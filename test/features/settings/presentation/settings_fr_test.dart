import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/config/legal_urls.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/safety/application/account_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/account_repository.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockAccount extends Mock implements AccountRepository {}

class _MockPush extends Mock implements PushRepository {}

/// French copy for Settings: rows, section headers, dialogs and snackbars,
/// plus a 320 px / 2.0x no-overflow pass.
void main() {
  setUpAll(loadAppFonts);

  late _MockAuth auth;
  late _MockAccount account;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    auth = _MockAuth();
    account = _MockAccount();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => account.deleteAccount()).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    bool narrow = false,
    double textScale = 1,
    String? phone,
  }) async {
    tester.view
      ..physicalSize = narrow ? const Size(320, 4000) : const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => 'v1.1.0 (build 2)'),
          authRepositoryProvider.overrideWithValue(auth),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              phone == null ? null : AuthUser(uid: 'me', phoneNumber: phone),
            ),
          ),
          accountRepositoryProvider.overrideWithValue(account),
          pushRepositoryProvider.overrideWithValue(_MockPush()),
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
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The Notifications section is iOS-only; the platform override must be
  /// cleared before the test body ends (Flutter's invariant check).
  Future<void> onIos(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('title, sections and rows are French', (tester) async {
    await onIos(() async {
      await pump(tester, phone: '+33612345678');
      for (final fr in [
        'Réglages',
        'Compte',
        'Modifier le profil',
        'Numéro de téléphone',
        'Se déconnecter',
        'Sécurité',
        'Personnes bloquées',
        'Conseils de sécurité',
        'Contacter l’assistance',
        'Notifications',
        'Réglages des notifications',
        'Gère les notifications dans les Réglages iOS',
        'Mentions légales',
        'Politique de confidentialité',
        'Conditions d’utilisation',
        'Licences open source',
        'À propos',
        'Version',
        'Supprimer le compte',
      ]) {
        expect(find.text(fr), findsOneWidget, reason: fr);
      }
      for (final en in [
        'Settings',
        'Account',
        'Edit profile',
        'Phone number',
        'Sign out',
        'Safety',
        'Blocked people',
        'Safety tips',
        'Contact support',
        'Notification settings',
        'Legal',
        'Privacy Policy',
        'Terms of Service',
        'Open-source licences',
        'About',
        'Delete account',
      ]) {
        expect(find.text(en), findsNothing, reason: en);
      }
      // The support address and the version are data, not copy.
      expect(find.text(supportEmail), findsOneWidget);
      expect(find.text('v1.1.0 (build 2)'), findsOneWidget);
    });
  });

  testWidgets('sign-out dialog is French', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();
    expect(find.text('Te déconnecter ?'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsNWidgets(2));
  });

  testWidgets('delete dialog and failure snackbar are French', (tester) async {
    when(() => account.deleteAccount()).thenThrow(StateError('boom'));
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_delete_account')));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ton compte ?'), findsOneWidget);
    expect(
      find.text(
        'Cela supprime définitivement ton compte et toutes tes données. '
        'Cette action est irréversible.',
      ),
      findsOneWidget,
    );
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_delete_account_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Impossible de supprimer le compte. Réessaie.'),
      findsOneWidget,
    );
  });

  testWidgets('no mail app: the snackbar is French and keeps the address', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_contact_support')));
    await tester.pump();
    expect(
      find.text('Impossible d’ouvrir ta messagerie. Écris à $supportEmail'),
      findsOneWidget,
    );
  });

  testWidgets('no overflow at 320 px and 2.0x, dialogs included', (
    tester,
  ) async {
    await onIos(() async {
      await pump(tester, narrow: true, textScale: 2, phone: '+33612345678');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('settings_delete_account')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
