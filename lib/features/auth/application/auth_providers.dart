/// Auth providers — application-layer wiring over [AuthRepository].
///
/// `currentUserDocProvider` (the `users/{uid}` Firestore stream) lives in
/// `features/user/application/user_providers.dart`, which watches
/// `authStateProvider` below.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';

/// The auth boundary repository (Google/Apple/phone sign-in, sign-out,
/// session stream). Override in tests with a fake/mock.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(),
);

/// The current auth session, or `null` when signed out.
final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// How a per-user provider should react to the auth session (see
/// [watchSession]).
enum SessionState {
  /// Auth hasn't resolved yet: stay in `AsyncLoading`.
  resolving,

  /// Signed out: yield an empty value, open no Firestore listener.
  signedOut,

  /// Signed in.
  signedIn,
}

/// Per-user providers (profiles, chat threads, requests...) call this first:
///
/// ```dart
/// switch (watchSession(ref)) {
///   case SessionState.resolving: return const Stream.empty();
///   case SessionState.signedOut: return Stream.value(null);
///   case SessionState.signedIn: break;
/// }
/// ```
///
/// It watches only the signed-in-ness of the session, so sign-out closes the
/// provider's Firestore listener (instead of leaving a stream the backend has
/// already terminated with permission-denied), and the next sign-in builds a
/// fresh one under its own credentials.
SessionState watchSession(Ref ref) {
  final (:isLoading, :signedIn) = ref.watch(
    authStateProvider.select(
      (auth) => (isLoading: auth.isLoading, signedIn: auth.value != null),
    ),
  );
  if (isLoading) return SessionState.resolving;
  return signedIn ? SessionState.signedIn : SessionState.signedOut;
}
