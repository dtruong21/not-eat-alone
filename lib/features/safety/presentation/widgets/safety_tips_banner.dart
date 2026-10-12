/// A one-line banner above the chat thread: "Meeting up? Safety tips". Tapping
/// it opens the tips sheet; the close button hides it for this chat. It
/// replaces the fixed safety card that used to take a third of the screen.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

class SafetyTipsBanner extends StatelessWidget {
  const SafetyTipsBanner({
    required this.onOpen,
    required this.onDismiss,
    super.key,
  });

  /// Opens the tips sheet.
  final VoidCallback onOpen;

  /// Hides the banner.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('safety_tips_banner'),
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: WarmPlayfulSize.minTap,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: WarmPlayfulSpacing.s4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        size: WarmPlayfulSize.icon,
                        color: context.wp.muted,
                      ),
                      const SizedBox(width: WarmPlayfulSpacing.s3),
                      Expanded(
                        child: Text(
                          'Meeting up? Safety tips',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss safety tips',
            constraints: const BoxConstraints(
              minWidth: WarmPlayfulSize.minTap,
              minHeight: WarmPlayfulSize.minTap,
            ),
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, color: context.wp.muted),
          ),
        ],
      ),
    );
  }
}
