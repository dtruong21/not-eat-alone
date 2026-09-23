import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';

/// Abstract interface for the `ratings` collection. Implemented in
/// `data/repositories/rating_repository_impl.dart` — the only file allowed
/// to import `cloud_firestore` for this feature.
abstract class RatingRepository {
  /// Writes `ratings/{rating.id}`.
  Future<void> submit(Rating rating);

  /// Streams the current user's rating for [matchId] (doc id
  /// `{matchId}_{raterUid}`), or `null` if they haven't rated yet.
  Stream<Rating?> watchMyRating(String matchId, String raterUid);
}
