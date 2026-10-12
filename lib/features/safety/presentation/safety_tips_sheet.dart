/// The safety tips for meeting up in person, as a bottom sheet opened from the
/// chat's safety banner. Static, scrollable at large text sizes.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';

const _tips = [
  'Meet in a public place',
  "Tell a friend where you're going",
  'Trust your instincts',
  'You can block or report anytime',
];

/// Opens the safety tips sheet.
Future<void> showSafetyTipsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _SafetyTipsSheet(),
    );

class _SafetyTipsSheet extends StatelessWidget {
  const _SafetyTipsSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      key: const Key('safety_tips_sheet'),
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meeting up? Stay safe', style: textTheme.titleLarge),
            const SizedBox(height: WarmPlayfulSpacing.s4),
            for (final tip in _tips)
              Padding(
                padding: const EdgeInsets.only(bottom: WarmPlayfulSpacing.s3),
                child: _TipBullet(text: tip),
              ),
            const SizedBox(height: WarmPlayfulSpacing.s2),
            AppButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBullet extends StatelessWidget {
  const _TipBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          right: WarmPlayfulSpacing.s3,
          top: WarmPlayfulSpacing.s2,
        ),
        child: Container(
          width: WarmPlayfulSpacing.s2,
          height: WarmPlayfulSpacing.s2,
          decoration: BoxDecoration(
            color: context.wp.muted,
            shape: BoxShape.circle,
          ),
        ),
      ),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
