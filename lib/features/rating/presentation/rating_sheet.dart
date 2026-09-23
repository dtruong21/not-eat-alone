/// The "Rate your meal" bottom sheet — a 1–5 star picker, a show-up toggle,
/// and an optional comment, wired to `ratingControllerProvider`. See
/// `docs/superpowers/specs/2026-09-23-ratings-design.md § 5. In-app
/// post-meal flow` for the model this feeds (`ratings/{matchId}_{raterUid}`,
/// one rating per rater per match, immutable).
///
/// [showRatingSheet] is the only public entry point; the entry point is
/// `PostMealCard` (see `widgets/post_meal_card.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';

/// Opens the rating sheet for [targetUid] within [matchId].
Future<void> showRatingSheet(
  BuildContext context, {
  required String matchId,
  required String targetUid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RatingSheet(matchId: matchId, targetUid: targetUid),
  );
}

class _RatingSheet extends ConsumerStatefulWidget {
  const _RatingSheet({required this.matchId, required this.targetUid});

  final String matchId;
  final String targetUid;

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int _stars = 0;
  bool _showedUp = true;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars <= 0) return;

    final comment = _commentController.text.trim();

    await ref.read(ratingControllerProvider.notifier).submit(
          matchId: widget.matchId,
          targetUid: widget.targetUid,
          stars: _stars,
          showedUp: _showedUp,
          comment: comment.isEmpty ? null : comment,
        );

    if (!mounted) return;
    final error = ref.read(ratingControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't submit your rating. Try again."),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for the feedback!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isSubmitting = ref.watch(ratingControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: WarmPlayfulSpacing.s5,
        right: WarmPlayfulSpacing.s5,
        top: WarmPlayfulSpacing.s5,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            WarmPlayfulSpacing.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How was your meal?',
            style: textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: WarmPlayfulType.h2Weight,
            ),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('rating_star_$i'),
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: colors.tertiary,
                    size: WarmPlayfulSpacing.s6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: WarmPlayfulSpacing.s2),
          SwitchListTile(
            key: const Key('rating_showed_up_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Did they show up?'),
            value: _showedUp,
            onChanged: isSubmitting
                ? null
                : (value) => setState(() => _showedUp = value),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s2),
          TextField(
            key: const Key('rating_comment_field'),
            controller: _commentController,
            enabled: !isSubmitting,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s2),
          FilledButton(
            key: const Key('rating_submit_button'),
            onPressed: (_stars <= 0 || isSubmitting) ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: WarmPlayfulSpacing.s4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
              ),
            ),
            child: isSubmitting
                ? SizedBox(
                    height: WarmPlayfulSpacing.s4,
                    width: WarmPlayfulSpacing.s4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
