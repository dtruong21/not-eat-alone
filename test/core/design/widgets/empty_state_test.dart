import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(320, 600),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: SizedBox(width: 320, height: 600, child: child)),
  ),
);

void main() {
  testWidgets('title only: no body, no button', (tester) async {
    await tester.pumpWidget(_host(const EmptyState(title: 'Nothing yet')));
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('icon, message and action render; action is tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        EmptyState(
          title: 'No meals',
          message: 'Create one.',
          icon: Icons.restaurant_rounded,
          action: AppButton(label: 'Create', onPressed: () => taps++),
        ),
      ),
    );
    expect(find.text('Create one.'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    await tester.tap(find.text('Create'));
    expect(taps, 1);
  });

  testWidgets('muted text colour and no overflow at 2.0x', (tester) async {
    await tester.pumpWidget(
      _host(
        const EmptyState(title: 'No chats yet', message: 'Match on a meal.'),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final wp = buildTheme(Brightness.light).extension<WarmPlayfulExtensions>()!;
    final body = tester.widget<Text>(find.text('Match on a meal.'));
    expect(body.style?.color, wp.muted);
  });
}
