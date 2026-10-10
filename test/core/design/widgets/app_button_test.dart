import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';

import '../../../support/contrast.dart';

Widget _host(
  Brightness b,
  Widget button, {
  double width = 320,
  double textScale = 1,
}) => MaterialApp(
  theme: buildTheme(b),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: width, child: button),
      ),
    ),
  ),
);

Color? _fill(WidgetTester tester, Type button) => tester
    .widget<Material>(
      find
          .descendant(of: find.byType(button), matching: find.byType(Material))
          .first,
    )
    .color;

Color? _labelColor(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text))).style.color;

void main() {
  for (final b in Brightness.values) {
    group('AppButton ($b)', () {
      final theme = buildTheme(b);
      final scheme = theme.colorScheme;
      final wp = theme.extension<WarmPlayfulExtensions>()!;

      testWidgets('idle primary: coral fill, onPrimary label, 56 high, full '
          'width at 320', (tester) async {
        await tester.pumpWidget(
          _host(b, AppButton(label: 'Send code', onPressed: () {})),
        );
        expect(_fill(tester, FilledButton), scheme.primary);
        expect(_labelColor(tester, 'Send code'), scheme.onPrimary);
        final size = tester.getSize(find.byType(FilledButton));
        expect(size.height, greaterThanOrEqualTo(56));
        expect(size.width, 320);
      });

      testWidgets('height overrides the per-variant default', (tester) async {
        await tester.pumpWidget(
          _host(
            b,
            AppButton(
              label: 'Go',
              variant: AppButtonVariant.outlined,
              height: WarmPlayfulSize.actionHeight,
              onPressed: () {},
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(OutlinedButton)).height,
          WarmPlayfulSize.actionHeight,
        );
      });

      testWidgets('loading keeps the enabled fill, shows a visible spinner, '
          'swallows taps and keeps the size', (tester) async {
        var taps = 0;
        Widget build({required bool loading}) => _host(
          b,
          AppButton(
            label: 'Send code',
            loadingLabel: 'Sending…',
            isLoading: loading,
            onPressed: () => taps++,
          ),
        );
        await tester.pumpWidget(build(loading: false));
        final idle = tester.getSize(find.byType(AppButton));

        await tester.pumpWidget(build(loading: true));
        expect(tester.getSize(find.byType(AppButton)), idle);
        expect(_fill(tester, FilledButton), scheme.primary);
        final spinner = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(
          contrast(spinner.color!, scheme.primary),
          greaterThanOrEqualTo(3),
        );
        expect(
          tester.getSize(find.byType(CircularProgressIndicator)),
          const Size.square(WarmPlayfulSize.spinner),
        );
        expect(find.text('Sending…'), findsOneWidget);
        expect(find.text('Send code'), findsNothing);

        await tester.tap(find.byType(AppButton));
        await tester.pump();
        expect(taps, 0);
      });

      testWidgets('loading with an icon and no expand does not resize', (
        tester,
      ) async {
        Widget build({required bool loading}) => _host(
          b,
          Row(
            children: [
              AppButton(
                label: 'Go',
                loadingLabel: 'Going…',
                icon: const Icon(Icons.send),
                expand: false,
                isLoading: loading,
                onPressed: () {},
              ),
            ],
          ),
        );
        await tester.pumpWidget(build(loading: false));
        final idle = tester.getSize(find.byType(AppButton));
        await tester.pumpWidget(build(loading: true));
        expect(tester.getSize(find.byType(AppButton)), idle);
      });

      testWidgets('onPressed null renders the disabled look', (tester) async {
        await tester.pumpWidget(
          _host(b, const AppButton(label: 'Send code', onPressed: null)),
        );
        expect(_fill(tester, FilledButton), wp.border);
        expect(_labelColor(tester, 'Send code'), wp.subtle);
      });

      testWidgets('loading is announced as a live region with the loading '
          'label', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            b,
            AppButton(
              label: 'Send code',
              loadingLabel: 'Sending…',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        );
        final data = tester.getSemantics(find.byType(AppButton));
        expect(data.label, contains('Sending…'));
        expect(data.flagsCollection.isLiveRegion, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        handle.dispose();
      });

      for (final v in AppButtonVariant.values) {
        testWidgets('${v.name} renders and is >= 48 high', (tester) async {
          for (final loading in [false, true]) {
            await tester.pumpWidget(
              _host(
                b,
                AppButton(
                  label: 'Action',
                  variant: v,
                  isLoading: loading,
                  expand: false,
                  onPressed: () {},
                ),
              ),
            );
            expect(
              tester.getSize(find.byType(AppButton)).height,
              greaterThanOrEqualTo(48),
            );
          }
        });
      }

      testWidgets('no overflow at 2x text scale and 320 px', (tester) async {
        final sizes = <Size>[];
        for (final loading in [false, true]) {
          await tester.pumpWidget(
            _host(
              b,
              AppButton(
                label: 'Send the verification code to my phone now',
                loadingLabel: 'Sending the verification code to my phone…',
                isLoading: loading,
                onPressed: () {},
              ),
              textScale: 2,
            ),
          );
          expect(tester.takeException(), isNull);
          sizes.add(tester.getSize(find.byType(AppButton)));
        }
        expect(sizes[1], sizes[0], reason: 'idle and loading sizes differ');
      });
    });
  }
}
