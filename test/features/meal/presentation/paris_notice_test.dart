import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/meal/presentation/widgets/paris_notice.dart';

void main() {
  testWidgets('renders the Paris notice message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: ParisNotice(),
        ),
      ),
    );

    expect(
      find.text("Convyve is Paris-only for now — we're just getting started here."),
      findsOneWidget,
    );
  });

  testWidgets('tapping close dismisses the notice for the session',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: ParisNotice(),
        ),
      ),
    );

    // Message is visible initially
    expect(
      find.text("Convyve is Paris-only for now — we're just getting started here."),
      findsOneWidget,
    );

    // Tap the close icon
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Message is gone (SizedBox.shrink renders nothing)
    expect(
      find.text("Convyve is Paris-only for now — we're just getting started here."),
      findsNothing,
    );
  });
}
