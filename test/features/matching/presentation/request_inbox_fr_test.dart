import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/matching/application/request_meal_provider.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
import 'package:not_eat_alone/features/matching/presentation/request_inbox_screen.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockRequests extends Mock implements RequestRepository {}

class _MockUsers extends Mock implements UserRepository {}

const _request = JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
);

const _longName = "Marie-Charlotte d'Aubigné-O'Brien de Castelnau";

final _guest = AppUser(
  uid: 'guest1',
  dob: DateTime(1995),
  displayName: _longName,
  age: 31,
);

const _restaurant = Restaurant(
  placeId: 'p1',
  name: "L'Auberge de la Grande Fontaine Saint-Honoré",
  address: '1 Rue X',
  lat: 0,
  lng: 0,
);

Meal _meal(DateTime at) => Meal(
  id: 'm1',
  hostId: 'host1',
  restaurant: _restaurant,
  dateTime: at,
  geohash: 'abc',
);

void main() {
  setUpAll(loadAppFonts);

  late _MockRequests requests;
  late _MockUsers users;

  setUp(() {
    requests = _MockRequests();
    users = _MockUsers();
    when(() => users.watch('guest1')).thenAnswer((_) => Stream.value(_guest));
    registerFallbackValue(_request);
  });

  Future<void> pump(
    WidgetTester tester, {
    List<JoinRequest> inbox = const [_request],
    Meal? meal,
    bool narrow = false,
    double textScale = 1,
    List<String>? pushed,
  }) async {
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const RequestInboxScreen()),
        GoRoute(
          path: '/chats/:matchId',
          builder: (_, state) {
            pushed?.add(state.uri.toString());
            return const Scaffold(body: Text('chat screen'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'host1')),
          ),
          requestRepositoryProvider.overrideWithValue(requests),
          userRepositoryProvider.overrideWithValue(users),
          hostInboxProvider.overrideWith((ref) => Stream.value(inbox)),
          requestMealProvider('m1').overrideWith((ref) async => meal),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildTheme(Brightness.light),
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('screen, tile and guest label are French', (tester) async {
    await pump(tester, meal: _meal(DateTime(2099, 1, 5, 19, 30)));

    expect(find.text('Demandes'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('$_longName, 31\u00a0ans'), findsOneWidget);
    expect(find.textContaining('janv.'), findsOneWidget);
    for (final english in ['Requests', 'Approve', 'Deny', 'Guest']) {
      expect(find.text(english), findsNothing);
    }
  });

  testWidgets('empty inbox is French', (tester) async {
    await pump(tester, inbox: const []);

    expect(find.text('Aucune demande en attente'), findsOneWidget);
    expect(find.text('No pending requests'), findsNothing);
  });

  testWidgets('a past meal shows the French chip, tooltip and hint', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, meal: _meal(DateTime(2020, 1, 5, 19, 30)));

    expect(find.text('L’heure du repas est passée'), findsOneWidget);
    expect(find.byTooltip('L’heure du repas est passée'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const Key('request_inbox_approve_button_m1_guest1')),
          )
          .hint,
      'L’heure du repas est passée',
    );
    expect(find.text('Meal time has passed'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Deny success and failure snackbars are French', (tester) async {
    await pump(tester);
    when(() => requests.deny(any())).thenAnswer((_) async {});
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    expect(find.text('Demande refusée.'), findsOneWidget);
    expect(find.text('Request denied.'), findsNothing);

    when(() => requests.deny(any())).thenThrow(StateError('boom'));
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Impossible de refuser cette demande. '
        'Elle a peut-être déjà été traitée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Approve failure snackbars are French', (tester) async {
    await pump(tester);
    when(
      () => requests.approve(any()),
    ).thenThrow(MealNoLongerOpenException('m1'));
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(find.text('Ce repas n’est plus ouvert.'), findsOneWidget);

    when(() => requests.approve(any())).thenThrow(StateError('boom'));
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Impossible d’accepter cette demande. '
        'Elle a peut-être déjà été traitée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Approve shows the French busy label, then the Chat action', (
    tester,
  ) async {
    final pushed = <String>[];
    final gate = Completer<void>();
    when(() => requests.approve(any())).thenAnswer((_) => gate.future);
    await pump(tester, pushed: pushed);

    await tester.tap(find.text('Accepter'));
    await tester.pump();
    expect(find.text('Acceptation…'), findsOneWidget);
    expect(find.text('Approving…'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Demande acceptée. Tu peux discuter maintenant.'),
      findsOneWidget,
    );
    expect(find.text('Discuter'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    await tester.tap(find.text('Discuter'));
    await tester.pumpAndSettle();
    expect(pushed, ['/chats/m1']);
  });

  testWidgets('Deny shows the French busy label', (tester) async {
    final gate = Completer<void>();
    when(() => requests.deny(any())).thenAnswer((_) => gate.future);
    await pump(tester);

    await tester.tap(find.text('Refuser'));
    await tester.pump();
    expect(find.text('Refus…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('long French strings do not overflow at 320 px and 2.0x', (
    tester,
  ) async {
    await pump(
      tester,
      narrow: true,
      textScale: 2,
      meal: _meal(DateTime(2020, 1, 5, 19, 30)),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('L’heure du repas est passée'), findsOneWidget);
  });

  testWidgets('the future-meal tile does not overflow at 320 px and 2.0x', (
    tester,
  ) async {
    await pump(
      tester,
      narrow: true,
      textScale: 2,
      meal: _meal(DateTime(2099, 1, 5, 19, 30)),
    );
    expect(tester.takeException(), isNull);
  });
}
