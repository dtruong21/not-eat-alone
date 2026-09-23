/// Compact aggregate-rating badge — a filled star + average (one decimal) +
/// review count, e.g. "★ 4.5 (8)", or "New" once the user has no ratings
/// yet. Reused on the meal-detail host block, the chat app bar (the other
/// participant), and the profile screen (the signed-in user's own
/// aggregate) — see `docs/superpowers/specs/2026-09-23-ratings-design.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

class RatingBadge extends ConsumerWidget {
  const RatingBadge({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // `.value` is `null` while loading and while the doc doesn't exist —
    // both tolerated the same way, with a tiny placeholder rather than a
    // spinner (this badge is decoration on a screen whose primary content
    // has its own loading state).
    final user = ref.watch(userDocProvider(uid)).value;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (user.ratingCount == 0) {
      return Text(
        'New',
        key: const Key('rating_badge_new'),
        style: textTheme.bodySmall?.copyWith(
          color: colors.outline,
          fontWeight: WarmPlayfulType.captionWeight,
        ),
      );
    }

    return Row(
      key: const Key('rating_badge'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          color: colors.tertiary,
          size: WarmPlayfulSpacing.s4,
        ),
        const SizedBox(width: WarmPlayfulSpacing.s1),
        Text(
          '${user.ratingAvg.toStringAsFixed(1)} (${user.ratingCount})',
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
            fontWeight: WarmPlayfulType.captionWeight,
          ),
        ),
      ],
    );
  }
}
