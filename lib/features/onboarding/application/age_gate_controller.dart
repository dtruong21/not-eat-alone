/// Age-gate controller — Riverpod `AsyncNotifier` orchestrating the user and
/// auth domains for the age-verification step.
///
/// No domain of its own here (pragmatic Clean Architecture): it reads
/// [userRepositoryProvider] and [authRepositoryProvider] directly rather than
/// owning a repository interface.
///
/// Pattern (master spec idiom #1):
///   - `build()` returns the initial value — `AsyncData(AgeGateState())`,
///     nothing submitted yet, not blocked.
///   - `submit()` sets `state = const AsyncValue.loading()` then
///     `state = await AsyncValue.guard(() => ...)`. Errors propagate into
///     `state.error` automatically instead of throwing — the screen renders
///     them rather than crashing.
///   - Inside methods after `build()`, use `ref.read` only.
///
/// DOB is always normalized to a UTC-midnight calendar date
/// (`DateTime.utc(y, m, d)`) before it reaches `isAdult()` or the repository
/// — see `UserRepository`'s Firestore converter, which normalizes reads to
/// UTC. Passing a local-time `DateTime` here would risk a day of drift
/// around the timezone boundary.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/util/age.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/onboarding/application/underage_notice_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

part 'age_gate_controller.g.dart';

/// Data carried by [AgeGateController]'s state once settled.
class AgeGateState {
  const AgeGateState({this.blocked = false});

  /// True once the current user has been signed out for being under 18.
  final bool blocked;
}

@riverpod
class AgeGateController extends _$AgeGateController {
  @override
  AsyncValue<AgeGateState> build() => const AsyncValue.data(AgeGateState());

  /// Submits [dob]. Adults get age-verified in Firestore; under-18s are
  /// signed out with [state] left `blocked`. Either branch's failures land
  /// in `state.error` rather than throwing.
  Future<void> submit(DateTime dob) async {
    // CRITICAL: normalize to a UTC-midnight calendar date — see file header.
    final dobUtc = DateTime.utc(dob.year, dob.month, dob.day);

    // Keep alive until settled — see CreateRequestController.request. Both
    // branches can unmount the screen mid-flight (sign-out / the router
    // redirect reacting to the age-verified write).
    final link = ref.keepAlive();
    try {
      if (!isAdult(dobUtc)) {
        await analytics.track(const AgeGateFailed());
        state = const AsyncValue.loading();
        state = await AsyncValue.guard(() async {
          // Before signing out: the router then sends them to sign-in, whose
          // banner explains why (this screen is unmounted by then).
          final notice = ref.read(underageNoticeProvider.notifier)
            ..set(value: true);
          try {
            await ref.read(authRepositoryProvider).signOut();
          } on Object {
            // Still signed in: a banner about being under 18 would greet
            // this user's next (adult) sign-out.
            notice.set(value: false);
            rethrow;
          }
          return const AgeGateState(blocked: true);
        });
        return;
      }

      // A stale banner from an earlier under-18 attempt must not outlive an
      // adult sign-in.
      ref.read(underageNoticeProvider.notifier).set(value: false);
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final uid = ref.read(authRepositoryProvider).currentUser!.uid;
        await ref
            .read(userRepositoryProvider)
            .upsertAgeVerified(uid: uid, dob: dobUtc);
        await analytics.track(const AgeGatePassed());
        // No navigation here — the router's redirect reacts to the user doc
        // once the write lands and moves us to `/`.
        return const AgeGateState();
      });
    } finally {
      link.close();
    }
  }
}
