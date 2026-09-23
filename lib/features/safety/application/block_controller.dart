/// Block controller — mirrors `CreateRequestController`'s shape (see that
/// file for the master-spec idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';

part 'block_controller.g.dart';

@riverpod
class BlockController extends _$BlockController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> block(String blockedUid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(blockRepositoryProvider).block(uid, blockedUid);
      await analytics.track(const UserBlocked());
    });
  }

  Future<void> unblock(String blockedUid) async {
    final uid = ref.read(authRepositoryProvider).currentUser!.uid;
    await ref.read(blockRepositoryProvider).unblock(uid, blockedUid);
  }
}
