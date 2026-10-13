import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_args.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_screen.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_fr.dart';

import '../../../support/pump_localized.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _args = PhoneVerifyArgs(
  verificationId: 'verif-1',
  phoneE164: '+33612345678',
);

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  Future<void> pump(WidgetTester tester, {bool narrow = false}) async {
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await pumpLocalized(
      tester,
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const PhoneVerifyScreen(args: _args),
      ),
      size: narrow ? const Size(320, 640) : null,
      textScale: narrow ? 2 : null,
    );
    await tester.pump();
  }

  testWidgets('every visible string is French', (tester) async {
    await pump(tester);

    for (final fr in [
      'Saisis le code',
      'Code envoyé au +33 6 12 34 56 78',
      'Modifier',
      'Valider',
      'Renvoyer le code dans 30\u00a0s',
    ]) {
      expect(find.text(fr), findsOneWidget, reason: fr);
    }
    expect(find.text('Code à 6 chiffres'), findsOneWidget);
    for (final en in ['Enter the code', 'Verify', 'Change', '6-digit code']) {
      expect(find.text(en), findsNothing, reason: en);
    }
    expect(find.textContaining('Resend code'), findsNothing);
    // Removing the pending cooldown timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a rejected code shows the French message', (tester) async {
    when(
      () => repo.confirmSmsCode(
        verificationId: any(named: 'verificationId'),
        smsCode: any(named: 'smsCode'),
      ),
    ).thenThrow(const InvalidSmsCodeException());
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('phone_verify_code_field')),
      '123456',
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Ce code n’a pas fonctionné. Vérifie-le ou renvoie-le.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a non-code failure shows the French generic error', (
    tester,
  ) async {
    when(
      () => repo.confirmSmsCode(
        verificationId: any(named: 'verificationId'),
        smsCode: any(named: 'smsCode'),
      ),
    ).thenThrow(Exception('network'));
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('phone_verify_code_field')),
      '123456',
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Oups, un problème est survenu. Réessaie.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no overflow at 320 px and 2.0x', (tester) async {
    await pump(tester, narrow: true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('placeholders render real values (seconds 0/1/many, phone)', () {
    final fr = AppLocalizationsFr();
    expect(fr.phoneResendIn(0), 'Renvoyer le code dans 0\u00a0s');
    expect(fr.phoneResendIn(1), 'Renvoyer le code dans 1\u00a0s');
    expect(fr.phoneResendIn(29), 'Renvoyer le code dans 29\u00a0s');
    expect(
      fr.phoneSentTo('+33 6 12 34 56 78'),
      'Code envoyé au +33 6 12 34 56 78',
    );
  });
}
