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

/// Largest text scale inside the bar: keeps the 56 pt button and the status
/// line a fixed size, so the bar never changes height (the page above it
/// still scales). The status line's full text is in its semantics label.
const _maxBarTextScale = 1.3;

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
      // Note: createRequest currently wraps every failure in
      // RepositoryWriteException, so the no-longer-open copy only shows if a
      // future repository change throws MealNoLongerOpenException.
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
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxBarTextScale,
      child: Material(
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
          maxLines: 1,
          onPressed: null,
        ),
        status: 'See requests in the Requests tab.',
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
          maxLines: 1,
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
        action: AppButton(
          key: const Key('meal_detail_request_retry_button'),
          label: 'Try again',
          variant: AppButtonVariant.tonal,
          maxLines: 1,
          onPressed: () => ref.invalidate(mealRequestStateProvider(meal.id)),
        ),
        status: "Couldn't load your request.",
        isError: true,
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
              maxLines: 1,
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
              maxLines: 1,
              onPressed: null,
            ),
            status: 'Waiting for the host to reply.',
          ),
          RequestStatus.approved => _Layout(
            action: AppButton(
              key: const Key('meal_detail_matched_banner'),
              label: 'Open chat',
              maxLines: 1,
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
              maxLines: 1,
              onPressed: null,
            ),
            status: 'The host chose someone else.',
          ),
        };
      },
    );
  }
}

/// Action on top, status line below in a slot that is always one line high.
class _Layout extends StatelessWidget {
  const _Layout({
    required this.action,
    this.status,
    this.statusKey,
    this.isError = false,
  });

  final Widget action;
  final String? status;
  final Key? statusKey;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isError ? context.wp.dangerText : context.wp.muted,
    );
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style?.fontSize ?? 12) * (style?.height ?? 1.5)).ceilToDouble();

    return Column(
      key: const Key('meal_action_bar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exactly the action height: at the clamped scale a label can still
        // ask for a pixel or two more than the button's minimum.
        SizedBox(height: WarmPlayfulSize.actionHeight, child: action),
        const SizedBox(height: WarmPlayfulSpacing.s2),
        // Mounted in every state so a status appearing is announced; the
        // label carries the full text even if the line is ellipsized.
        Semantics(
          key: const Key('meal_action_status'),
          container: true,
          liveRegion: true,
          label: status,
          excludeSemantics: true,
          child: SizedBox(
            height: lineHeight,
            child: status == null
                ? null
                : Text(
                    status!,
                    key: statusKey,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
          ),
        ),
      ],
    );
  }
}
