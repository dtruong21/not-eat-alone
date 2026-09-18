import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/features/home/placeholder_home.dart';

void main() {
  testWidgets('shows the flavor-aware app title', (tester) async {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);

    await tester.pumpWidget(const MaterialApp(home: PlaceholderHome()));

    expect(find.text('not-eat-alone'), findsOneWidget);
  });
}
