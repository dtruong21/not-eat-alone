import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/onboarding/application/age_gate_controller.dart';
import 'package:not_eat_alone/features/onboarding/application/underage_notice_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

import '../../../helpers/in_flight_dispose.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2000, 1, 1));
  });

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'u1'));
    when(() => authRepository.signOut()).thenAnswer((_) async {});
    when(
      () => userRepository.upsertAgeVerified(
        uid: any(named: 'uid'),
        dob: any(named: 'dob'),
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        userRepositoryProvider.overrideWithValue(userRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'adult DOB upserts age-verified with a UTC dob and does not sign out',
    () async {
      await container
          .read(ageGateControllerProvider.notifier)
          .submit(DateTime.utc(2000, 1, 1));

      final captured = verify(
        () => userRepository.upsertAgeVerified(
          uid: 'u1',
          dob: captureAny(named: 'dob'),
        ),
      ).captured.single as DateTime;

      expect(captured.isUtc, isTrue);
      expect(captured, DateTime.utc(2000, 1, 1));
      verifyNever(() => authRepository.signOut());

      final state = container.read(ageGateControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value?.blocked, isFalse);
    },
  );

  test(
    'under-18 DOB signs out, does not upsert, and marks state blocked',
    () async {
      await container
          .read(ageGateControllerProvider.notifier)
          .submit(DateTime.utc(2015, 1, 1));

      verify(() => authRepository.signOut()).called(1);
      verifyNever(
        () => userRepository.upsertAgeVerified(
          uid: any(named: 'uid'),
          dob: any(named: 'dob'),
        ),
      );

      final state = container.read(ageGateControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value?.blocked, isTrue);
    },
  );

  test('under-18 DOB sets the sign-in notice BEFORE signing out', () async {
    final log = <String>[];
    container.listen<bool>(
      underageNoticeProvider,
      (_, next) => log.add('notice:$next'),
    );
    when(() => authRepository.signOut()).thenAnswer((_) async {
      log.add('signOut');
    });

    await container
        .read(ageGateControllerProvider.notifier)
        .submit(DateTime.utc(2015));

    expect(log, ['notice:true', 'signOut']);
    expect(container.read(underageNoticeProvider), isTrue);
  });

  test('adult DOB does not set the sign-in notice', () async {
    final seen = <bool>[];
    container.listen<bool>(underageNoticeProvider, (_, next) => seen.add(next));

    await container
        .read(ageGateControllerProvider.notifier)
        .submit(DateTime.utc(2000));

    expect(seen, isEmpty);
    expect(container.read(underageNoticeProvider), isFalse);
  });

  // Regression: the controller's only watcher unmounting mid-action used
  // to dispose it, so the trailing `state =` threw UnmountedRefException.
  test('AgeGateController.submit (adult) survives its listener '
      'unmounting mid-flight', () async {
    final gate = Completer<void>();
    when(
      () => userRepository.upsertAgeVerified(
        uid: any(named: 'uid'),
        dob: any(named: 'dob'),
      ),
    ).thenAnswer((_) => gate.future);
    final seen = await runWithListenerRemovedMidFlight(
      container,
      ageGateControllerProvider,
      action: () => container
          .read(ageGateControllerProvider.notifier)
          .submit(DateTime.utc(2000)),
      release: gate.complete,
    );

    expect(seen.first.isLoading, isTrue);
    expect(seen.last.value?.blocked, isFalse);
  });

  // Regression: the controller's only watcher unmounting mid-action used
  // to dispose it, so the trailing `state =` threw UnmountedRefException.
  test('AgeGateController.submit (under-18 sign-out) survives its listener '
      'unmounting mid-flight', () async {
    final gate = Completer<void>();
    when(() => authRepository.signOut())
        .thenAnswer((_) => gate.future);
    final seen = await runWithListenerRemovedMidFlight(
      container,
      ageGateControllerProvider,
      action: () => container
          .read(ageGateControllerProvider.notifier)
          .submit(DateTime.utc(2015)),
      release: gate.complete,
    );

    expect(seen.first.isLoading, isTrue);
    expect(seen.last.value?.blocked, isTrue);
  });
}
