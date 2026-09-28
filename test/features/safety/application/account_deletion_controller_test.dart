import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/account_deletion_controller.dart';
import 'package:not_eat_alone/features/safety/application/account_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/account_repository.dart';

import '../../../helpers/in_flight_dispose.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockAccountRepository accountRepository;
  late ProviderContainer container;

  setUp(() {
    authRepository = MockAuthRepository();
    accountRepository = MockAccountRepository();

    when(() => accountRepository.deleteAccount()).thenAnswer((_) async {});
    when(() => authRepository.signOut()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        accountRepositoryProvider.overrideWithValue(accountRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AccountDeletionController', () {
    test(
      'delete() calls accountRepository.deleteAccount then '
      'authRepository.signOut, leaving state AsyncData',
      () async {
        await container
            .read(accountDeletionControllerProvider.notifier)
            .delete();

        verifyInOrder([
          () => accountRepository.deleteAccount(),
          () => authRepository.signOut(),
        ]);

        final state = container.read(accountDeletionControllerProvider);
        expect(state.hasError, isFalse);
        expect(state, isA<AsyncData<void>>());
      },
    );

    test(
      'delete() leaves state.hasError true and does NOT sign out when the '
      'repo throws',
      () async {
        when(
          () => accountRepository.deleteAccount(),
        ).thenThrow(Exception('boom'));

        await container
            .read(accountDeletionControllerProvider.notifier)
            .delete();

        final state = container.read(accountDeletionControllerProvider);
        expect(state.hasError, isTrue);
        verifyNever(() => authRepository.signOut());
      },
    );
  });

  // Regression: the controller's only watcher unmounting mid-action used
  // to dispose it, so the trailing `state =` threw UnmountedRefException.
  test('AccountDeletionController.delete survives its listener '
      'unmounting mid-flight', () async {
    final gate = Completer<void>();
    when(() => accountRepository.deleteAccount())
        .thenAnswer((_) => gate.future);
    final seen = await runWithListenerRemovedMidFlight(
      container,
      accountDeletionControllerProvider,
      action: () => container
          .read(accountDeletionControllerProvider.notifier)
          .delete(),
      release: gate.complete,
    );

    expect(seen.first.isLoading, isTrue);
    expect(seen.last, isA<AsyncData<void>>());
    verify(() => authRepository.signOut()).called(1);
  });
}
