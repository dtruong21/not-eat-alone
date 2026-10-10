import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/meal/presentation/widgets/paris_notice.dart';

void main() {
  var dismissed = 0;

  Future<void> pumpNotice(WidgetTester tester) async {
    dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: ParisNotice(onDismiss: () => dismissed++)),
      ),
    );
  }

  testWidgets('renders the Paris notice message', (tester) async {
    await pumpNotice(tester);

    expect(
      find.text("Convyve is Paris-only for now — we're just getting started here."),
      findsOneWidget,
    );
  });

  testWidgets('close has a Dismiss tooltip and calls onDismiss', (
    tester,
  ) async {
    await pumpNotice(tester);

    expect(find.byTooltip('Dismiss'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));

    expect(dismissed, 1);
  });
}
