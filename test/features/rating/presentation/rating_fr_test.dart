import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/rating/application/my_rating_provider.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';
import 'package:not_eat_alone/features/rating/presentation/rating_sheet.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/post_meal_card.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_fr.dart';

import '../../../helpers/load_app_fonts.dart';

class _FakeRatingController extends RatingController {
  _FakeRatingController({this.fail = false});

  final bool fail;

  @override
  Future<void> submit({
    required String matchId,
    required String targetUid,
    required int stars,
    required bool showedUp,
    String? comment,
  }) async {
    state = fail
        ? AsyncValue.error(StateError('boom'), StackTrace.empty)
        : const AsyncValue.data(null);
  }
}

const _longName = "Marie-Charlotte d'Aubigné-O'Brien de Castelnau-Montalembert";

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

/// French copy for ratings: sheet, post-meal card and badge.
void main() {
  setUpAll(loadAppFonts);

  void narrow(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    String? name,
    AppUser? user,
    bool fail = false,
    double textScale = 1,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        ratingControllerProvider.overrideWith(
          () => _FakeRatingController(fail: fail),
        ),
        matchMealProvider.overrideWith((ref, id) async => _past),
        myRatingProvider.overrideWith((ref, id) => Stream.value(null)),
        userDocProvider('them').overrideWith(
          (ref) => Stream.value(
            user ??
                (name == null ? null : AppUser(uid: 'them', displayName: name)),
          ),
        ),
      ],
      child: MaterialApp(
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
        home: Scaffold(body: SingleChildScrollView(child: home)),
      ),
    ),
  );

  Future<void> openSheet(
    WidgetTester tester, {
    String? name,
    bool fail = false,
    double textScale = 1,
  }) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showRatingSheet(
            context,
            matchId: 'm1',
            targetUid: 'them',
            partnerName: name,
          ),
          child: const Text('open'),
        ),
      ),
      fail: fail,
      textScale: textScale,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('rating sheet', () {
    testWidgets('title, switch, hint and Submit are French', (tester) async {
      await openSheet(tester, name: "Jean d'Arc");
      expect(
        find.text("Comment s’est passé ton repas avec Jean d'Arc\u00a0?"),
        findsOneWidget,
      );
      expect(find.text('La personne est-elle venue\u00a0?'), findsOneWidget);
      expect(find.text('Ajoute un commentaire (facultatif)'), findsOneWidget);
      expect(find.text('Envoyer'), findsOneWidget);
      for (final en in ['Did they show up?', 'Submit']) {
        expect(find.text(en), findsNothing);
      }
    });

    testWidgets('unnamed title', (tester) async {
      await openSheet(tester);
      expect(find.text('Comment s’est passé ton repas\u00a0?'), findsOneWidget);
    });

    testWidgets('star tooltips pluralise (1 and many)', (tester) async {
      await openSheet(tester);
      expect(find.byTooltip('1 étoile'), findsOneWidget);
      for (final n in [2, 3, 4, 5]) {
        expect(find.byTooltip('$n étoiles'), findsOneWidget);
      }
      expect(find.byTooltip('1 star'), findsNothing);
    });

    testWidgets('success and failure snackbars are French', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('rating_star_4')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rating_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Merci pour ton retour\u00a0!'), findsOneWidget);
      expect(find.text('Thanks for the feedback!'), findsNothing);
    });

    testWidgets('a failed submit shows the French error', (tester) async {
      await openSheet(tester, fail: true);
      await tester.tap(find.byKey(const Key('rating_star_2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rating_submit_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible d’envoyer ta note. Réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('no overflow: long name at 320 px and 2.0x', (tester) async {
      narrow(tester);
      await openSheet(tester, name: _longName, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('post-meal card', () {
    testWidgets('prompt and button are French', (tester) async {
      await pumpApp(
        tester,
        const PostMealCard(matchId: 'm1', targetUid: 'them'),
        name: "Jean d'Arc",
      );
      await tester.pumpAndSettle();
      expect(find.text('Comment s’est passé ton repas\u00a0?'), findsOneWidget);
      expect(find.text("Avec Jean d'Arc"), findsOneWidget);
      expect(find.text('Noter'), findsOneWidget);
      expect(find.text('How was your meal?'), findsNothing);
    });

    testWidgets('unnamed button reads Noter', (tester) async {
      await pumpApp(
        tester,
        const PostMealCard(matchId: 'm1', targetUid: 'them'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Noter'), findsOneWidget);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow: long name at 320 px and ${scale}x', (
        tester,
      ) async {
        narrow(tester);
        await pumpApp(
          tester,
          const PostMealCard(matchId: 'm1', targetUid: 'them'),
          name: _longName,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('rating badge', () {
    testWidgets('New is Nouveau', (tester) async {
      await pumpApp(
        tester,
        const RatingBadge(uid: 'them'),
        user: AppUser(uid: 'them', dob: DateTime(1990)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Nouveau'), findsOneWidget);
      expect(find.text('New'), findsNothing);
    });

    testWidgets('score uses the French decimal comma', (tester) async {
      await pumpApp(
        tester,
        const RatingBadge(uid: 'them'),
        user: AppUser(
          uid: 'them',
          dob: DateTime(1990),
          ratingAvg: 4.5,
          ratingCount: 8,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('4,5 (8)'), findsOneWidget);
    });
  });

  test('ICU: star counts 0, 1 and many', () {
    final fr = AppLocalizationsFr();
    expect(fr.ratingStarTooltip(0), '0 étoile');
    expect(fr.ratingStarTooltip(1), '1 étoile');
    expect(fr.ratingStarTooltip(5), '5 étoiles');
    expect(fr.ratingBadgeScore(4, 12), '4,0 (12)');
  });
}
