import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/rating/application/rating_providers.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';

/// The current user's rating for [matchId], or `null` if they haven't rated
/// yet — and always `null` (an empty stream) when signed out.
final myRatingProvider = StreamProvider.family<Rating?, String>((ref, matchId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(ratingRepositoryProvider).watchMyRating(matchId, uid);
});
