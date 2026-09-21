import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

/// The current user's request on [mealId], or null. Drives the meal-detail
/// button. Keyed by mealId; uid comes from auth.
final mealRequestStateProvider =
    StreamProvider.family<JoinRequest?, String>((ref, mealId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(requestRepositoryProvider).watchRequest(
        mealId: mealId,
        guestId: uid,
      );
});
