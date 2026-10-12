import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';

Widget _host(
  Widget child, {
  double width = 320,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: buildTheme(brightness),
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

  testWidgets('320 px wide at 2.0x text, animations enabled: no overflow, '
      'still reachable', (tester) async {
    await tester.pumpWidget(_host(ErrorState(onRetry: () {}), textScale: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Try again'));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('announces title and message as one live region, with the '
      'retry button separate', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(ErrorState(onRetry: () {})));
    expect(
      tester.getSemantics(find.text("Couldn't load this")),
      matchesSemantics(
        label: "Couldn't load this\nCheck your connection and try again.",
        isLiveRegion: true,
      ),
    );
    expect(find.bySemanticsLabel('Try again'), findsOneWidget);
    handle.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('($b) title keeps the default colour, body and icon are '
        'wp.muted', (tester) async {
      await tester.pumpWidget(_host(ErrorState(onRetry: () {}), brightness: b));
      final theme = buildTheme(b);
      final wp = theme.extension<WarmPlayfulExtensions>()!;
      final title = tester.widget<Text>(find.text("Couldn't load this"));
      expect(title.style?.color, theme.textTheme.titleMedium?.color);
      expect(title.style?.color, isNot(wp.muted));
      final body = tester.widget<Text>(
        find.text('Check your connection and try again.'),
      );
      expect(body.style?.color, wp.muted);
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded));
      expect(icon.color, wp.muted);
    });
  }
}
