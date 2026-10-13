import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/presentation/profile_edit_screen.dart';
import 'package:not_eat_alone/features/user/presentation/widgets/profile_form.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_en.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_fr.dart';

import '../../../helpers/load_app_fonts.dart';

class _FakeProfileController extends ProfileController {
  @override
  Future<void> save({String? displayName, String? bio, Gender? gender}) async {
    state = const AsyncValue.data(null);
  }
}

AppUser _user({
  String? name = 'Alex',
  Gender? gender = Gender.woman,
  List<String> photos = const ['https://example.com/1.jpg'],
  int ratingCount = 7,
}) => AppUser(
  uid: 'u1',
  dob: DateTime.utc(1995, 6),
  displayName: name,
  bio: 'Aime les ramen.',
  gender: gender,
  photoUrls: photos,
  ratingCount: ratingCount,
  ratingAvg: 4.7,
);

/// French copy for the Profile tab and the shared profile form.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester, {
    AppUser? user,
    bool narrow = false,
    double textScale = 1,
  }) async {
    final u = user ?? _user();
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDocProvider.overrideWith((ref) => Stream.value(u)),
          userDocProvider('u1').overrideWith((ref) => Stream.value(u)),
          profileControllerProvider.overrideWith(_FakeProfileController.new),
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
          home: const ProfileEditScreen(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('title, rating, form labels and gender are French', (
    tester,
  ) async {
    await pump(tester);
    for (final fr in [
      'Profil',
      'Ta note',
      'Photos',
      'Nom',
      'Je suis',
      'Femme',
      'Homme',
      'Non-binaire',
      'Bio',
      'Enregistrer',
    ]) {
      expect(find.text(fr), findsOneWidget, reason: fr);
    }
    expect(find.text('4,7 (7)'), findsOneWidget);
    expect(find.byTooltip('Réglages'), findsOneWidget);
    expect(find.byTooltip('Supprimer la photo'), findsOneWidget);
    expect(find.text('Ajouter une photo'), findsOneWidget);
    for (final en in [
      'Profile',
      'Your rating',
      'Name',
      'I am a',
      'Woman',
      'Man',
      'Non-binary',
      'Save',
      'Add photo',
    ]) {
      expect(find.text(en), findsNothing, reason: en);
    }
  });

  testWidgets('no ratings yet is French', (tester) async {
    await pump(tester, user: _user(ratingCount: 0));
    expect(find.text('Aucune note pour le moment'), findsOneWidget);
    expect(find.text('No ratings yet'), findsNothing);
  });

  testWidgets('the add-photo tile is announced in French', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel('Ajouter une photo'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the hint lists every missing field in French', (tester) async {
    await pump(tester, user: _user(name: null, gender: null, photos: const []));
    expect(
      find.text('Il manque encore\u00a0: une photo, ton nom et ton genre.'),
      findsOneWidget,
    );
    expect(find.textContaining('Still needed'), findsNothing);
  });

  testWidgets('the hint with two missing fields joins with "et"', (
    tester,
  ) async {
    await pump(tester, user: _user(gender: null, photos: const []));
    expect(
      find.text('Il manque encore\u00a0: une photo et ton genre.'),
      findsOneWidget,
    );
  });

  testWidgets('the hint with one missing field', (tester) async {
    await pump(tester, user: _user(photos: const []));
    expect(find.text('Il manque encore\u00a0: une photo.'), findsOneWidget);
  });

  testWidgets('saving shows the French snackbar', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      "Jean d'Arc",
    );
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Profil enregistré'), findsOneWidget);
    expect(find.text('Profile saved'), findsNothing);
  });

  testWidgets('no overflow at 320 px and 2.0x, all hints showing', (
    tester,
  ) async {
    await pump(
      tester,
      user: _user(name: null, gender: null, photos: const []),
      narrow: true,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  group('localizeMissingFields', () {
    final fr = AppLocalizationsFr();
    final en = AppLocalizationsEn();
    const photo = ProfileMissingField.photo;
    const name = ProfileMissingField.name;
    const gender = ProfileMissingField.gender;

    test('0, 1, 2 and 3 fields in French', () {
      expect(localizeMissingFields(fr, []), '');
      expect(localizeMissingFields(fr, [name]), 'ton nom');
      expect(
        localizeMissingFields(fr, [photo, gender]),
        'une photo et ton genre',
      );
      expect(
        localizeMissingFields(fr, [photo, name, gender]),
        'une photo, ton nom et ton genre',
      );
    });

    test('English keeps its wording', () {
      expect(localizeMissingFields(en, [photo, name]), 'a photo and your name');
      expect(
        localizeMissingFields(en, [photo, name, gender]),
        'a photo, your name and how you identify',
      );
      expect(
        en.profileStillNeeded(localizeMissingFields(en, [photo])),
        'Still needed: a photo.',
      );
    });
  });
}
