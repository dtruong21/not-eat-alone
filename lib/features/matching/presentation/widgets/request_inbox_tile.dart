/// A single pending [JoinRequest] row on the host's request inbox
/// (`RequestInboxScreen`).
///
/// Watches `userDocProvider(request.guestId)` for the guest's photo/name/
/// derived age (own loading/error tolerated — falls back to a placeholder
/// row rather than blocking the whole tile), and drives Approve/Deny through
/// `inboxActionControllerProvider`. While THIS request's action is in flight
/// (`inboxPendingProvider`) both its buttons disable and the pressed one
/// shows a spinner; other tiles stay usable. Also watches `requestMealProvider` to show which
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

import 'package:not_eat_alone/core/design/avatar_image.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/matching/application/inbox_action_controller.dart';
import 'package:not_eat_alone/features/matching/application/request_meal_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/inbox_action_message.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

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
    final guestAge = guest?.ageYears;
    final label = guest == null
        ? 'Guest'
        : [
            guest.displayName ?? 'Guest',
            if (guestAge != null) guestAge,
          ].join(', ');

    // Busy only for THIS request (the controller's own state is shared).
    final pendingAction = ref.watch(
      inboxPendingProvider.select((p) => p[request.id]),
    );
    final isBusy = pendingAction != null;

    // Loading / error / missing meal all collapse to `null`: the tile just
    // omits the meal line and leaves Approve enabled.
    final meal = ref.watch(requestMealProvider(request.mealId)).value;
    final isPast = meal != null && meal.dateTime.isBefore(DateTime.now());

    final mealLineStyle = textTheme.bodySmall?.copyWith(
      color: colors.onSurface,
      fontWeight: WarmPlayfulType.captionWeight,
    );

    // The hint lives on a Semantics wrapping the button so screen readers say
    // why Approve is disabled.
    final approveButton = MergeSemantics(
      child: Semantics(
        hint: isPast ? _pastMealLabel : null,
        child: AppButton(
          key: Key('request_inbox_approve_button_${request.id}'),
          label: 'Approve',
          loadingLabel: 'Approving…',
          expand: false,
          maxLines: 1,
          isLoading: pendingAction == InboxAction.approve,
          onPressed: isBusy || isPast ? null : () => _approve(context, ref),
        ),
      ),
    );
    // Deliberate: danger-coloured quiet action next to the primary Approve.
    final denyButton = TextButtonTheme(
      data: TextButtonThemeData(
        // `merge`: this style wins, the app's text-button theme fills the gaps.
        style: TextButton.styleFrom(
          foregroundColor: context.wp.dangerText,
        ).merge(theme.textButtonTheme.style),
      ),
      child: AppButton(
        key: Key('request_inbox_deny_button_${request.id}'),
        label: 'Deny',
        loadingLabel: 'Denying…',
        variant: AppButtonVariant.text,
        expand: false,
        maxLines: 1,
        isLoading: pendingAction == InboxAction.deny,
        onPressed: isBusy ? null : () => _deny(context, ref),
      ),
    );

    return Material(
      key: Key('request_inbox_tile_${request.id}'),
      color: colors.surfaceContainerHighest,
      elevation: WarmPlayfulElevation.card,
      shadowColor: context.wp.shadow,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
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
                      ? avatarImage(
                          context,
                          photoUrl,
                          radius: WarmPlayfulSpacing.s5,
                        )
                      : null,
                  onBackgroundImageError: photoUrl != null
                      ? ignoreAvatarImageError
                      : null,
                  child: photoUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: WarmPlayfulSpacing.s5,
                          color: context.wp.muted,
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
                      // The badge is empty until the guest doc loads: no gap then.
                      if (guest != null) ...[
                        const SizedBox(height: WarmPlayfulSpacing.s1),
                        RatingBadge(uid: request.guestId),
                      ],
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
            // Stacks (Approve on top) when the pair does not fit, at narrow
            // widths / large text, instead of overflowing.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              overflowDirection: VerticalDirection.up,
              spacing: WarmPlayfulSpacing.s2,
              overflowSpacing: WarmPlayfulSpacing.s2,
              children: [
                denyButton,
                if (isPast)
                  Tooltip(message: _pastMealLabel, child: approveButton)
                else
                  approveButton,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
