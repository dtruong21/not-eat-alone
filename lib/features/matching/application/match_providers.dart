import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/matching/data/repositories/match_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';

final matchRepositoryProvider =
    Provider<MatchRepository>((ref) => MatchRepositoryImpl());
