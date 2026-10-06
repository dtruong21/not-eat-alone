import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';

void main() {
  for (final b in Brightness.values) {
    group('button theme ($b)', () {
      Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(b),
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Enabled')),
                const FilledButton(onPressed: null, child: Text('Disabled')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Tonal'),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              ],
            ),
          ),
        ),
      );

      Color? fill(WidgetTester tester, String label) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.ancestor(
                    of: find.text(label),
                    matching: find.bySubtype<ButtonStyleButton>(),
                  ),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

      testWidgets('filled is coral with onPrimary label; disabled differs', (
        tester,
      ) async {
        await pump(tester);
        final scheme = buildTheme(b).colorScheme;
        expect(fill(tester, 'Enabled'), scheme.primary);
        expect(fill(tester, 'Disabled'), isNot(scheme.primary));
        final style = tester
            .widget<DefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('Enabled'),
                    matching: find.byType(DefaultTextStyle),
                  )
                  .first,
            )
            .style;
        expect(style.color, scheme.onPrimary);
      });

      testWidgets('tonal uses surface fill', (tester) async {
        await pump(tester);
        expect(fill(tester, 'Tonal'), buildTheme(b).colorScheme.surface);
      });

      testWidgets('every button is at least 48 tall', (tester) async {
        await pump(tester);
        for (final t in ['Enabled', 'Disabled', 'Tonal', 'Outlined']) {
          final h = tester
              .getSize(
                find.ancestor(
                  of: find.text(t),
                  matching: find.bySubtype<ButtonStyleButton>(),
                ),
              )
              .height;
          expect(h, greaterThanOrEqualTo(48), reason: t);
        }
      });

      testWidgets('outlined side is wp.muted', (tester) async {
        await pump(tester);
        final wp = buildTheme(b).extension<WarmPlayfulExtensions>()!;
        final btn = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
        final side =
            btn.style?.side?.resolve({}) ??
            Theme.of(
              tester.element(find.byType(OutlinedButton)),
            ).outlinedButtonTheme.style!.side!.resolve({});
        expect(side!.color, wp.muted);
      });

      test('elevated and chip labels use onAccent', () {
        final t = buildTheme(b);
        final wp = t.extension<WarmPlayfulExtensions>()!;
        expect(
          t.elevatedButtonTheme.style!.foregroundColor!.resolve({}),
          wp.onAccent,
        );
        expect(t.chipTheme.secondaryLabelStyle!.color, wp.onAccent);
      });
    });
  }

  for (final b in Brightness.values) {
    testWidgets('in-flight spinner is visible on the button fill ($b)', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(b),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                scheme = Theme.of(context).colorScheme;
                return FilledButton(
                  onPressed: null,
                  style: loadingFilledStyle(context, isLoading: true),
                  child: CircularProgressIndicator(color: scheme.onPrimary),
                );
              },
            ),
          ),
        ),
      );
      final fill = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(FilledButton),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(fill, scheme.primary);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final la = spinner.color!.computeLuminance();
      final lb = fill.computeLuminance();
      final ratio = (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
      expect(ratio, greaterThanOrEqualTo(3));
    });
  }

  testWidgets('extension copyWith/lerp cover dangerText, onAccent, shadow and '
      'context.wp', (tester) async {
    final light = buildTheme(Brightness.light);
    final dark = buildTheme(Brightness.dark);
    final a = light.extension<WarmPlayfulExtensions>()!;
    final d = dark.extension<WarmPlayfulExtensions>()!;
    const c = Color(0xFF123456);
    final cw = a.copyWith(dangerText: c, onAccent: c, shadow: c);
    expect(cw.dangerText, c);
    expect(cw.onAccent, c);
    expect(cw.shadow, c);
    expect(cw.muted, a.muted);
    final l = a.lerp(d, 1);
    expect(l.dangerText, d.dangerText);
    expect(l.onAccent, d.onAccent);
    expect(l.shadow, d.shadow);
    late WarmPlayfulExtensions got;
    await tester.pumpWidget(
      MaterialApp(
        theme: light,
        home: Builder(
          builder: (ctx) {
            got = ctx.wp;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(got.onAccent, a.onAccent);
  });
}
