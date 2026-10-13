import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/onboarding/presentation/age_gate_screen.dart';
import 'package:not_eat_alone/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_fr.dart';

import '../../../support/pump_localized.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockAuthRepository auth;
  late _MockUserRepository users;

  setUp(() {
    auth = _MockAuthRepository();
    users = _MockUserRepository();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'u1'));
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpAge(
    WidgetTester tester,
    GlobalKey<AgeGateScreenState> key, {
    bool narrow = false,
  }) async {
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await pumpLocalized(
      tester,
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
        child: AgeGateScreen(key: key),
      ),
      size: narrow ? const Size(320, 568) : null,
      textScale: narrow ? 2 : null,
    );
    await tester.pump();
  }

  group('age gate', () {
    testWidgets('strings are French, chosen date is a French long date', (
      tester,
    ) async {
      final key = GlobalKey<AgeGateScreenState>();
      await pumpAge(tester, key);

      expect(find.text('Confirme ta date de naissance'), findsOneWidget);
      expect(
        find.text('Tu dois avoir 18 ans ou plus pour utiliser Convyve.'),
        findsOneWidget,
      );
      expect(find.text('Choisis ta date de naissance'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.text('Confirm your date of birth'), findsNothing);
      expect(find.text('Continue'), findsNothing);

      key.currentState!.debugSetSelectedDate(DateTime(1990, 3, 5));
      await tester.pump();
      expect(find.text('5 mars 1990'), findsOneWidget);
    });

    testWidgets('date picker help and field label are French', (tester) async {
      final key = GlobalKey<AgeGateScreenState>();
      await pumpAge(tester, key);

      await tester.tap(find.text('Choisis ta date de naissance'));
      await tester.pumpAndSettle();

      expect(find.text('Ta date de naissance'), findsOneWidget);
      expect(find.text('Your date of birth'), findsNothing);
    });

    testWidgets('blocked screen and error state are French', (tester) async {
      final key = GlobalKey<AgeGateScreenState>();
      await pumpAge(tester, key);
      final now = DateTime.now();
      key.currentState!.debugSetSelectedDate(
        DateTime(now.year - 10, now.month, now.day),
      );
      await tester.pump();

      await tester.tap(find.text('Continuer'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Tu dois avoir 18 ans ou plus pour utiliser Convyve.'),
        findsOneWidget,
      );
      expect(find.text('Continuer'), findsNothing);
    });

    testWidgets('no overflow at 320 px and 2.0x', (tester) async {
      final key = GlobalKey<AgeGateScreenState>();
      await pumpAge(tester, key, narrow: true);
      key.currentState!.debugSetSelectedDate(DateTime(1990, 9, 30));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('profile setup', () {
    Future<void> pumpSetup(WidgetTester tester, {bool narrow = false}) async {
      if (narrow) {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }
      await pumpLocalized(
        tester,
        ProviderScope(
          overrides: [
            currentUserDocProvider.overrideWith(
              (ref) =>
                  Stream.value(AppUser(uid: 'u1', dob: DateTime.utc(2000))),
            ),
          ],
          child: const ProfileSetupScreen(),
        ),
        size: narrow ? const Size(320, 568) : null,
        textScale: narrow ? 2 : null,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('title, subtitle, Continue and the still-needed hint', (
      tester,
    ) async {
      await pumpSetup(tester);

      expect(find.text('Configure ton profil'), findsOneWidget);
      expect(find.text('Nom, photo et genre. C’est tout.'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      expect(find.textContaining('Il manque encore'), findsOneWidget);
      expect(find.text('Set up your profile'), findsNothing);
      expect(find.textContaining('Still needed'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('no overflow at 320 px and 2.0x', (tester) async {
      await pumpSetup(tester, narrow: true);
      expect(tester.takeException(), isNull);
    });
  });

  test('profileStillNeeded keeps apostrophes and the French colon space', () {
    final fr = AppLocalizationsFr();
    expect(
      fr.profileStillNeeded("l'adresse d'e-mail"),
      "Il manque encore : l'adresse d'e-mail.",
    );
  });
}
