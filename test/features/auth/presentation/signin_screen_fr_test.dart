import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/auth/presentation/signin_screen.dart';
import 'package:not_eat_alone/features/onboarding/application/underage_notice_provider.dart';

import '../../../support/pump_localized.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late ProviderContainer container;

  setUp(() => repo = _MockAuthRepository());

  Future<void> pump(
    WidgetTester tester, {
    bool narrow = false,
    bool underage = false,
  }) async {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    if (underage) {
      container.read(underageNoticeProvider.notifier).set(value: true);
    }
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await pumpLocalized(
      tester,
      UncontrolledProviderScope(
        container: container,
        child: const SigninScreen(),
      ),
      size: narrow ? const Size(320, 640) : null,
      textScale: narrow ? 2 : null,
    );
    await tester.pump();
  }

  testWidgets('every visible string is French', (tester) async {
    await pump(tester, underage: true);

    for (final fr in [
      'Bienvenue sur Convyve',
      'Rencontre quelqu’un autour d’un repas à Paris.',
      'Continuer avec Google',
      'ou',
      'Numéro de téléphone',
      'Envoyer le code',
      'Tu dois avoir 18 ans ou plus pour utiliser Convyve.',
    ]) {
      expect(find.text(fr), findsOneWidget, reason: fr);
    }
    expect(find.byTooltip('Fermer'), findsOneWidget);
    for (final en in [
      'Welcome to Convyve',
      'Continue with Google',
      'Phone number',
      'Send code',
      'You must be 18 or older to use Convyve.',
    ]) {
      expect(find.text(en), findsNothing, reason: en);
    }
    expect(find.text('Continuer avec Apple'), findsOneWidget);
  });

  testWidgets('invalid phone shows the French error', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Envoyer le code'));
    await tester.pump();

    expect(
      find.text(
        'Saisis un numéro avec l’indicatif du pays, par ex. '
        '+33 6 12 34 56 78',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed sign-in shows the French generic error', (
    tester,
  ) async {
    when(() => repo.signInWithGoogle()).thenThrow(Exception('boom'));
    await pump(tester);

    await tester.tap(find.text('Continuer avec Google'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Oups, un problème est survenu. Réessaie.'),
      findsOneWidget,
    );
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  testWidgets('sending the code shows the French loading label', (
    tester,
  ) async {
    when(
      () => repo.verifyPhone(
        phoneE164: any(named: 'phoneE164'),
        codeSent: any(named: 'codeSent'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) => Future<void>.delayed(const Duration(seconds: 1)));
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('signin_phone_field')),
      '+33612345678',
    );
    await tester.tap(find.text('Envoyer le code'));
    await tester.pump();

    expect(find.text('Envoi du code…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('no overflow at 320 px and 2.0x with the longest strings', (
    tester,
  ) async {
    await pump(tester, narrow: true, underage: true);
    await tester.ensureVisible(find.text('Envoyer le code'));
    await tester.tap(find.text('Envoyer le code'));
    await tester.pump();

    expect(find.textContaining('Saisis un numéro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
