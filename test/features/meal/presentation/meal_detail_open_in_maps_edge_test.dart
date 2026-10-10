import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/analytics/client.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/meal/application/maps_launcher_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

const _buttonKey = Key('meal_detail_open_in_maps_button');
const _cardKey = Key('meal_detail_restaurant_card');
const _failedText = "Couldn't open Maps";

Meal _meal({
  String name = 'Cafe Central',
  bool womenOnly = false,
  String hostId = 'host1',
}) => Meal(
  id: 'm1',
  hostId: hostId,
  restaurant: Restaurant(
    placeId: 'p1',
    name: name,
    address: '1 Rue de Rivoli, 75001 Paris',
    lat: 48.8566,
    lng: 2.3522,
  ),
  dateTime: DateTime(2027, 1, 5, 19, 30),
  geohash: 'u09tvw',
  womenOnly: womenOnly,
);

JoinRequest _request(RequestStatus status) => JoinRequest(
  id: 'r1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUserRepository userRepository;
  late List<String> events;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) => Stream.value(AppUser(uid: 'host1', dob: DateTime(1990, 3, 15))),
    );
    when(() => userRepository.watch('guest1')).thenAnswer(
      (_) => Stream.value(AppUser(uid: 'guest1', dob: DateTime(1995, 5, 5))),
    );
    // Route analytics through a recording sink so event ORDER relative to the
    // launcher is observable (the debugPrint path loses that).
    events = [];
    debugSetForceSend(true);
    debugSetLogSink((name, params) async => events.add(name));
  });

  tearDown(debugResetAnalytics);

  Future<void> pumpDetail(
    WidgetTester tester,
    Meal meal, {
    required MapsLauncher launcher,
    String viewerUid = 'guest1',
    Stream<JoinRequest?>? requestState,
    Gender? viewerGender,
    Brightness brightness = Brightness.light,
    double textScale = 1,
    TextDirection textDirection = TextDirection.ltr,
    Size? size,
    bool pushed = false,
  }) async {
    if (viewerGender != null) {
      when(() => userRepository.watch(viewerUid)).thenAnswer(
        (_) => Stream.value(
          AppUser(
            uid: viewerUid,
            dob: DateTime(1995, 5, 5),
            gender: viewerGender,
          ),
        ),
      );
    }
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(AuthUser(uid: viewerUid)),
          ),
          mealRequestStateProvider(
            meal.id,
          ).overrideWith((ref) => requestState ?? Stream.value(null)),
          mapsLauncherProvider.overrideWithValue(launcher),
        ],
        child: MaterialApp(
          theme: buildTheme(brightness),
          builder: (context, child) => Directionality(
            textDirection: textDirection,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
          home: pushed
              ? const Scaffold(body: Text('home'))
              : MealDetailScreen(meal: meal),
        ),
      ),
    );
    if (pushed) {
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => MealDetailScreen(meal: meal),
            ),
          );
      await tester.pumpAndSettle();
    }
    await tester.pump();
    await tester.pump();
  }

  group('who sees the action', () {
    testWidgets('host viewing their own meal still gets the action', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _meal(),
        viewerUid: 'host1',
        launcher: (_) async => true,
      );

      expect(find.byKey(_buttonKey), findsOneWidget);
      expect(
        find.byKey(const Key('meal_detail_your_meal_chip')),
        findsOneWidget,
      );
    });

    testWidgets('women-only meal: action shown to a non-woman viewer', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _meal(womenOnly: true),
        viewerGender: Gender.man,
        launcher: (_) async => true,
      );

      expect(find.byKey(_buttonKey), findsOneWidget);
      expect(find.text('This meal is women-only.'), findsOneWidget);
    });

    testWidgets('women-only meal: action shown to a woman viewer', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _meal(womenOnly: true),
        viewerGender: Gender.woman,
        launcher: (_) async => true,
      );

      expect(find.byKey(_buttonKey), findsOneWidget);
    });

    for (final status in RequestStatus.values) {
      testWidgets('request ${status.name}: action visible and tappable', (
        tester,
      ) async {
        var calls = 0;
        await pumpDetail(
          tester,
          _meal(),
          requestState: Stream.value(_request(status)),
          launcher: (_) async {
            calls++;
            return true;
          },
        );

        await tester.ensureVisible(find.byKey(_buttonKey));
        await tester.tap(find.byKey(_buttonKey));
        await tester.pump();

        expect(calls, 1);
        expect(events, ['directions_opened']);
      });
    }

    testWidgets('request state still loading: action usable', (tester) async {
      var calls = 0;
      await pumpDetail(
        tester,
        _meal(),
        requestState: const Stream<JoinRequest?>.empty(),
        launcher: (_) async {
          calls++;
          return true;
        },
      );

      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('request state errored: action usable', (tester) async {
      var calls = 0;
      await pumpDetail(
        tester,
        _meal(),
        requestState: Stream<JoinRequest?>.error(StateError('boom')),
        launcher: (_) async {
          calls++;
          return true;
        },
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();

      expect(calls, 1);
    });
  });

  group('tap sequencing', () {
    testWidgets('directions_opened fires BEFORE the launcher is invoked', (
      tester,
    ) async {
      final order = <String>[];
      debugSetLogSink((name, params) async => order.add('event:$name'));
      await pumpDetail(
        tester,
        _meal(),
        launcher: (_) async {
          order.add('launch');
          return true;
        },
      );

      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();

      expect(order, ['event:directions_opened', 'launch']);
    });

    testWidgets('a failed launch still counts the intent exactly once', (
      tester,
    ) async {
      await pumpDetail(tester, _meal(), launcher: (_) async => false);

      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();

      expect(events, ['directions_opened']);
      expect(find.text(_failedText), findsOneWidget);
    });

    testWidgets('a successful launch shows no snackbar', (tester) async {
      await pumpDetail(tester, _meal(), launcher: (_) async => true);

      await tester.tap(find.byKey(_buttonKey));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a throwing analytics sink does not block the launch', (
      tester,
    ) async {
      debugSetLogSink((_, _) async => throw StateError('analytics down'));
      var calls = 0;
      final logs = <String>[];
      final original = debugPrint;
      await pumpDetail(
        tester,
        _meal(),
        launcher: (_) async {
          calls++;
          return true;
        },
      );

      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        await tester.tap(find.byKey(_buttonKey));
        await tester.pump();
      } finally {
        debugPrint = original;
      }

      expect(calls, 1);
      expect(tester.takeException(), isNull);
      expect(logs.any((l) => l.contains('track failed')), isTrue);
    });

    testWidgets('a throwing launcher releases the double-tap guard', (
      tester,
    ) async {
      var calls = 0;
      await pumpDetail(
        tester,
        _meal(),
        launcher: (_) async {
          calls++;
          throw PlatformException(code: 'boom');
        },
      );

      // The provider contract says "never throws", so a violation surfaces as
      // an unhandled async error from the tap handler; collect it so the test
      // asserts only on the double-tap guard.
      final uncaught = <Object>[];
      Future<void> tapOnce() async {
        await runZonedGuarded(
          () => tester.tap(find.byKey(_buttonKey)),
          (error, _) => uncaught.add(error),
        );
        await tester.pump();
        await tester.pump();
      }

      await tapOnce();
      await tapOnce();

      expect(calls, 2, reason: '_launching must reset in finally');
      expect(uncaught, everyElement(isA<PlatformException>()));
    });

    testWidgets('the semantics tap action fires once, like a touch tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var calls = 0;
      await pumpDetail(
        tester,
        _meal(),
        launcher: (_) async {
          calls++;
          return true;
        },
      );

      tester.semantics.tap(find.semantics.byLabel('Open Cafe Central in Maps'));
      await tester.pump();

      expect(calls, 1);
      expect(events, ['directions_opened']);
      handle.dispose();
    });
  });

  group('lifecycle', () {
    testWidgets('failed launch resolving after the screen was popped is safe', (
      tester,
    ) async {
      final completer = Completer<bool>();
      await pumpDetail(
        tester,
        _meal(),
        pushed: true,
        launcher: (_) => completer.future,
      );

      await tester.tap(find.byKey(_buttonKey));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_buttonKey), findsNothing);

      completer.complete(false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_failedText), findsNothing);
    });

    testWidgets(
      'leaving the screen while the analytics send is in flight',
      (tester) async {
        final gate = Completer<void>();
        debugSetLogSink((name, params) => gate.future);
        var calls = 0;
        await pumpDetail(
          tester,
          _meal(),
          pushed: true,
          launcher: (_) async {
            calls++;
            return true;
          },
        );

        await tester.tap(find.byKey(_buttonKey));
        await tester.pump();
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();

        gate.complete();
        await tester.pumpAndSettle();

        // Must not throw "Cannot use ref after the widget was disposed".
        expect(tester.takeException(), isNull);
        expect(calls, lessThanOrEqualTo(1));
      },
    );
  });

  group('platform hand-off through the real default launcher', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<List<String>> tapOn(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
      final launched = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            launched.add(
              (call.arguments as Map<Object?, Object?>)['url']! as String,
            );
            return true;
          });
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpDetail(
        tester,
        _meal(name: 'Café & Co #1'),
        launcher: container.read(mapsLauncherProvider),
      );
      try {
        await tester.tap(find.byKey(_buttonKey));
        await tester.pump();
      } finally {
        // Reset before the test body ends: the framework's invariant check
        // runs before tearDown.
        debugDefaultTargetPlatformOverride = null;
      }
      return launched;
    }

    testWidgets('iOS opens Apple Maps over https', (tester) async {
      final launched = await tapOn(tester, TargetPlatform.iOS);

      expect(launched, hasLength(1));
      final uri = Uri.parse(launched.single);
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['q'], 'Café & Co #1');
      expect(uri.queryParameters['ll'], '48.8566,2.3522');
    });

    testWidgets('Android opens a geo: intent first', (tester) async {
      final launched = await tapOn(tester, TargetPlatform.android);

      expect(launched, hasLength(1));
      expect(launched.single, startsWith('geo:48.8566,2.3522?q='));
    });
  });

  group('layout', () {
    testWidgets('RTL: the action hugs the start (right) edge of the card', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _meal(),
        textDirection: TextDirection.rtl,
        launcher: (_) async => true,
      );

      final card = tester.getRect(find.byKey(_cardKey));
      final button = tester.getRect(find.byKey(_buttonKey));
      expect(card.right - button.right, lessThan(button.left - card.left));
      expect(button.width, lessThan(card.width / 2), reason: 'intrinsic width');
    });

    testWidgets('LTR: the action hugs the start (left) edge of the card', (
      tester,
    ) async {
      await pumpDetail(tester, _meal(), launcher: (_) async => true);

      final card = tester.getRect(find.byKey(_cardKey));
      final button = tester.getRect(find.byKey(_buttonKey));

      expect(button.left - card.left, lessThan(card.right - button.right));
    });

    testWidgets('2.0x text scale in LIGHT mode does not overflow', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _meal(),
        textScale: 2,
        launcher: (_) async => true,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(_buttonKey)).height,
        greaterThanOrEqualTo(48),
      );
    });

    for (final scenario in [
      (scale: 2.0, womenOnly: false),
      (scale: 1.5, womenOnly: true),
      (scale: 2.0, womenOnly: true),
    ]) {
      testWidgets('very long name at ${scenario.scale}x, '
          'womenOnly=${scenario.womenOnly}, 320dp phone', (tester) async {
        final longName = 'The Extraordinarily Long Restaurant Name ' * 25;
        await pumpDetail(
          tester,
          _meal(name: longName, womenOnly: scenario.womenOnly),
          textScale: scenario.scale,
          size: const Size(320, 640),
          launcher: (_) async => true,
        );

        expect(tester.takeException(), isNull);
        if (scenario.womenOnly) {
          expect(find.byKey(const Key('women_only_badge')), findsOneWidget);
        }
        await tester.ensureVisible(find.byKey(_buttonKey));
        await tester.pump();
        final card = tester.getRect(find.byKey(_cardKey));
        final button = tester.getRect(find.byKey(_buttonKey));
        expect(card.contains(button.center), isTrue);
        expect(button.right, lessThanOrEqualTo(card.right));
      });
    }

    testWidgets('long name semantics label is passed through verbatim', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDetail(
        tester,
        _meal(name: '寿司 🍣 & Co'),
        launcher: (_) async => true,
      );

      expect(find.bySemanticsLabel('Open 寿司 🍣 & Co in Maps'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dark + 1.5x text scale on a small screen: no overflow', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        _meal(),
        brightness: Brightness.dark,
        textScale: 1.5,
        size: const Size(320, 568),
        launcher: (_) async => true,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Open in Maps'), findsOneWidget);
    });
  });
}
