import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/features/aloft/api.dart';
import 'package:flutter_test/flutter_test.dart';

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.respond);

  final ResponseBody Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  test('login keeps credentials in POST body and returns native auth data', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://www.aloft.icu/api/v1/'));
    dio.httpClientAdapter = FixtureAdapter((request) {
      expect(request.method, 'POST');
      expect(request.path, 'passport/auth/login');
      expect(request.uri.query, isEmpty);
      expect(request.data, {'email': 'customer@example.invalid', 'password': 'fixture'});
      return ResponseBody.fromString('{"data":{"auth_data":"Bearer fixture"}}', 200, headers: {Headers.contentTypeHeader: ['application/json']});
    });
    expect(await AloftApi(client: dio).login('customer@example.invalid', 'fixture'), 'Bearer fixture');
  });

  test('expired authentication never exposes raw server request details', () async {
    final dio = Dio();
    dio.httpClientAdapter = FixtureAdapter((_) => ResponseBody.fromString('private server response', 401));
    await expectLater(AloftApi(client: dio).subscription('Bearer secret-token'), throwsA(isA<AloftApiException>().having((e) => e.failure, 'failure', AloftFailure.expired).having((e) => e.toString().contains('secret-token'), 'redacted', false)));
  });

  test('subscription requires verified official HTTPS URL', () {
    for (final url in ['http://www.aloft.icu/s/fixture', 'https://www.aloft.icu.attacker.invalid/s/fixture', 'https://example.invalid/s/fixture', 'https://www.aloft.icu:8443/s/fixture', 'https://user@www.aloft.icu/s/fixture', 'https://www.aloft.icu/redirect']) {
      expect(() => AloftSubscription.fromJson({'subscribe_url': url}), throwsA(isA<AloftApiException>()));
    }
  });

  test('quota and expiry handle overuse and trial-hour boundaries', () {
    final now = DateTime.now();
    final subscription = AloftSubscription.fromJson({'subscribe_url': 'https://aloft.icu/s/fixture', 'transfer_enable': '209715200', 'u': 104857600, 'd': 115343360, 'expired_at': now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000});
    expect(subscription.remaining, 0);
    expect(subscription.fraction, 1);
    expect(subscription.availableAt(now), false);
    expect(subscription.url.host, 'www.aloft.icu');
    expect(subscription.url.queryParameters['flag'], 'clash');
  });

  test('catalog prices retain backend minor currency units', () {
    final plan = AloftPlan.fromJson({'name': '100 GB', 'transfer_enable': '100', 'month_price': '4500', 'quarter_price': 10500, 'year_price': 32500, 'reset_price': 3500});
    expect(plan.quotaGb, 100);
    expect(plan.prices, {'month_price': 4500, 'quarter_price': 10500, 'year_price': 32500, 'reset_price': 3500});
  });
}
