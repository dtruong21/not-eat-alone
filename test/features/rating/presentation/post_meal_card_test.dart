import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/rating/application/my_rating_provider.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/post_meal_card.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

import '../../../helpers/load_app_fonts.dart';

final _past = Meal(
  id: 'm1',
  hostId: 'h',
  restaurant: const Restaurant(
    placeId: 'p',
    name: 'Cafe',
    address: 'a',
    lat: 0,
    lng: 0,
  ),
  dateTime: DateTime(2020, 1, 1, 19),
  geohash: 'u09tvw',
);

/// UX plan 18, task 3: the post-meal card's call to action is a primary
/// button that names the person.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester, {
    String? name,
    double scale = 1,
    Size size = const Size(360, 800),
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchMealProvider.overrideWith((ref, id) async => _past),
          myRatingProvider.overrideWith((ref, id) => Stream.value(null)),
          userDocProvider('them').overrideWith(
            (ref) => Stream.value(
              name == null ? null : AppUser(uid: 'them', displayName: name),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: PostMealCard(matchId: 'm1', targetUid: 'them'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppButton button(WidgetTester tester) => tester.widget<AppButton>(
    find.byKey(const Key('post_meal_card_rate_button')),
  );

  testWidgets('Rate is a primary AppButton naming the person', (tester) async {
    await pump(tester, name: 'Giulia');
    expect(button(tester).label, 'Rate Giulia');
    expect(button(tester).variant, AppButtonVariant.primary);
  });

  testWidgets('Rate falls back to plain "Rate"', (tester) async {
    await pump(tester);
    expect(button(tester).label, 'Rate');
  });

  testWidgets('long name at 320 px / 2.0x does not overflow', (tester) async {
    await pump(
      tester,
      name: 'Maximilian-Alexander von Hohenzollern',
      scale: 2,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('post_meal_card_rate_button')), findsOneWidget);
  });
}
