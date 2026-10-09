import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';

Widget _host(Widget child, {double width = 320, double textScale = 1}) =>
    MaterialApp(
      theme: buildTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(width: width, height: 600, child: child),
        ),
      ),
    );

void main() {
  testWidgets('shows default title, message and a Try again button that '
      'calls onRetry once', (tester) async {
    var retries = 0;
    await tester.pumpWidget(_host(ErrorState(onRetry: () => retries++)));

    expect(find.text("Couldn't load this"), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('custom title and message', (tester) async {
    await tester.pumpWidget(
      _host(ErrorState(onRetry: () {}, title: 'Oops', message: 'Later.')),
    );
    expect(find.text('Oops'), findsOneWidget);
    expect(find.text('Later.'), findsOneWidget);
  });

  testWidgets('320 px wide at 2.0x text: no overflow, still reachable', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ErrorState(onRetry: () {}), textScale: 2));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Try again'));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('exposes title, message and the retry button to semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(ErrorState(onRetry: () {})));
    expect(find.bySemanticsLabel("Couldn't load this"), findsOneWidget);
    expect(
      find.bySemanticsLabel('Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    handle.dispose();
  });
}
