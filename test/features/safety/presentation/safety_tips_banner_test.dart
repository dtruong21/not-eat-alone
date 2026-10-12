import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/safety/presentation/safety_tips_sheet.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_tips_banner.dart';

Widget _app(Widget body) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: Scaffold(body: body),
);

void main() {
  testWidgets('banner is one tappable line with a dismiss control', (
    tester,
  ) async {
    var opened = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      _app(
        SafetyTipsBanner(onOpen: () => opened++, onDismiss: () => dismissed++),
      ),
    );

    expect(find.text('Meeting up? Safety tips'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('safety_tips_banner'))).height,
      lessThanOrEqualTo(56),
    );

    await tester.tap(find.text('Meeting up? Safety tips'));
    expect(opened, 1);
    await tester.tap(find.byTooltip('Dismiss safety tips'));
    expect(dismissed, 1);
  });

  testWidgets('banner tap targets are at least 48 dp', (tester) async {
    await tester.pumpWidget(
      _app(SafetyTipsBanner(onOpen: () {}, onDismiss: () {})),
    );
    expect(
      tester.getSize(find.byTooltip('Dismiss safety tips')).shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('safety_tips_banner'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('showSafetyTipsSheet lists the four tips and closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSafetyTipsSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety_tips_sheet')), findsOneWidget);
    expect(find.text('Meeting up? Stay safe'), findsOneWidget);
    expect(find.text('Meet in a public place'), findsOneWidget);
    expect(find.text("Tell a friend where you're going"), findsOneWidget);
    expect(find.text('Trust your instincts'), findsOneWidget);
    expect(find.text('You can block or report anytime'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety_tips_sheet')), findsNothing);
  });

  testWidgets('the sheet scrolls at 320 px / 2.0x text without overflow', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSafetyTipsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('safety_tips_sheet')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });
}
