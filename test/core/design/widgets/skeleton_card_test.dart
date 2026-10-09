import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  double textScale = 1,
}) => MaterialApp(
  theme: buildTheme(brightness),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(320, 600),
      disableAnimations: disableAnimations,
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final b in Brightness.values) {
    testWidgets('SkeletonCard ($b): surface card with wp.border blocks', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SkeletonCard(), brightness: b));
      // flutter_animate starts via a zero-delay timer, which pump() without a
      // duration never fires.
      await tester.pump(const Duration(milliseconds: 50));
      final theme = buildTheme(b);
      final wp = theme.extension<WarmPlayfulExtensions>()!;

      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SkeletonCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, theme.colorScheme.surface);
      expect(card.elevation, WarmPlayfulElevation.card);

      final blocks = find.byKey(const Key('skeleton_block'));
      expect(blocks, findsWidgets);
      for (final e in blocks.evaluate()) {
        final deco = (e.widget as DecoratedBox).decoration as BoxDecoration;
        expect(deco.color, wp.border);
      }
    });
  }

  testWidgets('lines and avatar are configurable', (tester) async {
    await tester.pumpWidget(
      _host(const SkeletonCard(lines: 2, showAvatar: false)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    // 2 line blocks, no avatar block.
    expect(find.byKey(const Key('skeleton_block')), findsNWidgets(2));
    await tester.pumpWidget(_host(const SkeletonCard(lines: 2)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('skeleton_block')), findsNWidgets(3));
  });

  testWidgets('animated: shimmer runs and never settles; static when '
      'animations are disabled', (tester) async {
    await tester.pumpWidget(_host(const SkeletonCard()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Animate), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(const SkeletonCard(), disableAnimations: true),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Animate), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('SkeletonList renders count cards without overflow in a tight '
      'box and is not scrollable', (tester) async {
    await tester.pumpWidget(
      _host(const SizedBox(height: 150, child: SkeletonList(count: 4))),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonCard), findsWidgets);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('SkeletonMessages renders bubbles; static when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SkeletonMessages(), disableAnimations: true),
    );
    expect(find.byKey(const Key('skeleton_block')), findsWidgets);
    expect(find.byType(Animate), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2.0x text does not overflow', (tester) async {
    await tester.pumpWidget(
      _host(const SkeletonList(), textScale: 2, disableAnimations: true),
    );
    expect(tester.takeException(), isNull);
  });
}
