import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import '../../support/contrast.dart';

void main() {
  for (final b in Brightness.values) {
    group('off-state and selected controls ($b)', () {
      final theme = buildTheme(b);
      final wp = theme.extension<WarmPlayfulExtensions>()!;
      final accent = theme.colorScheme.primary;
      final surface = theme.colorScheme.surface;
      const off = <WidgetState>{};
      const on = {WidgetState.selected};

      test('Switch off: muted thumb and outline, readable on the track', () {
        final s = theme.switchTheme;
        expect(s.thumbColor!.resolve(off), wp.muted);
        expect(s.trackOutlineColor!.resolve(off), wp.muted);
        expect(s.trackColor!.resolve(off), surface);
        expect(contrast(wp.muted, surface), greaterThanOrEqualTo(3));
      });

      test('Switch on: onAccent thumb on the accent track (>= 3:1)', () {
        final s = theme.switchTheme;
        expect(s.thumbColor!.resolve(on), wp.onAccent);
        expect(s.trackColor!.resolve(on), accent);
        expect(contrast(wp.onAccent, accent), greaterThanOrEqualTo(3));
      });

      test('Switch disabled keeps the Material defaults', () {
        final s = theme.switchTheme;
        expect(s.thumbColor!.resolve({WidgetState.disabled}), isNull);
      });

      testWidgets('SegmentedButton unselected side is muted', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('One')),
                  ButtonSegment(value: 2, label: Text('Two')),
                ],
                selected: const {1},
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        );
        final side = theme.segmentedButtonTheme.style!.side!.resolve(off)!;
        expect(side.color, wp.muted);
        expect(
          contrast(side.color, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(3),
        );
      });

      test('ChoiceChip checkmark is onAccent on the selected fill', () {
        final c = theme.chipTheme;
        expect(c.checkmarkColor, wp.onAccent);
        expect(
          contrast(c.checkmarkColor!, c.selectedColor!),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('TextButton is at least 48 high', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: TextButton(onPressed: () {}, child: const Text('Go')),
              ),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48),
        );
      });
    });
  }
}
