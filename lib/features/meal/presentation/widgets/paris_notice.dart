/// A soft, dismissible info banner notifying users that Convyve is
/// currently Paris-only. Shown at the top of the discovery feed.
///
/// The notice is dismissed for the session via a local `bool _dismissed` flag
/// (no persistence). When dismissed, renders `SizedBox.shrink()`.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/tokens.dart';

/// A dismissible banner informing users that Convyve is Paris-only for now.
class ParisNotice extends StatefulWidget {
  /// Creates a ParisNotice.
  const ParisNotice({super.key});

  @override
  State<ParisNotice> createState() => _ParisNoticeState();
}

class _ParisNoticeState extends State<ParisNotice> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      child: Card(
        key: const Key('paris_notice_card'),
        elevation: 0,
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "Convyve is Paris-only for now — we're just getting started here.",
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s2),
              IconButton(
                key: const Key('paris_notice_close_button'),
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _dismissed = true;
                  });
                },
                iconSize: WarmPlayfulSpacing.s5,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: WarmPlayfulSpacing.s5,
                  minHeight: WarmPlayfulSpacing.s5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
