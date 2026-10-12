/// Inbox-action controller — host approves/denies a pending [JoinRequest].
/// Mirrors `CreateMealController`'s shape (see that file for the master-spec
/// idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/inbox_action.dart';

part 'inbox_action_controller.g.dart';

/// Requests whose Approve/Deny is in flight, by request id. The controller's
/// own state is shared by every inbox tile, so each tile reads THIS to know
/// whether its own request is busy (and which button to spin) while the other
/// tiles stay enabled. `keepAlive` so it outlives a tile unmounted mid-flight.
@Riverpod(keepAlive: true)
class InboxPending extends _$InboxPending {
  @override
  Map<String, InboxAction> build() => const {};

  /// Marks [requestId] as busy with [action].
  void start(String requestId, InboxAction action) =>
      state = {...state, requestId: action};

  /// Clears [requestId]'s busy mark.
  void finish(String requestId) => state = {...state}..remove(requestId);
}

@riverpod
class InboxActionController extends _$InboxActionController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Returns the resulting error (e.g. `MealNoLongerOpenException`), or
  /// `null` on success — so callers (`RequestInboxTile`) can react to the
  /// outcome WITHOUT a second `ref.read` of this controller's state after
  /// the `await`, which is unsafe once the calling widget may have been
  /// unmounted in the meantime (the request's own status flip, applied
  /// optimistically by the Firestore SDK, can rebuild the inbox list and
  /// remove the tile before this future even resolves).
  Future<Object?> approve(JoinRequest request) async {
    // Keep alive until settled — see CreateRequestController.request.
    final link = ref.keepAlive();
    final pending = ref.read(inboxPendingProvider.notifier)
      ..start(request.id, InboxAction.approve);
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        await ref.read(requestRepositoryProvider).approve(request);
        await analytics.track(const RequestApproved());
        // women_only not on the request; approve fires match_created
        // without it.
        await analytics.track(const MatchCreated(womenOnly: false));
      });
      return state.error;
    } finally {
      pending.finish(request.id);
      link.close();
    }
  }

  /// Returns the resulting error, or `null` on success — same contract as
  /// [approve], for the same unmount-after-await reason.
  Future<Object?> deny(JoinRequest request) async {
    // Keep alive until settled — see CreateRequestController.request.
    final link = ref.keepAlive();
    final pending = ref.read(inboxPendingProvider.notifier)
      ..start(request.id, InboxAction.deny);
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        await ref.read(requestRepositoryProvider).deny(request);
        await analytics.track(const RequestDenied());
      });
      return state.error;
    } finally {
      pending.finish(request.id);
      link.close();
    }
  }
}
