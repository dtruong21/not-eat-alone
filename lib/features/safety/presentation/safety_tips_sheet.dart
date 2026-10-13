/// The safety tips for meeting up in person, as a bottom sheet opened from the
/// chat's safety banner (and the list for Settings' Safety tips screen).
/// Static, scrollable at large text sizes.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

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
            Text(context.l10n.safetyTipsHeading, style: textTheme.titleLarge),
            const SizedBox(height: WarmPlayfulSpacing.s4),
            const SafetyTipsList(),
            const SizedBox(height: WarmPlayfulSpacing.s2),
            AppButton(
              label: context.l10n.safetyTipsGotIt,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four tips as bullets; shared by the sheet and the Safety tips screen.
class SafetyTipsList extends StatelessWidget {
  const SafetyTipsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tip in [
          l10n.safetyTipPublicPlace,
          l10n.safetyTipTellFriend,
          l10n.safetyTipInstincts,
          l10n.safetyTipBlockReport,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: WarmPlayfulSpacing.s3),
            child: _TipBullet(text: tip),
          ),
      ],
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
