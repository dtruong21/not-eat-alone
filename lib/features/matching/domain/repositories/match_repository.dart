import 'package:not_eat_alone/features/matching/domain/entities/match.dart';

abstract class MatchRepository {
  /// All matches the user participates in, newest first.
  Stream<List<Match>> watchMatchesForUser(String uid);
}
