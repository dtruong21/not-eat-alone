/// Safety tips (`/settings/safety`): the same four tips as the chat's
/// safety-tips sheet, reachable from Settings.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/safety/presentation/safety_tips_sheet.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.safetyTipsTitle)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
        children: [
          Text(
            context.l10n.safetyTipsHeading,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: WarmPlayfulSpacing.s4),
          const SafetyTipsList(),
        ],
      ),
    ),
  );
}
