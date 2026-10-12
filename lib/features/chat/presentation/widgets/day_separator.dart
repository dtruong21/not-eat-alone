/// The centred day label between messages of different days.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

class DaySeparator extends StatelessWidget {
  const DaySeparator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: WarmPlayfulSpacing.s3),
    child: Center(
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.wp.muted),
      ),
    ),
  );
}
