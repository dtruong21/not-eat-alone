import 'package:flutter/material.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

/// Centered "nothing here" block: optional icon, title, optional body and
/// optional action. Scrollable (always, so a parent [RefreshIndicator] keeps
/// working) and safe at large text scales.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    required this.title,
    this.message,
    this.icon,
    this.action,
    this.mutedTitle = true,
    this.announce = false,
    super.key,
  });

  /// Headline.
  final String title;

  /// Optional supporting text under [title].
  final String? message;

  /// Optional icon above [title], in the muted colour.
  final IconData? icon;

  /// Optional call to action, usually an `AppButton`.
  final Widget? action;

  /// Whether [title] uses the muted colour (the body always does). Error
  /// states turn this off so the headline keeps full text contrast.
  final bool mutedTitle;

  /// Announce the title and message to screen readers when this appears
  /// (live region), e.g. when an error replaces a loading skeleton.
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final wp = context.wp;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    ExcludeSemantics(
                      child: Icon(
                        icon,
                        size: WarmPlayfulSize.stateIcon,
                        color: wp.muted,
                      ),
                    ),
                    const SizedBox(height: WarmPlayfulSpacing.s3),
                  ],
                  MergeSemantics(
                    child: Semantics(
                      liveRegion: announce,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: mutedTitle
                                ? text.titleMedium?.copyWith(color: wp.muted)
                                : text.titleMedium,
                          ),
                          if (message != null) ...[
                            const SizedBox(height: WarmPlayfulSpacing.s2),
                            Text(
                              message!,
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(color: wp.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: WarmPlayfulSpacing.s5),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
