import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

part 'push_registration_controller.g.dart';

@riverpod
class PushRegistrationController extends _$PushRegistrationController {
  // Set while a device token is registered for this uid: keeps the (otherwise
  // autoDispose) controller alive so the locale listener below keeps working,
  // and is released by unregister or when the session no longer matches.
  String? _registeredUid;
  String? _registeredLang;
  KeepAliveLink? _registeredLink;

  @override
  AsyncValue<void> build() {
    ref.listen(localeControllerProvider, (_, next) => _onLocaleChanged(next));
    return const AsyncValue.data(null);
  }

  String _currentLang() => resolveAppLanguage(
    ref.read(localeControllerProvider),
    ref.read(deviceLocalesProvider),
  );

  /// Request permission then register the device token for [uid]. Safe to call
  /// on every app start for a signed-in, onboarded user.
  Future<void> register(String uid) async {
    // Keep alive until settled — see CreateRequestController.request.
    final link = ref.keepAlive();
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final repo = ref.read(pushRepositoryProvider);
        final lang = _currentLang();
        final granted = await repo.requestPermission();
        await analytics.track(PushPermissionGranted(granted: granted));
        if (granted) {
          await repo.registerToken(uid, lang: lang);
          _registeredLink?.close();
          _registeredUid = uid;
          _registeredLang = lang;
          _registeredLink = ref.keepAlive();
        }
      });
    } finally {
      link.close();
    }
  }

  Future<void> unregister(String uid) async {
    final repo = ref.read(pushRepositoryProvider);
    _stopTracking();
    await repo.unregisterCurrentToken(uid);
  }

  void _stopTracking() {
    _registeredUid = null;
    _registeredLang = null;
    _registeredLink?.close();
    _registeredLink = null;
  }

  void _onLocaleChanged(Object? _) {
    final uid = _registeredUid;
    if (uid == null) return;
    // Sign-out unregisters via the repository, not this controller: stop
    // tracking once the session is no longer the registered one.
    if (ref.read(authRepositoryProvider).currentUser?.uid != uid) {
      _stopTracking();
      return;
    }
    final lang = _currentLang();
    if (lang == _registeredLang) return;
    _registeredLang = lang;
    unawaited(_updateLanguage(ref.read(pushRepositoryProvider), uid, lang));
  }

  // Best-effort: a failed write must never reach PlatformDispatcher.onError.
  Future<void> _updateLanguage(
    PushRepository repo,
    String uid,
    String lang,
  ) async {
    try {
      await repo.updateTokenLanguage(uid, lang);
    } on Object catch (e) {
      debugPrint('push: language update failed (${e.runtimeType})');
    }
  }
}
