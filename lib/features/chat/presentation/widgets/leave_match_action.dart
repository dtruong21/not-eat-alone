/// App-bar "Can't make it" action for a match chat: lets the host cancel, or
/// the guest withdraw from, a MATCHED, FUTURE meal. Hidden otherwise (not
/// matched, already started, still loading). See DESIGN.md "Chat - Can't make it".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/leave_match_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

class LeaveMatchAction extends ConsumerWidget {
  const LeaveMatchAction({
    required this.matchId,
    required this.otherUid,
    super.key,
  });

  /// Equals the meal id (matches are 1:1 with meals).
  final String matchId;
  final String otherUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    final meal = ref.watch(matchMealProvider(matchId)).value;
    if (myUid == null || meal == null) return const SizedBox.shrink();

    final isHost = meal.hostId == myUid;
    final isGuest = meal.guestId == myUid;
    final canLeave =
        (isHost || isGuest) &&
        meal.status == MealStatus.matched &&
        meal.dateTime.isAfter(DateTime.now());
    if (!canLeave) return const SizedBox.shrink();

    final role = isHost ? CancelRole.host : CancelRole.guest;
    final otherName = ref.watch(userDocProvider(otherUid)).value?.displayName;

    return IconButton(
      key: const Key('leave_match_button'),
      icon: const Icon(Icons.event_busy_outlined),
      tooltip: context.l10n.leaveMatchTooltip,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final l10n = context.l10n;
        final router = GoRouter.of(context);
        final done = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _LeaveDialog(
            mealId: matchId,
            role: role,
            otherName: otherName ?? l10n.leaveMatchOtherFallback,
          ),
        );
        if (done == null) return; // "Keep meal"
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              done
                  ? (role == CancelRole.host
                        ? l10n.leaveMatchHostDone
                        : l10n.leaveMatchGuestDone)
                  : l10n.leaveMatchFailed,
            ),
          ),
        );
        if (done) router.go('/chats');
      },
    );
  }
}

/// Pops `true` on success, `false` on failure, `null` when the user keeps the meal.
class _LeaveDialog extends ConsumerWidget {
  const _LeaveDialog({
    required this.mealId,
    required this.role,
    required this.otherName,
  });

  final String mealId;
  final CancelRole role;
  final String otherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isHost = role == CancelRole.host;
    final loading = ref.watch(leaveMatchControllerProvider).isLoading;
    final errorColor = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: Text(
        isHost ? l10n.leaveMatchHostTitle : l10n.leaveMatchGuestTitle,
      ),
      content: Text(
        isHost
            ? l10n.leaveMatchHostBody(otherName)
            : l10n.leaveMatchGuestBody(otherName),
      ),
      actions: [
        TextButton(
          key: const Key('leave_match_keep'),
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.leaveMatchKeep),
        ),
        TextButton(
          key: const Key('leave_match_confirm'),
          style: TextButton.styleFrom(foregroundColor: errorColor),
          onPressed: loading
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  final ok = await ref
                      .read(leaveMatchControllerProvider.notifier)
                      .leave(mealId: mealId, role: role);
                  nav.pop(ok);
                },
          child: loading
              ? SizedBox(
                  height: WarmPlayfulSpacing.s4,
                  width: WarmPlayfulSpacing.s4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: errorColor,
                  ),
                )
              : Text(
                  isHost
                      ? l10n.leaveMatchHostConfirm
                      : l10n.leaveMatchGuestConfirm,
                ),
        ),
      ],
    );
  }
}
