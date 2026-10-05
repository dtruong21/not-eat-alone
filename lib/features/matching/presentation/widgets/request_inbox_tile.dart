/// A single pending [JoinRequest] row on the host's request inbox
/// (`RequestInboxScreen`).
///
/// Watches `userDocProvider(request.guestId)` for the guest's photo/name/
/// derived age (own loading/error tolerated — falls back to a placeholder
/// row rather than blocking the whole tile), and drives Approve/Deny through
/// `inboxActionControllerProvider`. Both buttons disable while that
/// controller is submitting. Also watches `requestMealProvider` to show which
/// meal the request is for (restaurant + date/time) and, once that meal's
/// time has passed, a chip plus a disabled Approve. While the meal is
/// loading, errored or missing the tile behaves as if it did not know about
/// the meal at all (the server rules remain the source of truth).
///
/// Every Approve/Deny outcome is surfaced as a SnackBar via
/// `inboxActionMessage`; a successful approve adds a **Chat** action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/matching/application/inbox_action_controller.dart';
import 'package:not_eat_alone/features/matching/application/request_meal_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/inbox_action_message.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

/// Age in whole years for someone born on [dob], as of [now] (defaults to
/// `DateTime.now()`). Duplicated from `meal_detail_screen.dart`'s
/// `_ageFromDob` — both are small, presentation-only, private helpers.
int _ageFromDob(DateTime dob, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dob.year;
  final hadBirthday =
      (today.month > dob.month) ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age;
}

const _pastMealLabel = 'Meal time has passed';
const _snackBarDuration = Duration(seconds: 6);
const _a11ySnackBarDuration = Duration(seconds: 8);

class RequestInboxTile extends ConsumerWidget {
  const RequestInboxTile({required this.request, super.key});

  final JoinRequest request;

  Future<void> _approve(BuildContext context, WidgetRef ref) =>
      _run(context, ref, InboxAction.approve);

  Future<void> _deny(BuildContext context, WidgetRef ref) =>
      _run(context, ref, InboxAction.deny);

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    InboxAction action,
  ) async {
    // Captured BEFORE the await: this tile can be unmounted mid-flight (the
    // request's own status flip, applied optimistically by the Firestore
    // SDK, can rebuild the inbox list and remove this tile before the action
    // resolves), so neither `context` nor `ref` is safe to touch afterward.
    // The screen's `ScaffoldMessenger` and the router are ANCESTORS that stay
    // mounted, so the captured references still work.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    final accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    final controller = ref.read(inboxActionControllerProvider.notifier);
    final error = switch (action) {
      InboxAction.approve => await controller.approve(request),
      InboxAction.deny => await controller.deny(request),
    };
    // The Chat action is only useful when there is a router to push on.
    final hasChat = inboxActionHasChatAction(action, error) && router != null;
    // A SnackBar with an action persists until dismissed by default, and this
    // one lives on the root messenger (it would follow the host across tabs
    // and block every later snackbar), so force a timeout, offer a close
    // icon, and REPLACE any snackbar still showing from a previous outcome.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(inboxActionMessage(action, error)),
          persist: false,
          showCloseIcon: hasChat,
          duration: accessibleNavigation
              ? _a11ySnackBarDuration
              : _snackBarDuration,
          action: hasChat
              ? SnackBarAction(
                  label: 'Chat',
                  onPressed: () => router.push('/chats/${request.mealId}'),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final guest = ref.watch(userDocProvider(request.guestId)).value;

    final photoUrl = (guest != null && guest.photoUrls.isNotEmpty)
        ? guest.photoUrls.first
        : null;
    final label = guest == null
        ? 'Guest'
        : '${guest.displayName ?? 'Guest'}, ${_ageFromDob(guest.dob)}';

    final isSubmitting = ref.watch(inboxActionControllerProvider).isLoading;

    // Loading / error / missing meal all collapse to `null`: the tile just
    // omits the meal line and leaves Approve enabled.
    final meal = ref.watch(requestMealProvider(request.mealId)).value;
    final isPast = meal != null && meal.dateTime.isBefore(DateTime.now());

    final mealLineStyle = textTheme.bodySmall?.copyWith(
      color: colors.onSurface,
      fontWeight: WarmPlayfulType.captionWeight,
    );

    final approveButton = FilledButton(
      key: Key('request_inbox_approve_button_${request.id}'),
      onPressed: isSubmitting || isPast ? null : () => _approve(context, ref),
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        ),
      ),
      // The hint lives INSIDE the button so it merges into the button's own
      // semantics node (a Semantics wrapper outside it would be a separate
      // node) and screen readers say why Approve is disabled.
      child: isPast
          ? Semantics(hint: _pastMealLabel, child: const Text('Approve'))
          : const Text('Approve'),
    );

    return Container(
      key: Key('request_inbox_tile_${request.id}'),
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: WarmPlayfulSpacing.s5,
                backgroundColor: colors.surfaceContainerHighest,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        size: WarmPlayfulSpacing.s5,
                        color: colors.outline,
                      )
                    : null,
              ),
              const SizedBox(width: WarmPlayfulSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: WarmPlayfulType.h2Weight,
                      ),
                    ),
                    if (meal != null) ...[
                      const SizedBox(height: WarmPlayfulSpacing.s1),
                      Column(
                        key: Key('request_inbox_meal_line_${request.id}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.restaurant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mealLineStyle,
                          ),
                          Text(
                            formatMealDateTime(meal.dateTime),
                            style: mealLineStyle,
                          ),
                        ],
                      ),
                    ],
                    if (isPast) ...[
                      const SizedBox(height: WarmPlayfulSpacing.s2),
                      Container(
                        key: Key('request_inbox_past_chip_${request.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: WarmPlayfulSpacing.s3,
                          vertical: WarmPlayfulSpacing.s1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(
                            WarmPlayfulRadius.pill,
                          ),
                        ),
                        child: Text(
                          _pastMealLabel,
                          // One line always: at 320 px and large text scales
                          // the label may ellipsize; the meaning is also
                          // carried by the disabled Approve's tooltip and
                          // semantics hint.
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onErrorContainer,
                            fontWeight: WarmPlayfulType.captionWeight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WarmPlayfulSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: Key('request_inbox_deny_button_${request.id}'),
                onPressed: isSubmitting ? null : () => _deny(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: const Text('Deny'),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s2),
              if (isPast)
                Tooltip(message: _pastMealLabel, child: approveButton)
              else
                approveButton,
            ],
          ),
        ],
      ),
    );
  }
}
