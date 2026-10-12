import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/safety/presentation/safety_tips_screen.dart';

void main() {
  testWidgets('shows the same four tips as the chat sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const SafetyTipsScreen(),
      ),
    );

    expect(find.text('Safety tips'), findsOneWidget);
    for (final tip in [
      'Meet in a public place',
      "Tell a friend where you're going",
      'Trust your instincts',
      'You can block or report anytime',
    ]) {
      expect(find.text(tip), findsOneWidget);
    }
  });
}
