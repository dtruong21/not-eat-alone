import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/rating/data/repositories/rating_repository_impl.dart';
import 'package:not_eat_alone/features/rating/domain/repositories/rating_repository.dart';

/// The rating boundary repository. Override in tests with a fake/mock.
final ratingRepositoryProvider =
    Provider<RatingRepository>((ref) => RatingRepositoryImpl());
