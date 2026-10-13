/// Create-request controller — guest joins a meal, mirrors
/// `CreateMealController`'s shape (see that file for the master-spec idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/util/queued_write.dart';
import 'package:not_eat_alone/core/util/queued_write_failures.dart';
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
    // Hold this autoDispose controller alive until the action settles: its
    // only watcher can unmount mid-flight (e.g. Firestore latency
    // compensation swaps the button that watches it), and the final
    // `state =` must still land for a re-subscribed error listener.
    final link = ref.keepAlive();
    // Read before the await: this controller may be disposed by the time a
    // late rejection arrives; the notifier is app-level.
    final failures = ref.read(queuedWriteFailuresProvider.notifier);
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final uid = ref.read(authRepositoryProvider).currentUser!.uid;
        await settleOrQueue(
          ref.read(requestRepositoryProvider).createRequest(
                mealId: meal.id,
                guestId: uid,
                hostId: meal.hostId,
              ),
          onLateError: (_, _) => failures.report(QueuedWriteKind.joinRequest),
        );
        await analytics.track(JoinRequested(womenOnly: meal.womenOnly));
      });
    } finally {
      link.close();
    }
  }
}
