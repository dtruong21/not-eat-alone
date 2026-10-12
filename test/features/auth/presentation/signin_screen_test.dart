import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_args.dart';
import 'package:not_eat_alone/features/auth/presentation/signin_screen.dart';
import 'package:not_eat_alone/features/onboarding/application/underage_notice_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// `analytics.track()` drops to `debugPrint` in debug builds (see
/// `lib/core/analytics/client.dart`) — intercept it here rather than mocking
/// analytics directly, since `track()` isn't provider-wired. [debugPrint] is
/// restored inside a `finally`, synchronously within the test body, rather
/// than via `tearDown()` — the flutter_test binding verifies foundation
/// debug variables are back to their defaults immediately after the test
/// body returns, which runs before a package:test `tearDown()` would fire.
Future<List<String>> _captureDebugLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) logs.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
  });

  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 800,
    double height = 900,
    double textScale = 1,
    Object? Function(Object?)? onPhonePush,
  }) async {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SigninScreen()),
        GoRoute(
          path: phoneVerifyRoutePath,
          builder: (_, state) {
            onPhonePush?.call(state.extra);
            return const Scaffold(body: Text('code screen'));
          },
        ),
      ],
    );
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterValidPhone(WidgetTester tester) => tester.enterText(
    find.byKey(const Key('signin_phone_field')),
    '+33612345678',
  );

  void stubVerifyPhone(
    Future<void> Function(
      void Function(String) codeSent,
      void Function(String) onError,
    )
    body,
  ) {
    when(
      () => authRepository.verifyPhone(
        phoneE164: any(named: 'phoneE164'),
        codeSent: any(named: 'codeSent'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((i) {
      return body(
        i.namedArguments[#codeSent] as void Function(String),
        i.namedArguments[#onError] as void Function(String),
      );
    });
  }

  testWidgets(
    'tapping Google calls signInWithGoogle and fires signin_started(google)',
    (tester) async {
      when(
        () => authRepository.signInWithGoogle(),
      ).thenAnswer((_) async {});

      await pumpScreen(tester);

      final logs = await _captureDebugLogs(() async {
        await tester.tap(find.text('Continue with Google'));
        await tester.pump();
        await tester.pump();
      });

      verify(() => authRepository.signInWithGoogle()).called(1);
      expect(
        logs.any((l) => l.contains('signin_started') && l.contains('google')),
        isTrue,
      );
    },
  );

  testWidgets(
    'an error from signInWithGoogle renders an error message, not a crash',
    (tester) async {
      when(
        () => authRepository.signInWithGoogle(),
      ).thenAnswer((_) async => throw Exception('network down'));

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Something went wrong — please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'entering a phone number and tapping Send code calls verifyPhone with '
    'the E.164 number',
    (tester) async {
      when(
        () => authRepository.verifyPhone(
          phoneE164: any(named: 'phoneE164'),
          codeSent: any(named: 'codeSent'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((_) async {});

      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const Key('signin_phone_field')),
        '+33612345678',
      );

      final logs = await _captureDebugLogs(() async {
        await tester.tap(find.text('Send code'));
        await tester.pump();
        await tester.pump();
      });

      verify(
        () => authRepository.verifyPhone(
          phoneE164: '+33612345678',
          codeSent: any(named: 'codeSent'),
          onError: any(named: 'onError'),
        ),
      ).called(1);
      expect(
        logs.any((l) => l.contains('signin_started') && l.contains('phone')),
        isTrue,
      );
    },
  );

  group('layout', () {
    testWidgets('at 320 px and 2.0x text nothing overflows and every label is '
        'fully visible', (tester) async {
      await pumpScreen(tester, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
      for (final label in ['Continue with Google', 'Send code']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: label);
        final box = tester.getRect(finder);
        final outer = tester.getRect(
          find
              .ancestor(
                of: finder,
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first,
        );
        expect(outer.contains(box.topLeft), isTrue, reason: label);
        expect(outer.contains(box.bottomRight), isTrue, reason: label);
        expect(outer.width, lessThanOrEqualTo(320), reason: label);
      }
      // Apple's label ignores the text scale (its type is already 24 px).
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.text('Continue with Apple')),
        ).scale(10),
        10,
      );
    });

    testWidgets('Google, Apple and Send code are all 56 high', (tester) async {
      await pumpScreen(tester);
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        WarmPlayfulSize.actionHeight,
      );
      expect(
        tester.getSize(find.byType(SignInWithAppleButton)).height,
        WarmPlayfulSize.actionHeight,
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        WarmPlayfulSize.actionHeight,
      );
    });

    testWidgets('subtitle names the product promise', (tester) async {
      await pumpScreen(tester);
      expect(
        find.text('Meet one person over a meal in Paris.'),
        findsOneWidget,
      );
      expect(find.text('Sign in to get started.'), findsNothing);
    });
  });

  group('official Apple button', () {
    testWidgets('black in light mode, white in dark; radius md; label', (
      tester,
    ) async {
      await pumpScreen(tester);
      var b = tester.widget<SignInWithAppleButton>(
        find.byType(SignInWithAppleButton),
      );
      expect(b.style, SignInWithAppleButtonStyle.black);
      expect(b.height, WarmPlayfulSize.actionHeight);
      expect(b.borderRadius, BorderRadius.circular(WarmPlayfulRadius.md));
      expect(b.text, 'Continue with Apple');

      await pumpScreen(tester, brightness: Brightness.dark);
      b = tester.widget<SignInWithAppleButton>(
        find.byType(SignInWithAppleButton),
      );
      expect(b.style, SignInWithAppleButtonStyle.white);
    });

    testWidgets('tapping it signs in with Apple, firing signin_started(apple) '
        'once', (tester) async {
      when(() => authRepository.signInWithApple()).thenAnswer((_) async {});
      await pumpScreen(tester);
      final logs = await _captureDebugLogs(() async {
        await tester.tap(find.text('Continue with Apple'));
        await tester.pump();
        await tester.pump();
      });
      verify(() => authRepository.signInWithApple()).called(1);
      expect(
        logs.where((l) => l.contains('signin_started') && l.contains('apple')),
        hasLength(1),
      );
    });

    testWidgets('is disabled for screen readers while another method is in '
        'flight', (tester) async {
      final handle = tester.ensureSemantics();
      stubVerifyPhone((_, _) async {});
      await pumpScreen(tester);
      final apple = find.byType(SignInWithAppleButton);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.getSemantics(apple),
        matchesSemantics(
          label: 'Continue with Apple',
          isButton: true,
          // hasEnabledState without isEnabled: it is read as disabled.
          hasEnabledState: true,
          isFocusable: true,
        ),
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('looks disabled and ignores taps while another method is in '
        'flight', (tester) async {
      stubVerifyPhone((_, _) async {});
      await pumpScreen(tester);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byType(SignInWithAppleButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
      await tester.tap(find.text('Continue with Apple'), warnIfMissed: false);
      verifyNever(() => authRepository.signInWithApple());
      // Leave no 60 s timer behind.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('while Apple itself is in flight it is announced as signing '
        'in', (tester) async {
      final handle = tester.ensureSemantics();
      final done = Completer<void>();
      when(
        () => authRepository.signInWithApple(),
      ).thenAnswer((_) => done.future);
      await pumpScreen(tester);
      await tester.tap(find.text('Continue with Apple'));
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Signing in…'), findsOneWidget);
      done.complete();
      await tester.pump();
      handle.dispose();
    });
  });

  group('phone', () {
    testWidgets('Send code stays loading until codeSent, then pushes the '
        'verification id', (tester) async {
      late void Function(String) fire;
      Object? extra;
      stubVerifyPhone((codeSent, _) async => fire = codeSent);
      await pumpScreen(tester, onPhonePush: (e) => extra = e);
      await tester.enterText(
        find.byKey(const Key('signin_phone_field')),
        '+33612345678',
      );
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Sending code…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fire('verif-1');
      await tester.pumpAndSettle();
      expect(find.text('code screen'), findsOneWidget);
      expect(extra, isA<PhoneVerifyArgs>());
      final args = extra! as PhoneVerifyArgs;
      expect(args.verificationId, 'verif-1');
      expect(args.phoneE164, '+33612345678');
    });

    testWidgets('onError clears the loading state and shows the generic '
        'error', (tester) async {
      late void Function(String) fail;
      stubVerifyPhone((_, onError) async => fail = onError);
      await pumpScreen(tester);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sending code…'), findsOneWidget);

      fail('boom');
      await tester.pump();
      expect(find.text('Send code'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('Something went wrong — please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a 60 s safety timeout clears the loading state', (
      tester,
    ) async {
      stubVerifyPhone((_, _) async {});
      await pumpScreen(tester);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Sending code…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Send code'), findsOneWidget);
      expect(
        find.text('Something went wrong — please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('spaces are stripped and a trunk 0 after +33 dropped before '
        'verifyPhone', (tester) async {
      stubVerifyPhone((_, _) async {});
      await pumpScreen(tester);
      for (final typed in ['+33 6 12 34 56 78', '+33 06 12 34 56 78']) {
        await tester.enterText(
          find.byKey(const Key('signin_phone_field')),
          typed,
        );
        await tester.tap(find.text('Send code'));
        await tester.pump();
        verify(
          () => authRepository.verifyPhone(
            phoneE164: '+33612345678',
            codeSent: any(named: 'codeSent'),
            onError: any(named: 'onError'),
          ),
        ).called(1);
        await tester.pump(const Duration(seconds: 61)); // timeout, retry-able
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the error line is a live region, also after the timeout', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      stubVerifyPhone((_, _) async {});
      await pumpScreen(tester);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 61));
      expect(
        tester.getSemantics(
          find.text('Something went wrong — please try again.'),
        ),
        matchesSemantics(
          label: 'Something went wrong — please try again.',
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });

    testWidgets("a superseded attempt's late codeSent does not push; the "
        'current one does and clears the error', (tester) async {
      final fires = <void Function(String)>[];
      var pushes = 0;
      stubVerifyPhone((codeSent, _) async => fires.add(codeSent));
      await pumpScreen(tester, onPhonePush: (_) => pushes++);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 61)); // attempt 1 times out
      expect(
        find.text('Something went wrong — please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Send code')); // attempt 2
      await tester.pump();
      expect(fires, hasLength(2));

      fires[0]('stale');
      await tester.pump();
      expect(pushes, 0);
      expect(find.text('Sending code…'), findsOneWidget);

      fires[1]('fresh');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(pushes, 1);
      expect(find.text('code screen'), findsOneWidget);
    });

    testWidgets('a codeSent arriving after the 60 s timeout does not open the '
        'code screen, even once Google has started', (tester) async {
      void Function(String)? lateCodeSent;
      var pushes = 0;
      stubVerifyPhone((codeSent, _) async => lateCodeSent = codeSent);
      when(() => authRepository.signInWithGoogle()).thenAnswer(
        (_) => Completer<void>().future,
      );
      await pumpScreen(tester, onPhonePush: (_) => pushes++);
      await enterValidPhone(tester);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      lateCodeSent!('late');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(pushes, 0);
      expect(find.text('code screen'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an invalid number shows the message on the field and does '
        'not call the repository', (tester) async {
      await pumpScreen(tester);
      // Default '+33' only.
      await tester.tap(find.text('Send code'));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('signin_phone_field')),
      );
      expect(
        field.decoration?.errorText,
        'Enter a phone number with country code, e.g. +33 6 12 34 56 78',
      );
      expect(
        find.text('Something went wrong — please try again.'),
        findsNothing,
      );
      verifyNever(
        () => authRepository.verifyPhone(
          phoneE164: any(named: 'phoneE164'),
          codeSent: any(named: 'codeSent'),
          onError: any(named: 'onError'),
        ),
      );
      // Editing clears it.
      await tester.enterText(
        find.byKey(const Key('signin_phone_field')),
        '+3361',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('signin_phone_field')))
            .decoration
            ?.errorText,
        isNull,
      );
    });

    testWidgets('the invalid-number error is scrolled into view when the '
        'keyboard opens', (tester) async {
      await pumpScreen(tester, width: 360, height: 640);
      await tester.tap(find.text('Send code'));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final bottom = tester
          .getBottomLeft(
            find.text(
              'Enter a phone number with country code, e.g. +33 6 12 34 56 78',
            ),
          )
          .dy;
      expect(bottom, lessThanOrEqualTo(640 - 300));
    });

    testWidgets('with a 300 px keyboard at 320 x 568 and 2.0x text, the error '
        'and Send code are scrolled above it', (tester) async {
      await pumpScreen(tester, width: 320, height: 568, textScale: 2);
      const keyboard = 300.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final send = find.widgetWithText(FilledButton, 'Send code');
      // Precondition: without a focus-scroll the button is under the keyboard.
      expect(
        tester.getBottomLeft(send).dy,
        greaterThan(568 - keyboard),
      );

      // Focusing the field (what the app does after an invalid number, and
      // what a tap does) scrolls it up by its scrollPadding.
      await tester.showKeyboard(find.byKey(const Key('signin_phone_field')));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(send).dy,
        lessThanOrEqualTo(568 - keyboard),
      );
    });

    testWidgets('only digits, + and spaces are accepted; autofill hint set', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.enterText(
        find.byKey(const Key('signin_phone_field')),
        '+33 (6)-12.ab',
      );
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('signin_phone_field')),
      );
      expect(field.controller?.text, '+33 612');
      expect(field.autofillHints, [AutofillHints.telephoneNumber]);
    });
  });

  group('under-18 banner', () {
    testWidgets('absent by default', (tester) async {
      await pumpScreen(tester);
      expect(
        find.text('You must be 18 or older to use Convyve.'),
        findsNothing,
      );
    });

    testWidgets('shown above the title as a live region and dismissible', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      container.read(underageNoticeProvider.notifier).set(value: true);
      await tester.pump();

      final banner = find.text('You must be 18 or older to use Convyve.');
      expect(banner, findsOneWidget);
      expect(
        tester.getTopLeft(banner).dy,
        lessThan(tester.getTopLeft(find.text('Welcome to Convyve')).dy),
      );
      expect(
        tester.getSemantics(banner),
        matchesSemantics(
          label: 'You must be 18 or older to use Convyve.',
          isLiveRegion: true,
        ),
      );
      final close = find.byTooltip('Dismiss');
      final size = tester.getSize(close);
      expect(size.width, greaterThanOrEqualTo(WarmPlayfulSize.minTap));
      expect(size.height, greaterThanOrEqualTo(WarmPlayfulSize.minTap));

      await tester.tap(close);
      await tester.pump();
      expect(banner, findsNothing);
      expect(container.read(underageNoticeProvider), isFalse);
      handle.dispose();
    });

    testWidgets('starting a sign-in clears it', (tester) async {
      when(() => authRepository.signInWithGoogle()).thenAnswer((_) async {});
      await pumpScreen(tester);
      container.read(underageNoticeProvider.notifier).set(value: true);
      await tester.pump();
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(container.read(underageNoticeProvider), isFalse);
    });
  });
}
