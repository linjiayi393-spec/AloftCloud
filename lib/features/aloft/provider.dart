import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account.dart';
import 'api.dart';

final aloftAccountProvider = Provider<AloftAccount>((ref) {
  final account = AloftAccount(
    api: AloftApi(),
    store: AloftSecureSessionStore(),
    profiles: _AloftProfiles(ref),
  );
  ref.onDispose(account.dispose);
  unawaited(account.restore());
  return account;
});

class _AloftProfiles implements AloftProfilePort {
  _AloftProfiles(this.ref);

  final Ref ref;

  @override
  Future<int> sync(Uri url, int? profileId) async {
    final saved = ref.read(profilesProvider).getProfile(profileId);
    final profile = saved?.copyWith(url: url.toString()) ??
        Profile.normal(label: appName, url: url.toString());
    final core = ref.read(coreHandlerProvider);
    try {
      final downloaded = await profile.update(
        validate: (path, key) => core.validateProfile(path, key),
      );
      ref.read(profilesActionProvider.notifier).putProfile(downloaded);
      ref.read(currentProfileIdProvider.notifier).value = downloaded.id;
      if (!await ref.read(setupActionProvider.notifier).applyProfile()) {
        throw const AloftApiException(AloftFailure.invalidResponse);
      }
      return downloaded.id;
    } catch (_) {
      if (saved == null) {
        await ref.read(profilesActionProvider.notifier).deleteProfile(profile.id);
      }
      rethrow;
    }
  }

  @override
  Future<void> remove(int? profileId) async {
    await ref.read(setupActionProvider.notifier).setRunning(false);
    if (profileId != null && ref.read(profilesProvider).getProfile(profileId) != null) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(profileId);
    }
  }

  @override
  Future<void> connect() async {
    if (!await ref.read(setupActionProvider.notifier).setRunning(true)) {
      throw const AloftApiException(AloftFailure.unavailable);
    }
  }

  @override
  Future<void> disconnect() async {
    if (!await ref.read(setupActionProvider.notifier).setRunning(false)) {
      throw const AloftApiException(AloftFailure.unavailable);
    }
  }
}
