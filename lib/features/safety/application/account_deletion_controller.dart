/// Account-deletion controller — mirrors `BlockController`'s shape (see that
/// file for the master-spec idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/safety/application/account_providers.dart';

part 'account_deletion_controller.g.dart';

@riverpod
class AccountDeletionController extends _$AccountDeletionController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Deletes the signed-in user's account (callable cascade), then signs
  /// out. On repo failure, does NOT sign out — the state is left in error so
  /// the UI can surface it and the user can retry.
  Future<void> delete() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await analytics.track(const AccountDeletionRequested());
      await ref.read(accountRepositoryProvider).deleteAccount();
      await ref.read(authRepositoryProvider).signOut();
    });
  }
}
