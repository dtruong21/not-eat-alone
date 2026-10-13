import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/matching/application/create_request_controller.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/meal/application/maps_launcher_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../support/pump_localized.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _FakeCreateRequest extends CreateRequestController {
  _FakeCreateRequest({this.error});

  final Object? error;

  @override
  Future<void> request(Meal meal) async {
    state = const AsyncValue.loading();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    state = error == null
        ? const AsyncValue.data(null)
        : AsyncValue.error(error!, StackTrace.empty);
  }
}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: "L'Ami Jean",
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
final Meal _womenOnlyMeal = _meal.copyWith(womenOnly: true);
final Meal _cancelled = _meal.copyWith(status: MealStatus.cancelled);

JoinRequest _request(RequestStatus status) => JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
  status: status,
);

typedef _Case = ({
  String name,
  String viewer,
  Meal meal,
  Gender? gender,
  JoinRequest? request,
  bool loadError,
  String label,
  String? status,
});

final _cases = <_Case>[
  (
    name: 'own meal',
    viewer: 'host1',
    meal: _meal,
    gender: null,
    request: null,
    loadError: false,
    label: 'C’est ton repas',
    status: 'Tes demandes\u00a0: onglet Demandes.',
  ),
  (
    name: 'cancelled',
    viewer: 'guest1',
    meal: _cancelled,
    gender: null,
    request: null,
    loadError: false,
    label: 'Repas annulé',
    status: 'L’hôte a annulé ce repas.',
  ),
  (
    name: 'women only, not a woman',
    viewer: 'guest1',
    meal: _womenOnlyMeal,
    gender: Gender.man,
    request: null,
    loadError: false,
    label: 'Entre femmes',
    status: 'Réservé aux femmes.',
  ),
  (
    name: 'load error',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: null,
    loadError: true,
    label: 'Réessayer',
    status: 'Impossible de charger ta demande.',
  ),
  (
    name: 'no request',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: null,
    loadError: false,
    label: 'Demander à rejoindre',
    status: null,
  ),
  (
    name: 'pending',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: _request(RequestStatus.pending),
    loadError: false,
    label: 'Demande envoyée',
    status: 'L’hôte n’a pas encore répondu.',
  ),
  (
    name: 'approved',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: _request(RequestStatus.approved),
    loadError: false,
    label: 'Ouvrir la discussion',
    status: 'C’est un match\u00a0! Dis bonjour\u00a0!',
  ),
  (
    name: 'denied',
    viewer: 'guest1',
    meal: _meal,
    gender: null,
    request: _request(RequestStatus.denied),
    loadError: false,
    label: 'Pas cette fois',
    status: 'L’hôte a choisi quelqu’un d’autre.',
  ),
];

void main() {
  setUpAll(loadAppFonts);

  late _MockUserRepository userRepository;

  setUp(() {
    userRepository = _MockUserRepository();
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) => Stream.value(
        AppUser(
          uid: 'host1',
          dob: DateTime(1990, 3, 15),
          displayName: 'Alex',
          bio: 'Loves ramen.',
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required Meal meal,
    String viewer = 'guest1',
    Gender? gender,
    JoinRequest? request,
    bool loadError = false,
    CreateRequestController? controller,
    MapsLauncher? launcher,
    bool narrow = false,
    double? textScale,
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
          authStateProvider.overrideWith(
            (ref) => Stream.value(AuthUser(uid: viewer)),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(uid: viewer, dob: DateTime(1995, 6), gender: gender),
            ),
          ),
          mealRequestStateProvider(meal.id).overrideWith(
            (ref) => loadError
                ? Stream<JoinRequest?>.error(StateError('boom'))
                : Stream.value(request),
          ),
          if (controller != null)
            createRequestControllerProvider.overrideWith(() => controller),
          if (launcher != null)
            mapsLauncherProvider.overrideWithValue(launcher),
        ],
        child: MealDetailScreen(meal: meal),
      ),
      size: narrow ? const Size(320, 640) : null,
      textScale: textScale,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  final statusFinder = find.byKey(const Key('meal_action_status'));
  final barFinder = find.byKey(const Key('meal_action_bar'));

  testWidgets('detail screen strings are French, none stay English', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, meal: _womenOnlyMeal, gender: Gender.woman);

    expect(find.text('Détails du repas'), findsOneWidget);
    expect(find.text('Entre femmes'), findsOneWidget);
    expect(find.text('Hôte'), findsOneWidget);
    expect(find.textContaining('janv.'), findsOneWidget);
    expect(find.textContaining('19:30'), findsOneWidget);
    expect(find.text('Open in Maps'), findsNothing);
    expect(find.text('Ouvrir dans Maps'), findsOneWidget);
    expect(
      find.bySemanticsLabel("Ouvrir L'Ami Jean dans Maps"),
      findsOneWidget,
    );
    expect(find.text('Meal details'), findsNothing);
    expect(find.text('Women only'), findsNothing);
    expect(find.text('Host'), findsNothing);
    semantics.dispose();
  });

  testWidgets('host name and age use the French pattern', (tester) async {
    await pump(tester, meal: _meal);

    expect(
      find.textContaining(RegExp(r'^Alex, \d+\u00a0ans$')),
      findsOneWidget,
    );
  });

  testWidgets('a host without a name falls back to "Hôte"', (tester) async {
    when(() => userRepository.watch('host1')).thenAnswer(
      (_) => Stream.value(AppUser(uid: 'host1', dob: DateTime(1990, 3, 15))),
    );
    await pump(tester, meal: _meal);

    expect(
      find.textContaining(RegExp(r'^Hôte, \d+\u00a0ans$')),
      findsOneWidget,
    );
  });

  testWidgets('a missing host says "Hôte indisponible"', (tester) async {
    when(
      () => userRepository.watch('host1'),
    ).thenAnswer((_) => Stream.value(null));
    await pump(tester, meal: _meal);

    expect(find.text('Hôte indisponible'), findsOneWidget);
    expect(find.text('Host unavailable'), findsNothing);
  });

  testWidgets('the host block error is the shared French message', (
    tester,
  ) async {
    when(
      () => userRepository.watch('host1'),
    ).thenAnswer((_) => Stream<AppUser?>.error(StateError('boom')));
    await pump(tester, meal: _meal);

    expect(
      find.text('Oups, un problème est survenu. Réessaie.'),
      findsOneWidget,
    );
  });

  testWidgets('the safety menu is French', (tester) async {
    await pump(tester, meal: _meal);

    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Signaler ce repas'), findsOneWidget);
    expect(find.text('Signaler l’hôte'), findsOneWidget);
    expect(find.text('Bloquer l’hôte'), findsOneWidget);
    expect(find.text('Report this meal'), findsNothing);
    expect(find.text('Block host'), findsNothing);
  });

  testWidgets('a failed Maps launch shows a French snackbar', (tester) async {
    await pump(tester, meal: _meal, launcher: (_) async => false);

    await tester.tap(find.byKey(const Key('meal_detail_open_in_maps_button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Impossible d’ouvrir Maps'), findsOneWidget);
  });

  group('action bar', () {
    for (final c in _cases) {
      testWidgets('${c.name}: French label and status on one line at 1.3x', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          meal: c.meal,
          viewer: c.viewer,
          gender: c.gender,
          request: c.request,
          loadError: c.loadError,
          narrow: true,
          textScale: 1.3,
        );

        expect(
          find.descendant(of: barFinder, matching: find.text(c.label)),
          findsOneWidget,
        );
        if (c.status != null) {
          final text = find.descendant(
            of: statusFinder,
            matching: find.text(c.status!),
          );
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'status ellipsizes at 320 px / 1.3x: ${c.status}',
          );
          expect(
            tester.getSemantics(statusFinder).getSemanticsData().label,
            c.status,
          );
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('${c.name}: no overflow at 320 px and 2.0x', (tester) async {
        await pump(
          tester,
          meal: c.meal,
          viewer: c.viewer,
          gender: c.gender,
          request: c.request,
          loadError: c.loadError,
          narrow: true,
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the bar is the same size in every French state at 1.3x', (
      tester,
    ) async {
      final sizes = <String, Size>{};
      for (final c in _cases) {
        await pump(
          tester,
          meal: c.meal,
          viewer: c.viewer,
          gender: c.gender,
          request: c.request,
          loadError: c.loadError,
          narrow: true,
          textScale: 1.3,
        );
        sizes[c.name] = tester.getSize(barFinder);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(sizes.values.toSet().length, 1, reason: '$sizes');
    });

    testWidgets('"Demander à rejoindre" while sending reads "Envoi…"', (
      tester,
    ) async {
      await pump(tester, meal: _meal, controller: _FakeCreateRequest());

      await tester.tap(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      await tester.pump();

      expect(find.text('Envoi de la demande…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('a rejected request shows the French snackbars', (
      tester,
    ) async {
      await pump(
        tester,
        meal: _meal,
        controller: _FakeCreateRequest(error: StateError('nope')),
      );
      await tester.tap(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Impossible d’envoyer ta demande. Réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('a meal that closed shows its own French snackbar', (
      tester,
    ) async {
      await pump(
        tester,
        meal: _meal,
        controller: _FakeCreateRequest(error: MealNoLongerOpenException('m1')),
      );
      await tester.tap(
        find.byKey(const Key('meal_detail_request_to_join_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Ce repas n’est plus ouvert.'), findsOneWidget);
    });
  });

  testWidgets(
    'long French strings do not overflow the detail at 320 px, 2.0x',
    (tester) async {
      await pump(
        tester,
        meal: _womenOnlyMeal.copyWith(
          note: 'Une longue note pour vérifier le retour à la ligne. ' * 4,
        ),
        gender: Gender.woman,
        narrow: true,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    },
  );
}
