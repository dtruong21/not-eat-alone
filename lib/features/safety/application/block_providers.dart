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
