/// Auth providers — application-layer wiring over [AuthRepository].
///
/// TEMPORARY filename: `auth_providers.dart` still holds the old
/// pre-clean-architecture providers (including `usersRepositoryProvider`/
/// `currentUserDocProvider`, which move out in a later task). Nothing
/// imports this file yet; Task 4 deletes the old file and promotes this one
/// to `auth_providers.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';

/// The auth boundary repository (Google/Apple/phone sign-in, sign-out,
/// session stream). Override in tests with a fake/mock.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl());

/// The current auth session, or `null` when signed out.
final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
