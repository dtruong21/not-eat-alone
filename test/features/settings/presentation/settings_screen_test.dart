import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/account_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/account_repository.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockAccountRepository accountRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    accountRepository = MockAccountRepository();

    // Signed out by default so `_signOut`'s optional push-token-unregister
    // branch is skipped — most assertions here don't tap sign out anyway.
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    when(() => accountRepository.deleteAccount()).thenAnswer((_) async {});
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith(
            (ref) async => 'v1.1.0 (build 2)',
          ),
          authRepositoryProvider.overrideWithValue(authRepository),
          accountRepositoryProvider.overrideWithValue(accountRepository),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders legal links, account actions, and the app version',
    (tester) async {
      await pumpSettings(tester);

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('v1.1.0 (build 2)'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Delete account opens the confirm dialog without deleting',
    (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings_delete_account')));
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsOneWidget);
      expect(
        find.text(
          "This permanently deletes your account and all your data. "
          "This can't be undone.",
        ),
        findsOneWidget,
      );
      verifyNever(() => accountRepository.deleteAccount());

      await tester.tap(
        find.byKey(const Key('settings_delete_account_cancel')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsNothing);
    },
  );
}
