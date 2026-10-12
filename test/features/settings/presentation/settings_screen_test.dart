import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockPushRepository extends Mock implements PushRepository {}

MockPushRepository _quietPushRepository() {
  final push = MockPushRepository();
  when(() => push.unregisterCurrentToken(any())).thenAnswer((_) async {});
  return push;
}

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

  Future<void> pumpSettings(
    WidgetTester tester, {
    PushRepository? pushRepository,
  }) async {
    // Tall enough that the lazy ListView builds every row, Delete account
    // (last) included.
    tester.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => 'v1.1.0 (build 2)'),
          authRepositoryProvider.overrideWithValue(authRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(authRepository.currentUser),
          ),
          accountRepositoryProvider.overrideWithValue(accountRepository),
          // Always overridden: the real repository needs a Firebase app.
          pushRepositoryProvider.overrideWithValue(
            pushRepository ?? _quietPushRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders legal links, account actions, and the app version', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('v1.1.0 (build 2)'), findsOneWidget);
  });

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

      await tester.tap(find.byKey(const Key('settings_delete_account_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsNothing);
    },
  );

  testWidgets('sign out asks first: cancel does nothing', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    verifyNever(() => authRepository.signOut());

    await tester.tap(find.byKey(const Key('settings_sign_out_cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsNothing);
    verifyNever(() => authRepository.signOut());
  });

  testWidgets('confirming sign-out unregisters the push token of the signed-in '
      'user exactly once, then signs out', (tester) async {
    final pushRepository = MockPushRepository();
    when(
      () => pushRepository.unregisterCurrentToken(any()),
    ).thenAnswer((_) async {});
    when(
      () => authRepository.currentUser,
    ).thenReturn(const AuthUser(uid: 'u1'));
    await pumpSettings(tester, pushRepository: pushRepository);

    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_sign_out_confirm')));
    await tester.pump();
    await tester.pump();

    verify(() => pushRepository.unregisterCurrentToken('u1')).called(1);
    verify(() => authRepository.signOut()).called(1);
  });

  testWidgets('confirming the sign-out dialog signs out once, no spinner', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings_sign_out_confirm')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    verify(() => authRepository.signOut()).called(1);
  });

  testWidgets(
    'screen unmounting while the confirm dialog is open: confirming still '
    'signs out (repository read before the dialog), no exception',
    (tester) async {
      final pushRepository = MockPushRepository();
      when(
        () => pushRepository.unregisterCurrentToken(any()),
      ).thenAnswer((_) async {});
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(uid: 'u1'));
      final showSettings = ValueNotifier(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWith((ref) async => 'v1'),
            authRepositoryProvider.overrideWithValue(authRepository),
            authStateProvider.overrideWith(
              (ref) => Stream.value(authRepository.currentUser),
            ),
            accountRepositoryProvider.overrideWithValue(accountRepository),
            pushRepositoryProvider.overrideWithValue(pushRepository),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: ValueListenableBuilder<bool>(
              valueListenable: showSettings,
              builder: (context, show, _) =>
                  show ? const SettingsScreen() : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_sign_out')));
      await tester.pumpAndSettle();

      // The dialog route outlives the screen (e.g. a session redirect).
      showSettings.value = false;
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings_sign_out_confirm')));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      verify(() => pushRepository.unregisterCurrentToken('u1')).called(1);
      verify(() => authRepository.signOut()).called(1);
    },
  );

  testWidgets(
    'sign out survives the screen unmounting while the token unregister is '
    'in flight (no ref read after the await) and still signs out',
    (tester) async {
      final gate = Completer<void>();
      final pushRepository = MockPushRepository();
      when(
        () => pushRepository.unregisterCurrentToken(any()),
      ).thenAnswer((_) => gate.future);
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(uid: 'u1'));

      await pumpSettings(tester, pushRepository: pushRepository);

      await tester.tap(find.byKey(const Key('settings_sign_out')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_sign_out_confirm')));
      await tester.pump();

      // Unmount the whole tree (disposing the screen's ref) mid-flight.
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      verify(() => authRepository.signOut()).called(1);
    },
  );
  group('Contact support', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('shows the support address as published contact info', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text(supportEmail), findsOneWidget);
    });

    testWidgets('tap opens a mailto link addressed to support', (tester) async {
      final launched = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            launched.add(
              (call.arguments as Map<Object?, Object?>)['url']! as String,
            );
            return true;
          });
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings_contact_support')));
      await tester.pump();

      expect(launched.single, startsWith('mailto:$supportEmail'));
      expect(find.textContaining("Couldn't open your mail app"), findsNothing);
    });

    testWidgets('no mail app: snackbar tells the user the address', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => false);
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings_contact_support')));
      await tester.pump();

      expect(
        find.text("Couldn't open your mail app. Write to $supportEmail"),
        findsOneWidget,
      );
    });
  });

  group('structure', () {
    setUp(() {
      FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    });

    Future<GoRouter> pumpRouted(
      WidgetTester tester, {
      Future<bool> Function()? openAppSettings,
      TextScaler scaler = TextScaler.noScaling,
    }) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SettingsScreen(),
          ),
          for (final path in [
            '/profile',
            '/settings/blocked',
            '/settings/safety',
          ])
            GoRoute(
              path: path,
              builder: (context, state) => Scaffold(body: Text('page $path')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appVersionProvider.overrideWith((ref) async => 'v1.1.0 (build 2)'),
            authRepositoryProvider.overrideWithValue(authRepository),
            authStateProvider.overrideWith(
              (ref) => Stream.value(authRepository.currentUser),
            ),
            accountRepositoryProvider.overrideWithValue(accountRepository),
            pushRepositoryProvider.overrideWithValue(_quietPushRepository()),
            if (openAppSettings != null)
              openAppSettingsProvider.overrideWithValue(openAppSettings),
          ],
          child: MaterialApp.router(
            theme: buildTheme(Brightness.light),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    void tall(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(800, 3000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

    testWidgets('groups appear in order with Delete account last', (
      tester,
    ) async {
      tall(tester);
      await pumpRouted(tester);

      final ys = [
        for (final t in ['Account', 'Safety', 'Legal', 'About'])
          top(tester, find.text(t)),
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Notifications'), findsNothing); // not iOS here
      final delete = top(
        tester,
        find.byKey(const Key('settings_delete_account')),
      );
      for (final key in [
        'settings_edit_profile',
        'settings_sign_out',
        'settings_blocked_people',
        'settings_safety_tips',
        'settings_contact_support',
        'settings_privacy_policy',
        'settings_terms_of_service',
        'settings_licenses',
        'settings_app_version',
      ]) {
        expect(
          top(tester, find.byKey(Key(key))),
          lessThan(delete),
          reason: key,
        );
      }
      expect(
        top(tester, find.byKey(const Key('settings_app_version'))),
        lessThan(delete),
      );
    });

    testWidgets('Delete account is in the danger text colour', (tester) async {
      tall(tester);
      await pumpRouted(tester);

      final danger = buildTheme(
        Brightness.light,
      ).extension<WarmPlayfulExtensions>()!.dangerText;
      final text = tester.widget<Text>(find.text('Delete account'));
      expect(text.style?.color, danger);
    });

    testWidgets('Delete account shows its spinner while in flight and cannot '
        'be tapped again', (tester) async {
      tall(tester);
      final gate = Completer<void>();
      when(
        () => accountRepository.deleteAccount(),
      ).thenAnswer((_) => gate.future);
      await pumpRouted(tester);

      await tester.tap(find.byKey(const Key('settings_delete_account')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('settings_delete_account_confirm')),
      );
      await tester.pump();

      final row = find.byKey(const Key('settings_delete_account'));
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(row).onTap, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      verify(() => accountRepository.deleteAccount()).called(1);
    });

    testWidgets('Edit profile goes to the profile tab', (tester) async {
      tall(tester);
      final router = await pumpRouted(tester);

      await tester.tap(find.byKey(const Key('settings_edit_profile')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/profile');
    });

    testWidgets('Blocked people and Safety tips open their routes', (
      tester,
    ) async {
      tall(tester);
      final router = await pumpRouted(tester);

      await tester.tap(find.byKey(const Key('settings_blocked_people')));
      await tester.pumpAndSettle();
      expect(find.text('page /settings/blocked'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings_safety_tips')));
      await tester.pumpAndSettle();
      expect(find.text('page /settings/safety'), findsOneWidget);
    });

    testWidgets('navigating rows have a chevron', (tester) async {
      tall(tester);
      await pumpRouted(tester);

      for (final key in [
        'settings_edit_profile',
        'settings_blocked_people',
        'settings_safety_tips',
        'settings_licenses',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byIcon(Icons.chevron_right_rounded),
          ),
          findsOneWidget,
          reason: key,
        );
      }
    });

    testWidgets('phone number is shown formatted when signed in with phone', (
      tester,
    ) async {
      tall(tester);
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(uid: 'u1', phoneNumber: '+33612345678'));
      await pumpRouted(tester);

      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('+33 6 12 34 56 78'), findsOneWidget);
    });

    testWidgets('phone number row is hidden without a number', (tester) async {
      tall(tester);
      when(
        () => authRepository.currentUser,
      ).thenReturn(const AuthUser(uid: 'u1'));
      await pumpRouted(tester);

      expect(find.text('Phone number'), findsNothing);
    });

    testWidgets('notification row is iOS only and opens the app settings', (
      tester,
    ) async {
      tall(tester);
      var opened = 0;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpRouted(
          tester,
          openAppSettings: () async {
            opened++;
            return true;
          },
        );

        expect(find.text('Notification settings'), findsOneWidget);
        expect(
          find.text('Manage notifications in iOS Settings'),
          findsOneWidget,
        );
        expect(
          top(tester, find.text('Notifications')),
          greaterThan(top(tester, find.text('Safety'))),
        );
        expect(
          top(tester, find.text('Notifications')),
          lessThan(top(tester, find.text('Legal'))),
        );
        await tester.tap(find.byKey(const Key('settings_notifications')));
        await tester.pump();
        expect(opened, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('no notification row on Android', (tester) async {
      tall(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpRouted(tester);
        expect(find.text('Notification settings'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Open-source licences opens the licence page with the app '
        'name and version', (tester) async {
      tall(tester);
      await pumpRouted(tester);

      await tester.tap(find.byKey(const Key('settings_licenses')));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('Convyve'), findsWidgets);
      expect(find.text('v1.1.0 (build 2)'), findsOneWidget);
    });

    testWidgets('every row is at least 48 high and nothing overflows at '
        '320 px / 2.0x', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        when(
          () => authRepository.currentUser,
        ).thenReturn(const AuthUser(uid: 'u1', phoneNumber: '+33612345678'));
        await pumpRouted(tester, scaler: const TextScaler.linear(2));
        for (final tile in find.byType(ListTile).evaluate()) {
          expect(
            tester.getSize(find.byWidget(tile.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('settings_delete_account')),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
