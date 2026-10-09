import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

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
                const FilledButton.tonal(
                  onPressed: null,
                  child: Text('TonalOff'),
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
        final wp = buildTheme(b).extension<WarmPlayfulExtensions>()!;
        expect(fill(tester, 'Disabled'), wp.border);
        final off = tester
            .widget<DefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('Disabled'),
                    matching: find.byType(DefaultTextStyle),
                  )
                  .first,
            )
            .style;
        expect(off.color, wp.subtle);
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
        final wp = buildTheme(b).extension<WarmPlayfulExtensions>()!;
        expect(fill(tester, 'TonalOff'), wp.border);
      });

      testWidgets('every button is at least 48 tall', (tester) async {
        await pump(tester);
        for (final t in [
          'Enabled',
          'Disabled',
          'Tonal',
          'TonalOff',
          'Outlined',
        ]) {
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
        final t = buildTheme(b).outlinedButtonTheme.style!;
        final side = t.side!.resolve({})!;
        expect(side.color, wp.muted);
        expect(side.width, 1.5);
        expect(
          t.shape!.resolve({}),
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
          ),
        );
        // The rendered button picks the same side up.
        final rendered = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(OutlinedButton),
                matching: find.byType(Material),
              )
              .first,
        );
        expect((rendered.shape! as RoundedRectangleBorder).side, side);
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
      expect(
        loadingFilledStyle(
          tester.element(find.byType(FilledButton)),
          isLoading: false,
        ),
        isNull,
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
      expect(contrastRatio(spinner.color!, fill), greaterThanOrEqualTo(3));
    });
  }

  for (final b in Brightness.values) {
    group('components that used secondaryContainer ($b)', () {
      final theme = buildTheme(b);
      final scheme = theme.colorScheme;
      final wp = theme.extension<WarmPlayfulExtensions>()!;

      Color? materialColor(WidgetTester tester, Finder of) => tester
          .widget<Material>(
            find.descendant(of: of, matching: find.byType(Material)).first,
          )
          .color;

      testWidgets('NavigationBar: accent indicator, onAccent selected icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                  NavigationDestination(icon: Icon(Icons.chat), label: 'B'),
                ],
              ),
            ),
          ),
        );
        expect(theme.navigationBarTheme.indicatorColor, scheme.primary);
        final sel = IconTheme.of(tester.element(find.byIcon(Icons.home)));
        final unsel = IconTheme.of(tester.element(find.byIcon(Icons.chat)));
        expect(sel.color, wp.onAccent);
        expect(unsel.color, wp.muted);
        expect(
          contrastRatio(wp.onAccent, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('SegmentedButton: selected segment accent with onAccent', (
        tester,
      ) async {
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
        Finder btn(String t) => find.ancestor(
          of: find.text(t),
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        expect(materialColor(tester, btn('One')), scheme.primary);
        final label = tester
            .widget<DefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('One'),
                    matching: find.byType(DefaultTextStyle),
                  )
                  .first,
            )
            .style;
        expect(label.color, wp.onAccent);
        expect(materialColor(tester, btn('Two')), isNot(scheme.primary));
      });

      testWidgets('FAB: accent fill, onAccent icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
        expect(
          materialColor(tester, find.byType(FloatingActionButton)),
          scheme.primary,
        );
        expect(
          IconTheme.of(tester.element(find.byIcon(Icons.add))).color,
          wp.onAccent,
        );
      });
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
