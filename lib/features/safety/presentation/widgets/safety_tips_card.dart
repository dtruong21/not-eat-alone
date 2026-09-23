/// A static, informational card displaying safety tips for users meeting up.
/// Shown at the top of the chat screen — no data, no interactions.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/tokens.dart';

/// A static card displaying safety tips for meeting up in person.
class SafetyTipsCard extends StatelessWidget {
  /// Creates a SafetyTipsCard.
  const SafetyTipsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      key: const Key('safety_tips_card'),
      elevation: 0,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meeting up? Stay safe',
              key: const Key('safety_tips_card_title'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: WarmPlayfulSpacing.s3),
            _TipBullet(
              text: 'Meet in a public place',
              textTheme: textTheme,
            ),
            const SizedBox(height: WarmPlayfulSpacing.s2),
            _TipBullet(
              text: "Tell a friend where you're going",
              textTheme: textTheme,
            ),
            const SizedBox(height: WarmPlayfulSpacing.s2),
            _TipBullet(
              text: 'Trust your instincts',
              textTheme: textTheme,
            ),
            const SizedBox(height: WarmPlayfulSpacing.s2),
            _TipBullet(
              text: 'You can block or report anytime',
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single bullet tip within the card.
class _TipBullet extends StatelessWidget {
  /// Creates a _TipBullet.
  const _TipBullet({
    required this.text,
    required this.textTheme,
  });

  final String text;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            right: WarmPlayfulSpacing.s2,
            top: WarmPlayfulSpacing.s1,
          ),
          child: Container(
            width: WarmPlayfulSpacing.s1,
            height: WarmPlayfulSpacing.s1,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
