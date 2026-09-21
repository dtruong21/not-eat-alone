/// Inbox-action controller — host approves/denies a pending [JoinRequest].
/// Mirrors `CreateMealController`'s shape (see that file for the master-spec
/// idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

part 'inbox_action_controller.g.dart';

@riverpod
class InboxActionController extends _$InboxActionController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> approve(JoinRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(requestRepositoryProvider).approve(request);
      await analytics.track(const RequestApproved());
      // women_only not on the request; approve fires match_created without it.
      await analytics.track(const MatchCreated(womenOnly: false));
    });
  }

  Future<void> deny(JoinRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(requestRepositoryProvider).deny(request);
      await analytics.track(const RequestDenied());
    });
  }
}
