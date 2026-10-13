/// The meal-detail screen's pinned action bar.
///
/// One full-width [AppButton] plus a reserved status line for every request
/// state (own meal, cancelled meal, women-only block, loading, error, none,
/// pending, approved, denied), so the bar never changes size as the state
/// changes (at a given text size and width). It is also the
/// always-mounted home of the server-rejection snackbar: the "Request to join"
/// button is swapped for "Requested" by the optimistic write before the server
/// answers, so the listener cannot live on that button.
library;

import 'dart:math' as math;

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
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// Largest text scale inside the bar: the app's tested ceiling, so the main
/// action honours large text. The bar still has ONE height at a given text
/// size in every state: [_Layout] sizes the action slot and the status slot
/// from the same measurements for all states.
const _maxBarTextScale = 2.0;

/// Above this text scale the status line may use two lines (and its slot
/// reserves them in every state).
const _statusTwoLineScale = 1.3;

/// Every label the bar's button can show, with the width its icon takes: the
/// action slot is sized for the one that needs the most lines, so all states
/// share one height.
List<(String, double)> _buttonLabels(AppLocalizations l10n) => [
  (l10n.mealActionRequestToJoin, 0),
  (
    l10n.mealActionSendingRequest,
    WarmPlayfulSize.spinner + WarmPlayfulSpacing.s2,
  ),
  (l10n.mealActionRequested, 0),
  (l10n.mealActionOpenChat, 24 + WarmPlayfulSpacing.s2),
  (l10n.mealActionNotSelected, 0),
  (l10n.mealActionYourMeal, 0),
  (l10n.mealWomenOnly, 0),
  (l10n.mealActionCancelled, 0),
  (l10n.commonTryAgain, 0),
];

/// Most lines a button label may wrap to.
const _maxLabelLines = 2;

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
    final l10n = context.l10n;
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
                ? l10n.mealActionNoLongerOpen
                : l10n.mealActionRequestFailed,
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
    final l10n = context.l10n;
    final viewerUid = ref.watch(authStateProvider).value?.uid;
    if (viewerUid != null && viewerUid == meal.hostId) {
      return _Layout(
        action: AppButton(
          key: const Key('meal_detail_your_meal_button'),
          label: l10n.mealActionYourMeal,
          variant: AppButtonVariant.tonal,
          maxLines: _maxLabelLines,
          onPressed: null,
        ),
        status: l10n.mealActionStatusYourMeal,
      );
    }

    // A cancelled meal is terminal and wins over everything below: the host's
    // "Can't make it" sets the meal to `cancelled` but leaves the guest's
    // request `approved`, which must not read as "Open chat". After the
    // own-meal check (the host keeps their own view) and before the women-only
    // check (eligibility is moot once the meal is gone).
    if (meal.status == MealStatus.cancelled) {
      return _Layout(
        action: AppButton(
          key: const Key('meal_detail_cancelled_button'),
          label: l10n.mealActionCancelled,
          variant: AppButtonVariant.tonal,
          maxLines: _maxLabelLines,
          onPressed: null,
        ),
        status: l10n.mealActionStatusCancelled,
      );
    }

    // Client-side mirror of the rules' women-only check on request create.
    final viewerGender = ref.watch(currentUserDocProvider).value?.gender;
    if (meal.womenOnly && viewerGender != Gender.woman) {
      return _Layout(
        action: AppButton(
          key: const Key('meal_detail_women_only_disabled_button'),
          label: l10n.mealWomenOnly,
          variant: AppButtonVariant.tonal,
          maxLines: _maxLabelLines,
          onPressed: null,
        ),
        status: l10n.mealActionStatusWomenOnly,
        statusKey: const Key('meal_detail_women_only_note'),
      );
    }

    final requestState = ref.watch(mealRequestStateProvider(meal.id));
    return requestState.when(
      loading: () => const _Layout(
        action: SkeletonCard(
          key: Key('meal_action_skeleton'),
          lines: 1,
          showAvatar: false,
        ),
      ),
      error: (error, stackTrace) => _Layout(
        action: AppButton(
          key: const Key('meal_detail_request_retry_button'),
          label: l10n.commonTryAgain,
          variant: AppButtonVariant.tonal,
          maxLines: _maxLabelLines,
          onPressed: () => ref.invalidate(mealRequestStateProvider(meal.id)),
        ),
        status: l10n.mealActionStatusLoadError,
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
              label: l10n.mealActionRequestToJoin,
              loadingLabel: l10n.mealActionSendingRequest,
              maxLines: _maxLabelLines,
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
          RequestStatus.pending => _Layout(
            action: AppButton(
              key: const Key('meal_detail_requested_button'),
              label: l10n.mealActionRequested,
              variant: AppButtonVariant.tonal,
              maxLines: _maxLabelLines,
              onPressed: null,
            ),
            status: l10n.mealActionStatusPending,
          ),
          RequestStatus.approved => _Layout(
            action: AppButton(
              key: const Key('meal_detail_matched_banner'),
              label: l10n.mealActionOpenChat,
              maxLines: _maxLabelLines,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              // matchId == mealId: `matches/{mealId}` is the hand-off doc the
              // approve transaction writes, so the meal id is the route param.
              onPressed: () => context.push('/chats/${meal.id}'),
            ),
            status: l10n.mealActionStatusApproved,
          ),
          RequestStatus.denied => _Layout(
            action: AppButton(
              key: const Key('meal_detail_not_selected_button'),
              label: l10n.mealActionNotSelected,
              variant: AppButtonVariant.tonal,
              maxLines: _maxLabelLines,
              onPressed: null,
            ),
            status: l10n.mealActionStatusDenied,
          ),
        };
      },
    );
  }
}

/// Action on top, status line below, both in slots whose height depends only
/// on the text size and the width, never on the state.
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
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final statusStyle = theme.textTheme.bodySmall?.copyWith(
      color: isError ? context.wp.dangerText : context.wp.muted,
    );
    final statusLines = scaler.scale(1) > _statusTwoLineScale ? 2 : 1;
    final statusLineHeight = scaler
        .scale((statusStyle?.fontSize ?? 12) * (statusStyle?.height ?? 1.5))
        .ceilToDouble();
    final labelStyle = theme.textTheme.labelLarge ?? const TextStyle();
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The text width inside a button: its horizontal padding comes off.
        final textWidth = constraints.maxWidth - 2 * WarmPlayfulSpacing.s5;
        var lines = 1;
        for (final (label, iconWidth) in _buttonLabels(context.l10n)) {
          final painter =
              TextPainter(
                text: TextSpan(text: label, style: labelStyle),
                textDirection: direction,
                textScaler: scaler,
                maxLines: _maxLabelLines,
              )..layout(
                maxWidth: (textWidth - iconWidth).clamp(0, double.infinity),
              );
          final measured = painter.computeLineMetrics().length;
          painter.dispose();
          if (measured > lines) lines = measured;
        }
        final labelLineHeight = scaler
            .scale((labelStyle.fontSize ?? 16) * (labelStyle.height ?? 1.5))
            .ceilToDouble();
        final actionHeight = math.max(
          WarmPlayfulSize.actionHeight,
          lines * labelLineHeight + 2 * WarmPlayfulSpacing.s3,
        );

        return Column(
          key: const Key('meal_action_bar'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tight height: a button grows to the slot, the skeleton fills it.
            SizedBox(height: actionHeight, child: action),
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
                height: statusLineHeight * statusLines,
                child: status == null
                    ? null
                    : Text(
                        status!,
                        key: statusKey,
                        textAlign: TextAlign.center,
                        maxLines: statusLines,
                        overflow: TextOverflow.ellipsis,
                        style: statusStyle,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
