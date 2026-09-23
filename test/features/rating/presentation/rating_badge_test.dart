import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

Future<void> pumpBadge(WidgetTester tester, AppUser user) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userDocProvider('u1').overrideWith((ref) => Stream.value(user)),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(body: RatingBadge(uid: 'u1')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the average (one decimal) and count when rated',
      (tester) async {
    await pumpBadge(
      tester,
      AppUser(
        uid: 'u1',
        dob: DateTime(1990, 1, 1),
        ratingAvg: 4.5,
        ratingCount: 8,
      ),
    );

    expect(find.text('4.5 (8)'), findsOneWidget);
  });

  testWidgets('shows "New" when ratingCount is 0', (tester) async {
    await pumpBadge(
      tester,
      AppUser(uid: 'u1', dob: DateTime(1990, 1, 1)),
    );

    expect(find.text('New'), findsOneWidget);
  });
}
