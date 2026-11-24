import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

abstract interface class AloftSessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class AloftSecureSessionStore implements AloftSessionStore {
  static const _key = 'aloft.account.v1';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

abstract interface class AloftProfilePort {
  Future<int> sync(Uri url, int? profileId);
  Future<void> remove(int? profileId);
  Future<void> connect();
  Future<void> disconnect();
}

enum AloftAccountIssue { credentials, network, response, storage, quota, expired }

class AloftAccount extends ChangeNotifier {
  AloftAccount({required this.api, required this.store, required this.profiles});

  final AloftPanel api;
  final AloftSessionStore store;
  final AloftProfilePort profiles;
  String? _token;
  int? _profileId;
  int _epoch = 0;
  bool _disposed = false;
  bool restoring = true;
  bool busy = false;
  String email = '';
  AloftSubscription? subscription;
  List<AloftPlan> plans = const [];
  AloftAccountIssue? issue;

  bool get signedIn => _token != null;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    final epoch = ++_epoch;
    try {
      final raw = await store.read();
      if (_disposed || epoch != _epoch || raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map || value['token'] is! String || value['email'] is! String ||
          (value['token'] as String).isEmpty) {
        await store.clear();
        return;
      }
      _token = value['token'] as String;
      email = value['email'] as String;
      _profileId = value['profile_id'] is int ? value['profile_id'] as int : null;
      await _load(epoch);
    } catch (error) {
      issue = _failure(error);
    } finally {
      if (epoch == _epoch) restoring = false;
      _emit();
    }
  }

  Future<void> login(String address, String password) async {
    if (busy) return;
    final epoch = ++_epoch;
    busy = true;
    issue = null;
    _emit();
    String? token;
    try {
      token = await api.login(address, password);
      final result = await Future.wait<Object>([
        api.subscription(token),
        api.plans(token),
      ]);
      if (_disposed || epoch != _epoch) return;
      await store.write(jsonEncode({'email': address.trim(), 'token': token}));
      if (_disposed || epoch != _epoch) return;
      _token = token;
      email = address.trim();
      _profileId = null;
      subscription = result[0] as AloftSubscription;
      plans = result[1] as List<AloftPlan>;
    } catch (error) {
      issue = _failure(error);
      if (token != null) {
        try { await api.revoke(token); } catch (_) {}
      }
    } finally {
      if (epoch == _epoch) busy = false;
      _emit();
    }
  }

  Future<void> _load(int epoch) async {
    final token = _token;
    if (token == null) return;
    try {
      final result = await Future.wait<Object>([
        api.subscription(token),
        api.plans(token),
      ]);
      if (_disposed || epoch != _epoch) return;
      subscription = result[0] as AloftSubscription;
      plans = result[1] as List<AloftPlan>;
    } on AloftApiException catch (error) {
      if (error.failure == AloftFailure.expired && epoch == _epoch) {
        await _clear();
        issue = AloftAccountIssue.expired;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (busy || !signedIn) return;
    final epoch = _epoch;
    busy = true;
    issue = null;
    _emit();
    try { await _load(epoch); } catch (error) { issue = _failure(error); }
    finally { busy = false; _emit(); }
  }

  Future<void> connect() async {
    if (busy || !signedIn) return;
    final epoch = _epoch;
    busy = true;
    issue = null;
    _emit();
    try {
      await _load(epoch);
      if (_disposed || epoch != _epoch || !signedIn) return;
      final value = subscription;
      if (value == null || !value.availableAt(DateTime.now())) {
        issue = AloftAccountIssue.quota;
        return;
      }
      final id = await profiles.sync(value.url, _profileId);
      if (_disposed || epoch != _epoch) {
        await profiles.remove(id);
        return;
      }
      _profileId = id;
      await store.write(jsonEncode({'email': email, 'token': _token, 'profile_id': id}));
      await profiles.connect();
    } catch (error) {
      issue = _failure(error);
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    issue = null;
    _emit();
    try { await profiles.disconnect(); }
    catch (_) { issue = AloftAccountIssue.network; }
    finally { busy = false; _emit(); }
  }

  Future<void> _clear() async {
    final id = _profileId;
    _token = null;
    _profileId = null;
    email = '';
    subscription = null;
    plans = const [];
    try { await store.clear(); }
    finally { await profiles.remove(id); }
  }

  Future<void> logout() async {
    if (busy) return;
    ++_epoch;
    final token = _token;
    busy = true;
    issue = null;
    _emit();
    try {
      await _clear();
    } catch (error) { issue = _failure(error); }
    finally {
      if (token != null) {
        try { await api.revoke(token); } catch (_) {}
      }
      busy = false;
      _emit();
    }
  }

  AloftAccountIssue _failure(Object error) => switch (error) {
    AloftApiException(failure: AloftFailure.credentials) => AloftAccountIssue.credentials,
    AloftApiException(failure: AloftFailure.expired) => AloftAccountIssue.expired,
    AloftApiException(failure: AloftFailure.invalidResponse) => AloftAccountIssue.response,
    AloftApiException() => AloftAccountIssue.network,
    _ => AloftAccountIssue.storage,
  };

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    super.dispose();
  }
}
