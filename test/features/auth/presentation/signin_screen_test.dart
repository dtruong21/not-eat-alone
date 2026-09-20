import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/auth/presentation/signin_screen.dart';

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

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SigninScreen(),
        ),
      ),
    );
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
}
