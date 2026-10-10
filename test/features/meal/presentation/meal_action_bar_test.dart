import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/create_request_controller.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

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
);

final _womenOnlyMeal = Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
  womenOnly: true,
);

JoinRequest _request(RequestStatus status) => JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
  status: status,
);

/// Stands in for the real controller: records calls, goes loading, then
/// settles (data or error) after 100 ms.
class _FakeCreateRequest extends CreateRequestController {
  _FakeCreateRequest({this.error, this.onLoading});

  final Object? error;
  final void Function()? onLoading;
  final calls = <Meal>[];

  @override
  Future<void> request(Meal meal) async {
    calls.add(meal);
    state = const AsyncValue.loading();
    onLoading?.call();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    state = error == null
        ? const AsyncValue.data(null)
        : AsyncValue.error(error!, StackTrace.empty);
  }
}

typedef _Case = ({
  String name,
  String viewer,
  Meal meal,
  Gender? gender,
  JoinRequest? request,
  String label,
  String? status,
  bool enabled,
  String buttonKey,
});

final _cases = <_Case>[
  (
    name: 'own meal',
    viewer: 'host1',
    meal: _meal,
    gender: null,
    request: null,
    label: 'This is your meal',
    status: "You'll see requests in the Requests tab.",
    enabled: false,
    buttonKey: 'meal_detail_your_meal_button',
  ),
  (
    name: 'women only, not a woman',
    viewer: 'guest1',
    meal: _womenOnlyMeal,
    gender: Gender.man,
    request: null,
    label: 'Women only',
    status: 'Only women can join this meal.',
    enabled: false,
    buttonKey: 'meal_detail_women_only_disabled_button',
  ),
  (
    name: 'no request',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: null,
    label: 'Request to join',
    status: null,
    enabled: true,
    buttonKey: 'meal_detail_request_to_join_button',
  ),
  (
    name: 'pending',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: _request(RequestStatus.pending),
    label: 'Requested',
    status: 'Waiting for the host to reply.',
    enabled: false,
    buttonKey: 'meal_detail_requested_button',
  ),
  (
    name: 'approved',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: _request(RequestStatus.approved),
    label: 'Open chat',
    status: "You're matched. Say hi!",
    enabled: true,
    buttonKey: 'meal_detail_matched_banner',
  ),
  (
    name: 'denied',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: _request(RequestStatus.denied),
    label: 'Not selected',
    status: 'The host chose someone else. Have a look at other meals.',
    enabled: false,
    buttonKey: 'meal_detail_not_selected_button',
  ),
];

void main() {
  late _MockUserRepository userRepository;

  setUp(() {
    userRepository = _MockUserRepository();
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) => Stream.value(
        AppUser(
          uid: 'host1',
          dob: DateTime(1990, 3, 15),
          displayName: 'Alex',
          bio: 'Loves ramen. ' * 40,
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required Meal meal,
    String viewer = 'guest1',
    Gender? gender,
    Stream<JoinRequest?>? requests,
    Stream<JoinRequest?> Function()? requestsBuilder,
    JoinRequest? request,
    _FakeCreateRequest? controller,
    double textScale = 1,
    GoRouter? router,
  }) async {
    final overrides = [
      userRepositoryProvider.overrideWithValue(userRepository),
      authStateProvider.overrideWith(
        (ref) => Stream.value(AuthUser(uid: viewer)),
      ),
      currentUserDocProvider.overrideWith(
        (ref) => Stream.value(
          AppUser(uid: viewer, dob: DateTime(1995, 6), gender: gender),
        ),
      ),
      mealRequestStateProvider(meal.id).overrideWith(
        (ref) => requestsBuilder?.call() ?? requests ?? Stream.value(request),
      ),
      if (controller != null)
        createRequestControllerProvider.overrideWith(() => controller),
    ];
    Widget builder(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: router == null
            ? MaterialApp(
                theme: buildTheme(Brightness.light),
                builder: builder,
                home: MealDetailScreen(meal: meal),
              )
            : MaterialApp.router(
                theme: buildTheme(Brightness.light),
                builder: builder,
                routerConfig: router,
              ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // Lets the skeleton's zero-length animate timer (gone once data lands)
    // fire; never pumpAndSettle with a skeleton on screen.
    await tester.pump(const Duration(milliseconds: 50));
  }

  final bar = find.byKey(const Key('meal_action_bar'));

  group('every state', () {
    Size? firstBarSize;

    /// Bar size of the plain "Request to join" state, for tests that run
    /// alone.
    Future<Size> baseline(WidgetTester tester) async {
      await pump(tester, meal: _meal);
      final size = tester.getSize(bar);
      await tester.pumpWidget(const SizedBox());
      return size;
    }

    for (final c in _cases) {
      testWidgets('${c.name}: full-width 56 high button, fixed bar', (
        tester,
      ) async {
        await pump(
          tester,
          meal: c.meal,
          viewer: c.viewer,
          gender: c.gender,
          request: c.request,
        );

        final buttonFinder = find.byKey(Key(c.buttonKey));
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<AppButton>(buttonFinder);
        expect(button.label, c.label);
        expect(button.onPressed != null, c.enabled);

        final barSize = tester.getSize(bar);
        final buttonSize = tester.getSize(buttonFinder);
        expect(buttonSize.width, barSize.width);
        expect(buttonSize.height, WarmPlayfulSize.actionHeight);

        // The bar is the same size in every state.
        firstBarSize ??= barSize;
        expect(barSize, firstBarSize);

        // Pinned at the bottom of the screen.
        expect(
          tester.getRect(bar).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );

        final status = find.byKey(const Key('meal_action_status'));
        if (c.status == null) {
          expect(
            find.descendant(of: status, matching: find.byType(Text)),
            findsNothing,
          );
        } else {
          expect(
            find.descendant(of: status, matching: find.text(c.status!)),
            findsOneWidget,
          );
          expect(
            tester.widget<Semantics>(status).properties.liveRegion,
            isTrue,
          );
        }
      });
    }

    testWidgets('loading request: skeleton, same bar size', (tester) async {
      final expected = await baseline(tester);
      await pump(
        tester,
        meal: _meal,
        requests: StreamController<JoinRequest?>().stream,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('meal_action_skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(bar), expected);
    });

    testWidgets('request error: retry row, same bar size, retry refetches', (
      tester,
    ) async {
      final expected = await baseline(tester);
      var calls = 0;
      // StateError: Riverpod's default retry skips Errors, so it lands at once.
      await pump(
        tester,
        meal: _meal,
        requestsBuilder: () => ++calls == 1
            ? Stream.error(StateError('boom'))
            : Stream.value(null),
      );

      expect(find.text("Couldn't load your request"), findsOneWidget);
      expect(tester.getSize(bar), expected);
      await tester.tap(
        find.byKey(const Key('meal_detail_request_retry_button')),
      );
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      expect(
        find.byKey(const Key('meal_detail_request_to_join_button')),
        findsOneWidget,
      );
    });
  });

  testWidgets('"Request to join" calls request(meal) once', (tester) async {
    final controller = _FakeCreateRequest();
    await pump(tester, meal: _meal, controller: controller);

    await tester.tap(
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    await tester.pump();
    // In flight: the button shows its loading label and ignores more taps.
    expect(find.text('Sending request…'), findsWidgets);
    await tester.tap(
      find.byKey(const Key('meal_detail_request_to_join_button')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.calls, [_meal]);
  });

  testWidgets('"Open chat" goes to /chats/<mealId>', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MealDetailScreen(meal: _meal),
        ),
        GoRoute(
          path: '/chats/:matchId',
          builder: (_, state) =>
              Text('chat ${state.pathParameters['matchId']}'),
        ),
      ],
    );
    await pump(
      tester,
      meal: _meal,
      request: _request(RequestStatus.approved),
      router: router,
    );

    await tester.tap(find.byKey(const Key('meal_detail_matched_banner')));
    await tester.pumpAndSettle();

    expect(find.text('chat m1'), findsOneWidget);
  });

  group('rejection feedback', () {
    testWidgets('generic failure: one snackbar, even after the button '
        'swapped to Requested', (tester) async {
      final requests = StreamController<JoinRequest?>();
      final controller = _FakeCreateRequest(
        error: Exception('network'),
        onLoading: () => requests.add(_request(RequestStatus.pending)),
      );
      await pump(
        tester,
        meal: _meal,
        requests: requests.stream,
        controller: controller,
      );
      requests.add(null);
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      await tester.pump();
      await tester.pump();
      // Optimistic swap: the Request button is gone.
      expect(
        find.byKey(const Key('meal_detail_request_to_join_button')),
        findsNothing,
      );
      expect(find.text('Requested'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(
        find.text("Couldn't send your request. Try again."),
        findsOneWidget,
      );
    });

    testWidgets('meal no longer open: its own copy', (tester) async {
      final controller = _FakeCreateRequest(
        error: MealNoLongerOpenException('m1'),
      );
      await pump(tester, meal: _meal, controller: controller);

      await tester.tap(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('This meal is no longer open.'), findsOneWidget);
      expect(find.text("Couldn't send your request. Try again."), findsNothing);
    });
  });

  testWidgets('320 px wide, 2.0x text, long note and bio: no overflow, bar '
      'stays on screen', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final longMeal = Meal(
      id: 'm1',
      hostId: 'host1',
      restaurant: _restaurant,
      dateTime: DateTime(2027, 1, 5, 19, 30),
      geohash: 'u09tvw',
      note: 'A very long note about the evening. ' * 30,
    );

    for (final c in _cases) {
      await tester.pumpWidget(const SizedBox());
      await pump(
        tester,
        meal: longMeal.copyWith(womenOnly: c.meal.womenOnly),
        viewer: c.viewer,
        gender: c.gender,
        request: c.request,
        textScale: 2,
      );
      expect(tester.takeException(), isNull, reason: c.name);
      final rect = tester.getRect(bar);
      expect(rect.bottom, lessThanOrEqualTo(640), reason: c.name);
      expect(rect.left, greaterThanOrEqualTo(0), reason: c.name);
      expect(rect.right, lessThanOrEqualTo(320), reason: c.name);
      expect(find.byKey(Key(c.buttonKey)), findsOneWidget, reason: c.name);
    }
  });

  group('safety menu', () {
    testWidgets('absent on your own meal', (tester) async {
      await pump(tester, meal: _meal, viewer: 'host1');
      expect(find.byKey(const Key('safety_actions_menu')), findsNothing);
    });

    testWidgets('present for other viewers', (tester) async {
      await pump(tester, meal: _meal);
      expect(find.byKey(const Key('safety_actions_menu')), findsOneWidget);
    });
  });
}
