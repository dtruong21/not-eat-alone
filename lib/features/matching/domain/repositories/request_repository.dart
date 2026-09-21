import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

abstract class RequestRepository {
  /// Guest ([guestId], the current auth uid supplied by the application layer)
  /// creates a pending request for [mealId] hosted by [hostId].
  /// Document id is `"${mealId}_${guestId}"`.
  Future<void> createRequest({
    required String mealId,
    required String guestId,
    required String hostId,
  });

  /// The guest's own request on [mealId] (drives the meal-detail button).
  Stream<JoinRequest?> watchRequest({
    required String mealId,
    required String guestId,
  });

  /// All `pending` requests across the host's meals, newest first (inbox).
  Stream<List<JoinRequest>> watchPendingForHost(String hostId);

  /// Host approves [request]: locks the meal, creates the match, denies
  /// siblings. Throws MealNoLongerOpenException when the meal is not `open`.
  Future<void> approve(JoinRequest request);

  /// Host denies a single [request].
  Future<void> deny(JoinRequest request);
}
