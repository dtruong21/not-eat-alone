import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_tips_card.dart';

void main() {
  testWidgets('SafetyTipsCard renders title and tips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: SafetyTipsCard(),
        ),
      ),
    );

    expect(find.byKey(const Key('safety_tips_card')), findsOneWidget);
    expect(find.text('Meeting up? Stay safe'), findsOneWidget);
    expect(find.text('Meet in a public place'), findsOneWidget);
    expect(find.text("Tell a friend where you're going"), findsOneWidget);
    expect(find.text('Trust your instincts'), findsOneWidget);
    expect(find.text('You can block or report anytime'), findsOneWidget);
  });
}
