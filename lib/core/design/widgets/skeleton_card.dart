import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

/// Shimmers [child] in a loop, or leaves it still when the platform asks for
/// reduced motion. The loop never settles, so tests that show a skeleton must
/// `pump(Duration)`, not `pumpAndSettle`.
Widget _shimmer(BuildContext context, Widget child) =>
    MediaQuery.disableAnimationsOf(context)
    ? child
    : child
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
            duration: WarmPlayfulSkeleton.shimmer,
            color: context.wp.divider,
          );

class _Block extends StatelessWidget {
  const _Block({required this.height, this.width, this.circle = false});

  final double height;
  final double? width;
  final bool circle;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      key: const Key('skeleton_block'),
      decoration: BoxDecoration(
        color: context.wp.border,
        borderRadius: BorderRadius.circular(
          circle ? WarmPlayfulRadius.pill : WarmPlayfulRadius.sm,
        ),
      ),
    ),
  );
}

/// Card-shaped loading placeholder: an optional avatar and [lines] text
/// blocks on a surface card.
class SkeletonCard extends StatelessWidget {
  /// Creates a skeleton card.
  const SkeletonCard({this.lines = 3, this.showAvatar = true, super.key});

  /// Number of text-line blocks; the last one is shorter.
  final int lines;

  /// Show a round avatar block at the leading edge.
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final blocks = Row(
      children: [
        if (showAvatar) ...[
          const _Block(
            height: WarmPlayfulSkeleton.avatar,
            width: WarmPlayfulSkeleton.avatar,
            circle: true,
          ),
          const SizedBox(width: WarmPlayfulSpacing.s3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines; i++) ...[
                if (i > 0) const SizedBox(height: WarmPlayfulSpacing.s2),
                FractionallySizedBox(
                  widthFactor: i == lines - 1 && lines > 1
                      ? WarmPlayfulSkeleton.lastLineWidthFactor
                      : 1,
                  child: const _Block(height: WarmPlayfulSkeleton.lineHeight),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return ExcludeSemantics(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: WarmPlayfulElevation.card,
        shadowColor: context.wp.shadow,
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
          child: _shimmer(context, blocks),
        ),
      ),
    );
  }
}

/// A non-scrolling stack of [SkeletonCard]s with the feed lists' padding;
/// clips rather than overflows when the space is short.
class SkeletonList extends StatelessWidget {
  /// Creates a list of [count] skeleton cards.
  const SkeletonList({this.count = 3, super.key});

  /// Number of cards.
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    liveRegion: true,
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      itemCount: count,
      separatorBuilder: (context, index) =>
          const SizedBox(height: WarmPlayfulSpacing.s3),
      itemBuilder: (context, index) => const SkeletonCard(),
    ),
  );
}

/// Chat-shaped loading placeholder: alternating incoming/outgoing bubbles.
class SkeletonMessages extends StatelessWidget {
  /// Creates [count] alternating skeleton bubbles.
  const SkeletonMessages({this.count = 4, super.key});

  /// Number of bubbles.
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    liveRegion: true,
    child: ExcludeSemantics(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
        itemCount: count,
        separatorBuilder: (context, index) =>
            const SizedBox(height: WarmPlayfulSpacing.s3),
        itemBuilder: (context, index) => Align(
          alignment: index.isEven
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          child: FractionallySizedBox(
            widthFactor: WarmPlayfulSkeleton.bubbleWidthFactor,
            child: _shimmer(
              context,
              const _Block(height: WarmPlayfulSkeleton.bubbleHeight),
            ),
          ),
        ),
      ),
    ),
  );
}
