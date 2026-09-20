import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/user/data/repositories/user_repository_impl.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepositoryImpl());

/// The signed-in user's `users/{uid}` document, or `null` when signed out
/// or the document doesn't exist yet.
final currentUserDocProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(user.uid);
});
