import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

import '../../../helpers/load_app_fonts.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: 'Cafe Central',
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

final _discoverableMeal = DiscoverableMeal(meal: _meal, distanceMeters: 1234);

final _host = AppUser(
  uid: 'host1',
  dob: DateTime(1990),
  displayName: 'Alex',
);

AppUser _viewer(Gender gender) => AppUser(
      uid: 'viewer1',
      dob: DateTime(1995),
      gender: gender,
    );

void main() {
  // Real glyph widths: with Ahem every glyph is 1 em and the wrap checks at
  // large text mean nothing.
  setUpAll(loadAppFonts);

  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  var locationCalls = 0;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    locationCalls = 0;
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    when(() => userRepository.watch('host1'))
        .thenAnswer((_) => Stream.value(_host));
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    List<DiscoverableMeal> meals = const [],
    Stream<List<DiscoverableMeal>> Function()? mealsStream,
    Gender? viewerGender,
    Brightness brightness = Brightness.light,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DiscoveryScreen(),
        ),
        GoRoute(
          path: '/meals/new',
          builder: (context, state) => const Scaffold(body: Text('new-meal')),
        ),
        GoRoute(
          path: '/meals/detail',
          builder: (context, state) {
            final meal = state.extra! as Meal;
            return Scaffold(body: Text('detail:${meal.id}'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          userRepositoryProvider.overrideWithValue(userRepository),
          locationProvider.overrideWith((ref) async {
            locationCalls++;
            return (lat: 48.8566, lng: 2.3522);
          }),
          discoveryControllerProvider.overrideWith(
            (ref) => mealsStream != null ? mealsStream() : Stream.value(meals),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(_viewer(viewerGender ?? Gender.man)),
          ),
        ],
        child: MaterialApp.router(
          theme: buildTheme(brightness),
          routerConfig: router,
        ),
      ),
    );
    // Two pumps to let both StreamProviders resolve past AsyncLoading; the
    // second advances time so the skeleton's zero-delay shimmer start timer
    // (flutter_animate) fires and leaves nothing pending.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows the flavor-aware app title', (tester) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    expect(find.text('Convyve'), findsOneWidget);
  });

  testWidgets('renders a card with restaurant name and distance', (
    tester,
  ) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    expect(find.text(_restaurant.name), findsOneWidget);
    expect(find.textContaining('1.2 km'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('"Women only" badge shows for a woman viewer', (tester) async {
    await pumpDiscovery(
      tester,
      meals: [_discoverableMeal],
      viewerGender: Gender.woman,
    );

    expect(find.text('Women only'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('"Women only" badge is peach with onAccent text ($b)', (
      tester,
    ) async {
      await pumpDiscovery(
        tester,
        meals: [_discoverableMeal],
        viewerGender: Gender.woman,
        brightness: b,
      );

      final wp = buildTheme(b).extension<WarmPlayfulExtensions>()!;
      final badge = tester.widget<Container>(
        find.byKey(const Key('women_only_badge')),
      );
      expect((badge.decoration! as BoxDecoration).color, wp.peach);
      final text = tester.widget<Text>(find.text('Women only'));
      expect(text.style!.color, wp.onAccent);
      final la = wp.onAccent.computeLuminance();
      final lb = wp.peach.computeLuminance();
      final ratio = (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('"Women only" badge is hidden for a man viewer', (
    tester,
  ) async {
    await pumpDiscovery(
      tester,
      meals: [_discoverableMeal],
      viewerGender: Gender.man,
    );

    expect(find.text('Women only'), findsNothing);
  });

  testWidgets('tapping a card navigates to the meal detail route', (
    tester,
  ) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    await tester.tap(find.text(_restaurant.name));
    await tester.pumpAndSettle();

    expect(find.text('detail:${_meal.id}'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton list, not a spinner', (tester) async {
    await pumpDiscovery(
      tester,
      mealsStream: () => const Stream<List<DiscoverableMeal>>.empty(),
    );

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty feed: invites to host; button goes where the FAB goes', (
    tester,
  ) async {
    await pumpDiscovery(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No meals nearby yet'), findsOneWidget);
    expect(
      find.text('Be the first: host a meal and someone will join.'),
      findsOneWidget,
    );
    expect(find.byType(AppButton), findsOneWidget);
    await tester.pumpAndSettle(); // the FAB animates out once the feed is empty
    // One Create a meal button, not two: the FAB is hidden for an empty feed.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Create a meal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discovery_empty_create_button')));
    await tester.pumpAndSettle();

    expect(find.text('new-meal'), findsOneWidget);
  });

  testWidgets('the app bar has no sign-out button (it lives in Settings)', (
    tester,
  ) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    expect(find.byKey(const Key('discovery_sign_out_button')), findsNothing);
    expect(find.byTooltip('Sign out'), findsNothing);
  });

  testWidgets('a card has ONE muted meta text: when · how far', (tester) async {
    await pumpDiscovery(tester, meals: [_discoverableMeal]);

    final meta = tester.widget<Text>(
      find.text('${formatMealDateTime(_meal.dateTime)} · 1.2 km'),
    );
    final wp = buildTheme(Brightness.light).extension<WarmPlayfulExtensions>()!;
    expect(meta.maxLines, 2);
    expect(meta.overflow, TextOverflow.ellipsis);
    expect(meta.style!.color, wp.muted);
    expect(find.text('1.2 km'), findsNothing);
  });

  testWidgets('long names ellipsize at 320 px / 2.0x text: no overflow', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 800)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) =>
          Stream.value(_host.copyWith(displayName: 'Emilia Vasquez-Hernandez')),
    );
    final long = _meal.copyWith(
      restaurant: _restaurant.copyWith(
        name: 'Le Petit Café du Coin des Amis Réunis de la Rue Oberkampf',
      ),
    );

    await pumpDiscovery(
      tester,
      meals: [DiscoverableMeal(meal: long, distanceMeters: 1300)],
      viewerGender: Gender.woman,
    );

    expect(tester.takeException(), isNull);
    final name = tester.widget<Text>(find.text(long.restaurant.name));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    final host = tester.widget<Text>(find.text('Emilia Vasquez-Hernandez'));
    expect(host.maxLines, 1);
    expect(host.overflow, TextOverflow.ellipsis);

    // The meta wraps to a second line instead of cutting the distance.
    final whenText = formatMealDateTime(long.dateTime);
    final metaFinder = find.textContaining(whenText);
    final meta = tester.widget<Text>(metaFinder);
    expect(meta.data, '$whenText · 1.3 km');
    expect(
      tester.renderObject<RenderParagraph>(metaFinder).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getRect(metaFinder).left,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(Key('discovery_meal_card_${long.id}'))).left,
      ),
    );
  });

  testWidgets('the last card scrolls fully above the Create a meal button', (
    tester,
  ) async {
    final meals = [
      for (var i = 0; i < 6; i++)
        DiscoverableMeal(
          meal: _meal.copyWith(id: 'm$i'),
          distanceMeters: 1000.0 + i,
        ),
    ];
    await pumpDiscovery(tester, meals: meals);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final last = tester.getRect(
      find.byKey(const Key('discovery_meal_card_m5')),
    );
    final fab = tester.getRect(
      find.byKey(const Key('discovery_create_meal_button')),
    );
    expect(last.bottom, lessThanOrEqualTo(fab.top));
  });

  group('Paris notice', () {
    const noticeKey = Key('paris_notice_card');

    testWidgets('is the first item of the list and scrolls away', (
      tester,
    ) async {
      final meals = [
        for (var i = 0; i < 6; i++)
          DiscoverableMeal(meal: _meal.copyWith(id: 'm$i'), distanceMeters: 1),
      ];
      await pumpDiscovery(tester, meals: meals);

      expect(
        tester.getTopLeft(find.byKey(noticeKey)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('discovery_meal_card_m0'))).dy,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(find.byKey(noticeKey), findsNothing);
    });

    testWidgets('close is a 48 px target with a Dismiss tooltip; dismisses', (
      tester,
    ) async {
      await pumpDiscovery(tester, meals: [_discoverableMeal]);

      final size = tester.getSize(
        find.byKey(const Key('paris_notice_close_button')),
      );
      expect(size.width, greaterThanOrEqualTo(WarmPlayfulSize.minTap));
      expect(size.height, greaterThanOrEqualTo(WarmPlayfulSize.minTap));
      expect(find.byTooltip('Dismiss'), findsOneWidget);

      await tester.tap(find.byKey(const Key('paris_notice_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(noticeKey), findsNothing);
      expect(find.text(_restaurant.name), findsOneWidget);
    });

    testWidgets('stays above the empty state; dismissing keeps the state', (
      tester,
    ) async {
      await pumpDiscovery(tester);

      expect(find.byKey(noticeKey), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);

      await tester.tap(find.byKey(const Key('paris_notice_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(noticeKey), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('stays above the error state; dismissing keeps the state', (
      tester,
    ) async {
      await pumpDiscovery(
        tester,
        mealsStream: () =>
            Stream<List<DiscoverableMeal>>.error(StateError('x')),
      );

      expect(find.byKey(noticeKey), findsOneWidget);
      expect(find.byType(ErrorState), findsOneWidget);

      await tester.tap(find.byKey(const Key('paris_notice_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(noticeKey), findsNothing);
      expect(find.byType(ErrorState), findsOneWidget);
    });

    testWidgets('stays above the loading skeleton', (tester) async {
      await pumpDiscovery(
        tester,
        mealsStream: () => const Stream<List<DiscoverableMeal>>.empty(),
      );

      expect(find.byKey(noticeKey), findsOneWidget);
      expect(find.byType(SkeletonList), findsOneWidget);
    });
  });

  testWidgets('error shows ErrorState; Try again re-fetches the feed', (
    tester,
  ) async {
    var calls = 0;
    await pumpDiscovery(
      tester,
      mealsStream: () => ++calls == 1
          ? Stream<List<DiscoverableMeal>>.error(StateError('boom'))
          : Stream.value([_discoverableMeal]),
    );
    expect(find.byType(ErrorState), findsOneWidget);
    // Pull-to-refresh path: the location is read again too (not only the
    // feed provider invalidated).
    final locationBefore = locationCalls;

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(locationCalls, locationBefore + 1);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text(_restaurant.name), findsOneWidget);
  });
}
