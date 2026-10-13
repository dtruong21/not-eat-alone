/// A card prompting the current user to rate the other participant, shown
/// in the matched chat's message list (just above the composer) once the meal
/// is over. Self-hides while the meal is still upcoming, while the meal is
/// unknown/loading, and once the current user has already rated this match -
/// see `docs/superpowers/specs/2026-09-23-ratings-design.md § 5. In-app
/// post-meal flow`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/rating/application/my_rating_provider.dart';
import 'package:not_eat_alone/features/rating/presentation/rating_sheet.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

class PostMealCard extends ConsumerStatefulWidget {
  const PostMealCard({
    required this.matchId,
    required this.targetUid,
    super.key,
  });

  final String matchId;
  final String targetUid;

  @override
  ConsumerState<PostMealCard> createState() => _PostMealCardState();
}

class _PostMealCardState extends ConsumerState<PostMealCard> {
  bool _firedPrompt = false;

  /// Fires `post_meal_prompt_shown` exactly once, on the frame after this
  /// card first becomes visible — deferred to a post-frame callback so it
  /// never runs as a side effect of `build()` itself.
  void _firePromptShownOnce() {
    if (_firedPrompt) return;
    _firedPrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(analytics.track(const PostMealPromptShown()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final meal = ref.watch(matchMealProvider(widget.matchId)).value;
    final myRating = ref.watch(myRatingProvider(widget.matchId)).value;

    final isPast = meal != null && meal.dateTime.isBefore(DateTime.now());
    if (!isPast || myRating != null) {
      return const SizedBox.shrink();
    }

    _firePromptShownOnce();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final targetName = ref
        .watch(userDocProvider(widget.targetUid))
        .value
        ?.displayName;

    // Large text: the button drops below the text, full width, instead of
    // squeezing title and label into half a row each (same 1.3x switch as
    // the blocked-people rows).
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final prompt = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.ratingTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: WarmPlayfulType.h2Weight,
          ),
        ),
        const SizedBox(height: WarmPlayfulSpacing.s1),
        Text(
          // The person's name is readable here (the button only says
          // "Rate"); it wraps to two lines and only a pathological name is cut.
          targetName != null
              ? context.l10n.ratingCardSubtitleNamed(targetName)
              : context.l10n.ratingCardSubtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: context.wp.muted),
        ),
      ],
    );
    Widget rateButton({required bool expand}) => AppButton(
      key: const Key('post_meal_card_rate_button'),
      // Constant and short so it never truncates; screen readers still hear
      // who is being rated.
      label: context.l10n.ratingRate,
      semanticLabel: targetName != null
          ? context.l10n.ratingRateNamed(targetName)
          : null,
      expand: expand,
      onPressed: () => showRatingSheet(
        context,
        matchId: widget.matchId,
        targetUid: widget.targetUid,
        partnerName: targetName,
      ),
    );

    return Card(
      key: const Key('post_meal_card'),
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  prompt,
                  const SizedBox(height: WarmPlayfulSpacing.s3),
                  rateButton(expand: true),
                ],
              )
            : Row(
                children: [
                  // The label is short and constant, so the button takes its
                  // natural width and the prompt gets the rest.
                  Expanded(child: prompt),
                  const SizedBox(width: WarmPlayfulSpacing.s3),
                  rateButton(expand: false),
                ],
              ),
      ),
    );
  }
}
