import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';

part 'push_registration_controller.g.dart';

@riverpod
class PushRegistrationController extends _$PushRegistrationController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Request permission then register the device token for [uid]. Safe to call
  /// on every app start for a signed-in, onboarded user.
  Future<void> register(String uid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(pushRepositoryProvider);
      final granted = await repo.requestPermission();
      await analytics.track(PushPermissionGranted(granted: granted));
      if (granted) {
        await repo.registerToken(uid);
      }
    });
  }

  Future<void> unregister(String uid) async {
    await ref.read(pushRepositoryProvider).unregisterCurrentToken(uid);
  }
}
