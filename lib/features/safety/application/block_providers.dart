import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/safety/data/repositories/block_repository_impl.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';

/// The block boundary repository. Override in tests with a fake/mock.
final blockRepositoryProvider = Provider<BlockRepository>(
  (ref) => BlockRepositoryImpl(),
);

/// The set of uids the signed-in user should hide (empty when signed out).
final blockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(blockRepositoryProvider).watchBlockedUserIds(uid);
});

/// Only the uids the signed-in user blocked (for the Blocked-people screen).
/// Auto-disposed and tied to the session like the other per-user streams.
final blockedByMeProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  switch (watchSession(ref)) {
    case SessionState.resolving:
      return const Stream.empty();
    case SessionState.signedOut:
      return Stream.value(const <String>{});
    case SessionState.signedIn:
      break;
  }
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(blockRepositoryProvider).watchBlockedByMe(uid);
});
