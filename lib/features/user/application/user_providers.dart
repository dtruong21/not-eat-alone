import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/user/data/repositories/user_repository_impl.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepositoryImpl());

/// The signed-in user's OWN record (private `users/{uid}` merged with their
/// public profile), or `null` when signed out or the age gate hasn't created
/// it yet.
final currentUserDocProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchOwn(user.uid);
});

/// Any user's PUBLIC profile (`profiles/{uid}`) — for showing a host/guest.
/// Has no `dob`/`gender`; use [AppUser.ageYears] for the age.
final userDocProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watch(uid);
});
