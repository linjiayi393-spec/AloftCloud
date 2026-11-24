import 'dart:convert';

import 'package:fl_clash/features/aloft/account.dart';
import 'package:fl_clash/features/aloft/api.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySession implements AloftSessionStore {
  String? value;
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('storage unavailable');
    this.value = value;
  }

  @override
  Future<void> clear() async { value = null; }
}

class FakeProfiles implements AloftProfilePort {
  final operations = <String>[];
  bool failSync = false;

  @override
  Future<int> sync(Uri url, int? profileId) async {
    operations.add('sync');
    expect(url.queryParameters['flag'], 'clash');
    if (failSync) throw const AloftApiException(AloftFailure.unavailable);
    return profileId ?? 42;
  }

  @override
  Future<void> connect() async { operations.add('connect'); }

  @override
  Future<void> disconnect() async { operations.add('disconnect'); }

  @override
  Future<void> remove(int? profileId) async { operations.add('remove:$profileId'); }
}

class FakePanel implements AloftPanel {
  final revoked = <String>[];
  AloftFailure? failure;
  int quota = 107374182400;
  int used = 53687091200;

  @override
  Future<String> login(String email, String password) async {
    if (failure != null) throw AloftApiException(failure!);
    return 'Bearer fixture';
  }

  @override
  Future<AloftSubscription> subscription(String token) async {
    if (failure != null) throw AloftApiException(failure!);
    return AloftSubscription.fromJson({
      'transfer_enable': quota,
      'u': used,
      'd': 0,
      'expired_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
      'subscribe_url': 'https://www.aloft.icu/s/fixture',
    });
  }

  @override
  Future<List<AloftPlan>> plans(String token) async => [
    AloftPlan.fromJson({'name': '100 GB', 'transfer_enable': 100, 'month_price': 2500, 'quarter_price': 6800, 'year_price': 18800, 'reset_price': 1500}),
  ];

  @override
  Future<void> revoke(String token) async { revoked.add(token); }
}

void main() {
  late MemorySession store;
  late FakePanel api;
  late FakeProfiles profiles;
  late AloftAccount account;

  setUp(() {
    store = MemorySession();
    api = FakePanel();
    profiles = FakeProfiles();
    account = AloftAccount(api: api, store: store, profiles: profiles);
  });
  tearDown(() => account.dispose());

  test('login loads server-specific catalog and stores no password', () async {
    await account.restore();
    expect(account.restoring, false);
    await account.login('customer@example.invalid', 'private-password');
    expect(account.signedIn, true);
    expect(account.plans.single.prices['month_price'], 2500);
    expect(account.subscription!.remaining, 53687091200);
    expect(store.value, isNot(contains('private-password')));
    expect(profiles.operations, isEmpty);
  });

  test('connect refreshes eligibility then synchronizes before starting', () async {
    await account.login('customer@example.invalid', 'fixture');
    await account.connect();
    expect(profiles.operations, ['sync', 'connect']);
    expect(jsonDecode(store.value!)['profile_id'], 42);
    await account.disconnect();
    expect(profiles.operations.last, 'disconnect');
  });

  test('logout clears local session, removes its profile and revokes token', () async {
    await account.login('customer@example.invalid', 'fixture');
    await account.connect();
    await account.logout();
    expect(store.value, null);
    expect(account.signedIn, false);
    expect(account.subscription, null);
    expect(account.plans, isEmpty);
    expect(profiles.operations.last, 'remove:42');
    expect(api.revoked, ['Bearer fixture']);
  });

  test('exhaustion blocks connection without removing renewal catalog', () async {
    await account.login('customer@example.invalid', 'fixture');
    api.used = api.quota;
    await account.connect();
    expect(account.issue, AloftAccountIssue.quota);
    expect(profiles.operations, isEmpty);
    expect(account.plans, isNotEmpty);
    expect(account.busy, false);
  });

  test('expired authorization clears prior account and node profile', () async {
    store.value = jsonEncode({'email': 'customer@example.invalid', 'token': 'Bearer fixture', 'profile_id': 42});
    api.failure = AloftFailure.expired;
    await account.restore();
    expect(account.signedIn, false);
    expect(store.value, null);
    expect(profiles.operations, ['remove:42']);
    expect(account.issue, AloftAccountIssue.expired);
  });

  test('network failure never starts stale subscription', () async {
    await account.login('customer@example.invalid', 'fixture');
    api.failure = AloftFailure.unavailable;
    await account.connect();
    expect(profiles.operations, isEmpty);
    expect(account.issue, AloftAccountIssue.network);
    expect(account.busy, false);
  });

  test('secure storage failure prevents login and revokes new token', () async {
    store.failWrites = true;
    await account.login('customer@example.invalid', 'fixture');
    expect(account.signedIn, false);
    expect(account.issue, AloftAccountIssue.storage);
    expect(api.revoked, ['Bearer fixture']);
    expect(account.busy, false);
  });

  test('failed profile synchronization does not connect', () async {
    await account.login('customer@example.invalid', 'fixture');
    profiles.failSync = true;
    await account.connect();
    expect(profiles.operations, ['sync']);
    expect(account.busy, false);
    expect(account.issue, AloftAccountIssue.network);
  });
}
