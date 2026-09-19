import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/firebase/auth_repository.dart';
import 'package:not_eat_alone/core/firebase/users_repository.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/presentation/age_gate_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUsersRepository extends Mock implements UsersRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository authRepository;
  late MockUsersRepository usersRepository;
  late MockUser user;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2000, 1, 1));
  });

  setUp(() {
    authRepository = MockAuthRepository();
    usersRepository = MockUsersRepository();
    user = MockUser();
    when(() => user.uid).thenReturn('uid-1');
    when(() => authRepository.authStateChanges())
        .thenAnswer((_) => Stream.value(user));
    when(() => authRepository.signOut()).thenAnswer((_) async {});
  });

  /// DOB well under 18 years old, relative to "now" so the test never rots.
  DateTime under18Dob() {
    final now = DateTime.now();
    return DateTime.utc(now.year - 10, now.month, now.day);
  }

  /// DOB well over 18 years old, relative to "now".
  DateTime adultDob() {
    final now = DateTime.now();
    return DateTime.utc(now.year - 25, now.month, now.day);
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    GlobalKey<AgeGateScreenState> key,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          usersRepositoryProvider.overrideWithValue(usersRepository),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: AgeGateScreen(key: key),
        ),
      ),
    );
    // Let authStateProvider's underlying stream resolve to AsyncData(user).
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'under-18 DOB shows the block message and signs out, without upserting',
    (tester) async {
      final key = GlobalKey<AgeGateScreenState>();
      await pumpScreen(tester, key);

      key.currentState!.debugSetSelectedDate(under18Dob());
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.text('You must be 18 or older to use not-eat-alone.'),
        findsOneWidget,
      );
      verify(() => authRepository.signOut()).called(1);
      verifyNever(
        () => usersRepository.upsertAgeVerified(
          uid: any(named: 'uid'),
          dob: any(named: 'dob'),
        ),
      );
    },
  );

  testWidgets(
    'adult DOB shows loading then upserts age-verified with a UTC dob',
    (tester) async {
      final key = GlobalKey<AgeGateScreenState>();
      final completer = Completer<void>();
      when(
        () => usersRepository.upsertAgeVerified(
          uid: any(named: 'uid'),
          dob: any(named: 'dob'),
        ),
      ).thenAnswer((_) => completer.future);

      await pumpScreen(tester, key);

      final dob = adultDob();
      key.currentState!.debugSetSelectedDate(dob);
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      // Loading state renders while the write is in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      final captured = verify(
        () => usersRepository.upsertAgeVerified(
          uid: 'uid-1',
          dob: captureAny(named: 'dob'),
        ),
      ).captured.single as DateTime;

      expect(captured.isUtc, isTrue);
      expect(captured, DateTime.utc(dob.year, dob.month, dob.day));
      verifyNever(() => authRepository.signOut());
    },
  );
}
