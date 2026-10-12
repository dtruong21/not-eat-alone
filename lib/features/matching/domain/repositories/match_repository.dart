import 'package:not_eat_alone/features/matching/domain/entities/match.dart';

abstract class MatchRepository {
  /// All matches the user participates in, newest first.
  Stream<List<Match>> watchMatchesForUser(String uid);

  /// "Can't make it": the host cancels, or the guest withdraws from, the
  /// matched, future meal [mealId]. Server-side (callable) so the other person
  /// is told; throws if the call fails. NOT queued while offline.
  Future<void> cancelMatchedMeal({required String mealId});
}
