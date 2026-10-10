/// The meal-detail screen's pinned action bar.
///
/// One full-width [AppButton] plus a reserved status line for every request
/// state (own meal, women-only block, loading, error, none, pending, approved,
/// denied), so the bar never changes size as the state changes. It is also the
/// always-mounted home of the server-rejection snackbar: the "Request to join"
/// button is swapped for "Requested" by the optimistic write before the server
/// answers, so the listener cannot live on that button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/create_request_controller.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

/// Status lines the bar reserves room for (longer copy is ellipsized).
const _statusLines = 2;

/// Pinned bottom bar for [meal]; use as `Scaffold.bottomNavigationBar`.
class MealActionBar extends ConsumerWidget {
  /// Creates the bar for [meal].
  const MealActionBar({required this.meal, super.key});

  /// The meal being viewed.
  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Captured synchronously: the listener fires later, off a rebuild.
    final messenger = ScaffoldMessenger.of(context);
    // loading -> error only, so this fires once per failed submit.
    ref.listen<AsyncValue<void>>(createRequestControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading != true || !next.hasError) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            next.error is MealNoLongerOpenException
                ? 'This meal is no longer open.'
                : "Couldn't send your request. Try again.",
          ),
        ),
      );
    });

    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: WarmPlayfulElevation.card,
      shadowColor: context.wp.shadow,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
          child: _BarContent(meal: meal),
        ),
      ),
    );
  }
}

/// Resolves the viewer's state into an action + status, in the order the
/// screen has always applied it.
class _BarContent extends ConsumerWidget {
  const _BarContent({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewerUid = ref.watch(authStateProvider).value?.uid;
    if (viewerUid != null && viewerUid == meal.hostId) {
      return const _Layout(
        action: AppButton(
          key: Key('meal_detail_your_meal_button'),
          label: 'This is your meal',
          variant: AppButtonVariant.tonal,
          onPressed: null,
        ),
        status: "You'll see requests in the Requests tab.",
      );
    }

    // Client-side mirror of the rules' women-only check on request create.
    final viewerGender = ref.watch(currentUserDocProvider).value?.gender;
    if (meal.womenOnly && viewerGender != Gender.woman) {
      return const _Layout(
        action: AppButton(
          key: Key('meal_detail_women_only_disabled_button'),
          label: 'Women only',
          variant: AppButtonVariant.tonal,
          onPressed: null,
        ),
        status: 'Only women can join this meal.',
        statusKey: Key('meal_detail_women_only_note'),
      );
    }

    final requestState = ref.watch(mealRequestStateProvider(meal.id));
    return requestState.when(
      loading: () => const _Layout(
        action: SizedBox(
          height: WarmPlayfulSize.actionHeight,
          child: SkeletonCard(
            key: Key('meal_action_skeleton'),
            lines: 1,
            showAvatar: false,
          ),
        ),
      ),
      error: (error, stackTrace) => _Layout(
        action: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: WarmPlayfulSize.actionHeight,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Couldn't load your request",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s3),
              AppButton(
                key: const Key('meal_detail_request_retry_button'),
                label: 'Try again',
                variant: AppButtonVariant.tonal,
                expand: false,
                onPressed: () =>
                    ref.invalidate(mealRequestStateProvider(meal.id)),
              ),
            ],
          ),
        ),
      ),
      data: (request) {
        if (request == null) {
          final isSubmitting = ref
              .watch(createRequestControllerProvider)
              .isLoading;
          return _Layout(
            action: AppButton(
              key: const Key('meal_detail_request_to_join_button'),
              label: 'Request to join',
              loadingLabel: 'Sending request…',
              isLoading: isSubmitting,
              onPressed: isSubmitting
                  ? null
                  : () => ref
                        .read(createRequestControllerProvider.notifier)
                        .request(meal),
            ),
          );
        }
        return switch (request.status) {
          RequestStatus.pending => const _Layout(
            action: AppButton(
              key: Key('meal_detail_requested_button'),
              label: 'Requested',
              variant: AppButtonVariant.tonal,
              onPressed: null,
            ),
            status: 'Waiting for the host to reply.',
          ),
          RequestStatus.approved => _Layout(
            action: AppButton(
              key: const Key('meal_detail_matched_banner'),
              label: 'Open chat',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              // matchId == mealId: `matches/{mealId}` is the hand-off doc the
              // approve transaction writes, so the meal id is the route param.
              onPressed: () => context.push('/chats/${meal.id}'),
            ),
            status: "You're matched. Say hi!",
          ),
          RequestStatus.denied => const _Layout(
            action: AppButton(
              key: Key('meal_detail_not_selected_button'),
              label: 'Not selected',
              variant: AppButtonVariant.tonal,
              onPressed: null,
            ),
            status: 'The host chose someone else. Have a look at other meals.',
          ),
        };
      },
    );
  }
}

/// Action on top, status line below in a slot that is always the same height.
class _Layout extends StatelessWidget {
  const _Layout({required this.action, this.status, this.statusKey});

  final Widget action;
  final String? status;
  final Key? statusKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.wp.muted);
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style?.fontSize ?? 12) * (style?.height ?? 1.5));

    return Column(
      key: const Key('meal_action_bar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        action,
        const SizedBox(height: WarmPlayfulSpacing.s2),
        // Mounted in every state so a status appearing is announced.
        Semantics(
          key: const Key('meal_action_status'),
          liveRegion: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: lineHeight * _statusLines),
            child: status == null
                ? null
                : Text(
                    status!,
                    key: statusKey,
                    textAlign: TextAlign.center,
                    maxLines: _statusLines,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
          ),
        ),
      ],
    );
  }
}
