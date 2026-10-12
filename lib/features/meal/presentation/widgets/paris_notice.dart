/// A soft, dismissible info banner notifying users that Convyve is
/// currently Paris-only. Shown as the first item of the discovery feed.
///
/// Stateless: the discovery screen owns the per-session dismissed flag (so
/// the choice survives the list rebuilding or being scrolled). Persisting it
/// across sessions would need `shared_preferences`, which is not a dependency.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/tokens.dart';

/// A dismissible banner informing users that Convyve is Paris-only for now.
class ParisNotice extends StatelessWidget {
  /// Creates a ParisNotice.
  const ParisNotice({required this.onDismiss, super.key});

  /// Called when the close button is tapped.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const Key('paris_notice_card'),
      margin: EdgeInsets.zero,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: WarmPlayfulSpacing.s4,
          top: WarmPlayfulSpacing.s2,
          bottom: WarmPlayfulSpacing.s2,
          right: WarmPlayfulSpacing.s1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Convyve is Paris-only for now — '
                "we're just getting started here.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
            IconButton(
              key: const Key('paris_notice_close_button'),
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded),
              onPressed: onDismiss,
              constraints: const BoxConstraints(
                minWidth: WarmPlayfulSize.minTap,
                minHeight: WarmPlayfulSize.minTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
