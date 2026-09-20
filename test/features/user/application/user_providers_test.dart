import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

void main() {
  group('currentUserDocProvider', () {
    late MockAuthRepository authRepository;
    late MockUserRepository userRepository;
    late ProviderContainer container;

    setUp(() {
      authRepository = MockAuthRepository();
      userRepository = MockUserRepository();
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer buildContainer() {
      return ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          userRepositoryProvider.overrideWithValue(userRepository),
        ],
      );
    }

    /// Listens to [currentUserDocProvider] and resolves with the first
    /// `AsyncData` value matching [matches]. A plain `container.read(
    /// currentUserDocProvider.future)` isn't used here because the provider
    /// rebuilds once the underlying `authStateProvider` settles from
    /// loading to its resolved value, and without an active listener
    /// keeping the element alive across that rebuild, `.future` can hang
    /// indefinitely instead of resolving with the final value.
    Future<AppUser?> waitFor(
      ProviderContainer container,
      bool Function(AppUser? value) matches,
    ) {
      final completer = Completer<AppUser?>();
      final sub = container.listen(currentUserDocProvider, (previous, next) {
        final value = next.value;
        if (next.hasValue && matches(value) && !completer.isCompleted) {
          completer.complete(value);
        }
      }, fireImmediately: true);
      return completer.future.whenComplete(sub.close);
    }

    test('emits null when signed out', () async {
      when(() => authRepository.authStateChanges())
          .thenAnswer((_) => Stream.value(null));

      container = buildContainer();

      final result = await waitFor(container, (value) => value == null);

      expect(result, isNull);
      verifyNever(() => userRepository.watch(any()));
    });

    test('emits the AppUser when signed in', () async {
      when(() => authRepository.authStateChanges())
          .thenAnswer((_) => Stream.value(const AuthUser(uid: 'u1')));

      final appUser = AppUser(
        uid: 'u1',
        dob: DateTime.utc(2000, 1, 1),
        ageVerified: true,
      );
      when(() => userRepository.watch('u1'))
          .thenAnswer((_) => Stream.value(appUser));

      container = buildContainer();

      final result = await waitFor(container, (value) => value == appUser);

      expect(result, appUser);
      verify(() => userRepository.watch('u1')).called(1);
    });
  });
}
