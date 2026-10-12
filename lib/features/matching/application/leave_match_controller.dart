/// "Can't make it" controller - host cancels / guest withdraws from a matched
/// meal. Not queueable offline (the other person must really be told), so it
/// awaits the server and surfaces failures as `AsyncError`.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';

part 'leave_match_controller.g.dart';

@riverpod
class LeaveMatchController extends _$LeaveMatchController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Returns true when the meal was cancelled / left.
  Future<bool> leave({required String mealId, required CancelRole role}) async {
    // Keep alive until settled (the dialog that watches us closes meanwhile).
    final link = ref.keepAlive();
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        await ref.read(matchRepositoryProvider).cancelMatchedMeal(mealId: mealId);
        await analytics.track(MealCancelled(role: role));
      });
      return !state.hasError;
    } finally {
      link.close();
    }
  }
}
