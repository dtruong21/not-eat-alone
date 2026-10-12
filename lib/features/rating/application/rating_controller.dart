/// Rating controller — the rater submits stars/no-show/comment for a match
/// participant. Same shape as `CreateRequestController`/`CreateMealController`
/// (master spec idiom #1): `build()` returns `AsyncData(null)`, `submit()`
/// sets loading then wraps the write in `AsyncValue.guard` so failures land
/// in `state.error` rather than throwing. `meal_rated` fires only after the
/// write succeeds.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/util/queued_write.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/rating/application/rating_providers.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';

part 'rating_controller.g.dart';

@riverpod
class RatingController extends _$RatingController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Submits a rating of [targetUid] for [matchId]. No-ops when [stars] is
  /// not a positive number (blank/unset rating).
  Future<void> submit({
    required String matchId,
    required String targetUid,
    required int stars,
    required bool showedUp,
    String? comment,
  }) async {
    if (stars <= 0) return;

    // Keep alive until settled — see CreateRequestController.request.
    final link = ref.keepAlive();
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final uid = ref.read(authRepositoryProvider).currentUser!.uid;
        final rating = Rating(
          id: '${matchId}_$uid',
          matchId: matchId,
          raterUid: uid,
          targetUid: targetUid,
          stars: stars,
          showedUp: showedUp,
          comment: comment,
        );
        await settleOrQueue(ref.read(ratingRepositoryProvider).submit(rating));
        await analytics.track(MealRated(stars: stars, showedUp: showedUp));
      });
    } finally {
      link.close();
    }
  }
}
