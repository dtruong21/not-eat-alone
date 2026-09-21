/// Create-request controller — guest joins a meal, mirrors
/// `CreateMealController`'s shape (see that file for the master-spec idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

part 'create_request_controller.g.dart';

@riverpod
class CreateRequestController extends _$CreateRequestController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> request(Meal meal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(requestRepositoryProvider).createRequest(
            mealId: meal.id,
            guestId: uid,
            hostId: meal.hostId,
          );
      await analytics.track(JoinRequested(womenOnly: meal.womenOnly));
    });
  }
}
