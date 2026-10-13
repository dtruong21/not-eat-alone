import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/widgets/paris_notice.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../support/pump_localized.dart';

class _MockUserRepository extends Mock implements UserRepository {}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: "Bouillon Chartier de l'Opéra",
  address: '1 Rue de Rivoli, 75001 Paris',
  lat: 48.8566,
  lng: 2.3522,
);

final _meal = Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
  womenOnly: true,
);

void main() {
  setUpAll(loadAppFonts);

  late _MockUserRepository userRepository;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    userRepository = _MockUserRepository();
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) => Stream.value(
        AppUser(uid: 'host1', dob: DateTime(1990), displayName: 'Alex'),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    List<DiscoverableMeal> meals = const [],
    Gender viewerGender = Gender.woman,
    bool narrow = false,
    double? textScale,
    Locale locale = const Locale('fr'),
  }) async {
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await pumpLocalized(
      tester,
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          locationProvider.overrideWith(
            (ref) async => (lat: 48.8566, lng: 2.3522),
          ),
          discoveryControllerProvider.overrideWith(
            (ref) => Stream.value(meals),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(uid: 'v', dob: DateTime(1995), gender: viewerGender),
            ),
          ),
        ],
        child: const DiscoveryScreen(),
      ),
      locale: locale,
      size: narrow ? const Size(320, 640) : null,
      textScale: textScale,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty state and notice are French', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle(); // the FAB animates out on an empty feed

    expect(find.text('Pas encore de repas près de toi'), findsOneWidget);
    expect(
      find.text('Lance-toi\u00a0: propose un repas et quelqu’un te rejoindra.'),
      findsOneWidget,
    );
    expect(find.text('Créer un repas'), findsOneWidget);
    expect(
      find.text(
        'Convyve n’est qu’à Paris pour l’instant — on démarre tout juste.',
      ),
      findsOneWidget,
    );
    expect(find.text('No meals nearby yet'), findsNothing);
    expect(find.text('Create a meal'), findsNothing);
    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  testWidgets('a card shows the French badge, date, comma distance, host', (
    tester,
  ) async {
    await pump(
      tester,
      meals: [DiscoverableMeal(meal: _meal, distanceMeters: 1234)],
    );

    expect(find.text('Entre femmes'), findsOneWidget);
    expect(find.textContaining('1,2\u00a0km'), findsOneWidget);
    expect(find.textContaining('janv.'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Créer un repas'), findsOneWidget); // the FAB
    expect(find.text('Women only'), findsNothing);
    expect(find.textContaining('1.2 km'), findsNothing);
  });

  testWidgets('a card keeps English formatting under the English locale', (
    tester,
  ) async {
    await pump(
      tester,
      meals: [DiscoverableMeal(meal: _meal, distanceMeters: 1234)],
      locale: const Locale('en'),
    );

    expect(find.textContaining('1.2 km'), findsOneWidget);
    expect(find.text('Women only'), findsOneWidget);
  });

  testWidgets('distances round to one decimal in French', (tester) async {
    await pump(
      tester,
      meals: [DiscoverableMeal(meal: _meal, distanceMeters: 40)],
    );

    expect(find.textContaining('0,0\u00a0km'), findsOneWidget);
  });

  testWidgets('a host without a name reads "Hôte"', (tester) async {
    when(
      () => userRepository.watch('host1'),
    ).thenAnswer((_) => Stream.value(null));
    await pump(
      tester,
      meals: [DiscoverableMeal(meal: _meal, distanceMeters: 500)],
    );

    expect(find.text('Hôte'), findsOneWidget);
  });

  testWidgets('empty state has no overflow at 320 px and 2.0x', (tester) async {
    await pump(tester, narrow: true, textScale: 2);

    expect(tester.takeException(), isNull);
  });

  testWidgets('cards, badge and FAB have no overflow at 320 px and 2.0x', (
    tester,
  ) async {
    await pump(
      tester,
      meals: [
        DiscoverableMeal(meal: _meal, distanceMeters: 12345),
        DiscoverableMeal(
          meal: _meal.copyWith(id: 'm2', dateTime: DateTime(2027, 12, 25, 12)),
          distanceMeters: 99,
        ),
      ],
      narrow: true,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('ParisNotice alone has no overflow at 320 px and 2.0x', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLocalized(
      tester,
      ParisNotice(onDismiss: () {}),
      size: const Size(320, 640),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });
}
