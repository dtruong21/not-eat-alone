import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/firebase/auth_repository.dart';
import 'package:not_eat_alone/core/firebase/users_repository.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/app_user.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUsersRepository extends Mock implements UsersRepository {}

class MockUser extends Mock implements User {}

void main() {
  group('currentUserDocProvider', () {
    late MockAuthRepository authRepository;
    late MockUsersRepository usersRepository;
    late ProviderContainer container;

    setUp(() {
      authRepository = MockAuthRepository();
      usersRepository = MockUsersRepository();
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer buildContainer() {
      return ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          usersRepositoryProvider.overrideWithValue(usersRepository),
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
      verifyNever(() => usersRepository.watch(any()));
    });

    test('emits the AppUser when signed in', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('uid-123');
      when(() => authRepository.authStateChanges())
          .thenAnswer((_) => Stream.value(user));

      final appUser = AppUser(
        uid: 'uid-123',
        dob: DateTime.utc(2000, 1, 1),
        ageVerified: true,
      );
      when(() => usersRepository.watch('uid-123'))
          .thenAnswer((_) => Stream.value(appUser));

      container = buildContainer();

      final result = await waitFor(container, (value) => value == appUser);

      expect(result, appUser);
      verify(() => usersRepository.watch('uid-123')).called(1);
    });
  });
}
