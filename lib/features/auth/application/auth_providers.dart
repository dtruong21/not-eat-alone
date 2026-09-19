/// Auth + session providers — application-layer wiring over
/// [AuthRepository] and [UsersRepository].
///
/// Manual `Provider`/`StreamProvider` (no `@riverpod` codegen), consistent
/// with `lib/core/routing/router.dart`. `authStateProvider` imports
/// `firebase_auth` only for the `User` type that `AuthRepository` already
/// exposes on its public API — feature code still never imports
/// `cloud_firestore` directly; that boundary is owned by
/// [UsersRepository].
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/firebase/auth_repository.dart';
import 'package:not_eat_alone/core/firebase/users_repository.dart';
import 'package:not_eat_alone/features/auth/domain/app_user.dart';

/// The auth boundary repository (Google/Apple/phone sign-in, sign-out,
/// session stream). Override in tests with a fake/mock.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// The `users/{uid}` Firestore repository. Override in tests with a
/// fake/mock.
final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

/// The current Firebase Auth session, or `null` when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The signed-in user's `users/{uid}` document, or `null` when signed out
/// or the document doesn't exist yet.
final currentUserDocProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.value;
  if (user == null) return Stream.value(null);
  return ref.watch(usersRepositoryProvider).watch(user.uid);
});
