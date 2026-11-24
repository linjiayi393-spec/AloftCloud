import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

const aloftWebsite = 'https://www.aloft.icu';

enum AloftFailure { credentials, expired, unavailable, invalidResponse }

class AloftApiException implements Exception {
  const AloftApiException(this.failure);

  final AloftFailure failure;

  @override
  String toString() => 'AloftApiException(${failure.name})';
}

abstract interface class AloftPanel {
  Future<String> login(String email, String password);
  Future<AloftSubscription> subscription(String token);
  Future<List<AloftPlan>> plans(String token);
  Future<void> revoke(String token);
}

class AloftApi implements AloftPanel {
  AloftApi({Dio? client}) : _client = client ?? _newClient();

  final Dio _client;

  static Dio _newClient() {
    final client = Dio(BaseOptions(
      baseUrl: '$aloftWebsite/api/v1/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    ));
    client.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..findProxy = (_) => 'DIRECT'
        ..badCertificateCallback = (_, _, _) => false,
    );
    return client;
  }

  Future<Object?> _request(
    String path, {
    String? token,
    Map<String, Object?>? data,
  }) async {
    try {
      final response = await _client.request<Object?>(
        path,
        data: data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          headers: {if (token != null) 'Authorization': token},
        ),
      );
      final body = response.data;
      if (body is! Map<String, dynamic> || !body.containsKey('data')) {
        throw const AloftApiException(AloftFailure.invalidResponse);
      }
      return body['data'];
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw AloftApiException(switch (status) {
        401 || 403 => token == null
            ? AloftFailure.credentials
            : AloftFailure.expired,
        400 || 422 => token == null
            ? AloftFailure.credentials
            : AloftFailure.invalidResponse,
        _ => AloftFailure.unavailable,
      });
    }
  }

  @override
  Future<String> login(String email, String password) async {
    final data = await _request('passport/auth/login', data: {
      'email': email.trim(),
      'password': password,
    });
    if (data is! Map || data['auth_data'] is! String ||
        (data['auth_data'] as String).isEmpty) {
      throw const AloftApiException(AloftFailure.invalidResponse);
    }
    return data['auth_data'] as String;
  }

  @override
  Future<AloftSubscription> subscription(String token) async {
    final data = await _request('user/getSubscribe', token: token);
    if (data is! Map<String, dynamic>) {
      throw const AloftApiException(AloftFailure.invalidResponse);
    }
    return AloftSubscription.fromJson(data);
  }

  @override
  Future<List<AloftPlan>> plans(String token) async {
    final data = await _request('user/plan/fetch', token: token);
    if (data is! List) {
      throw const AloftApiException(AloftFailure.invalidResponse);
    }
    return [
      for (final item in data)
        if (item is Map<String, dynamic>) AloftPlan.fromJson(item),
    ];
  }

  @override
  Future<void> revoke(String token) async {
    await _request('user/aloft/logout', token: token, data: {});
  }
}

int _count(Object? value) => switch (value) {
  num number when number.isFinite => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

class AloftSubscription {
  const AloftSubscription({
    required this.quota,
    required this.used,
    required this.expiresAt,
    required this.url,
    required this.planName,
  });

  factory AloftSubscription.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['subscribe_url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (url == null || url.scheme != 'https' ||
        !const {'www.aloft.icu', 'aloft.icu'}.contains(url.host) ||
        url.userInfo.isNotEmpty || (url.hasPort && url.port != 443) ||
        !(url.path.startsWith('/s/') || url.path == '/api/v1/client/subscribe')) {
      throw const AloftApiException(AloftFailure.invalidResponse);
    }
    final expiry = _count(json['expired_at']);
    final plan = json['plan'];
    return AloftSubscription(
      quota: _count(json['transfer_enable']).clamp(0, 1 << 62),
      used: (_count(json['u']) + _count(json['d'])).clamp(0, 1 << 62),
      expiresAt: expiry > 0
          ? DateTime.fromMillisecondsSinceEpoch(expiry * 1000)
          : null,
      url: url.replace(
        host: 'www.aloft.icu',
        queryParameters: {...url.queryParameters, 'flag': 'clash'},
        fragment: '',
      ),
      planName: plan is Map && plan['name'] is String
          ? plan['name'] as String
          : '',
    );
  }

  final int quota;
  final int used;
  final DateTime? expiresAt;
  final Uri url;
  final String planName;

  int get remaining => (quota - used).clamp(0, quota);
  double get fraction => quota == 0 ? 0 : (used / quota).clamp(0, 1);
  bool availableAt(DateTime now) => remaining > 0 &&
      (expiresAt == null || expiresAt!.isAfter(now));
}

class AloftPlan {
  const AloftPlan({
    required this.name,
    required this.quotaGb,
    required this.prices,
  });

  factory AloftPlan.fromJson(Map<String, dynamic> json) => AloftPlan(
    name: json['name'] is String ? json['name'] as String : '',
    quotaGb: _count(json['transfer_enable']),
    prices: {
      for (final key in ['month_price', 'quarter_price', 'year_price', 'reset_price'])
        if (json[key] != null) key: _count(json[key]),
    },
  );

  final String name;
  final int quotaGb;
  final Map<String, int> prices;
}
