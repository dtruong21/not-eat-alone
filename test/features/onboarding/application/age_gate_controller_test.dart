import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers_v2.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/onboarding/application/age_gate_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

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
}
