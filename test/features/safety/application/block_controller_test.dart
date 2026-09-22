import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_controller.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockBlockRepository extends Mock implements BlockRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockBlockRepository blockRepository;
  late ProviderContainer container;

  setUp(() {
    authRepository = MockAuthRepository();
    blockRepository = MockBlockRepository();

    when(
      () => authRepository.currentUser,
    ).thenReturn(const AuthUser(uid: 'me'));
    when(
      () => blockRepository.block(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => blockRepository.unblock(any(), any()),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        blockRepositoryProvider.overrideWithValue(blockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('BlockController', () {
    test(
      'block() calls repo.block(myUid, x) and leaves state AsyncData',
      () async {
        await container.read(blockControllerProvider.notifier).block('x');

        verify(() => blockRepository.block('me', 'x')).called(1);

        final state = container.read(blockControllerProvider);
        expect(state.hasError, isFalse);
        expect(state, isA<AsyncData<void>>());
      },
    );

    test('block() leaves state.hasError true when the repo throws', () async {
      when(
        () => blockRepository.block(any(), any()),
      ).thenThrow(Exception('boom'));

      await container.read(blockControllerProvider.notifier).block('x');

      final state = container.read(blockControllerProvider);
      expect(state.hasError, isTrue);
    });

    test('unblock() calls repo.unblock(myUid, x)', () async {
      await container.read(blockControllerProvider.notifier).unblock('x');

      verify(() => blockRepository.unblock('me', 'x')).called(1);
    });
  });
}
