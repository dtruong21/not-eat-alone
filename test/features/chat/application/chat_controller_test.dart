import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_controller.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockChatRepository chatRepository;
  late ProviderContainer container;

  setUp(() {
    authRepository = MockAuthRepository();
    chatRepository = MockChatRepository();

    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'user_1'));
    when(() => chatRepository.sendMessage(
          matchId: any(named: 'matchId'),
          senderId: any(named: 'senderId'),
          text: any(named: 'text'),
        )).thenAnswer((_) async {});
    when(() => chatRepository.markRead(
          matchId: any(named: 'matchId'),
          uid: any(named: 'uid'),
        )).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        chatRepositoryProvider.overrideWithValue(chatRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ChatController', () {
    test(
      'send() calls sendMessage with matchId/text/uid and leaves AsyncData',
      () async {
        await container
            .read(chatControllerProvider.notifier)
            .send(matchId: 'match_1', text: 'hello');

        verify(
          () => chatRepository.sendMessage(
            matchId: 'match_1',
            senderId: 'user_1',
            text: 'hello',
          ),
        ).called(1);

        final state = container.read(chatControllerProvider);
        expect(state.hasError, isFalse);
        expect(state, isA<AsyncData<void>>());
      },
    );

    test('send() no-ops on blank text', () async {
      await container
          .read(chatControllerProvider.notifier)
          .send(matchId: 'match_1', text: '   ');

      verifyNever(
        () => chatRepository.sendMessage(
          matchId: any(named: 'matchId'),
          senderId: any(named: 'senderId'),
          text: any(named: 'text'),
        ),
      );
    });

    test('send() leaves state.hasError true when sendMessage throws',
        () async {
      when(() => chatRepository.sendMessage(
            matchId: any(named: 'matchId'),
            senderId: any(named: 'senderId'),
            text: any(named: 'text'),
          )).thenThrow(Exception('boom'));

      await container
          .read(chatControllerProvider.notifier)
          .send(matchId: 'match_1', text: 'hello');

      final state = container.read(chatControllerProvider);
      expect(state.hasError, isTrue);
    });

    test('markRead() calls repo.markRead with the current uid', () async {
      await container
          .read(chatControllerProvider.notifier)
          .markRead('match_1');

      verify(
        () => chatRepository.markRead(matchId: 'match_1', uid: 'user_1'),
      ).called(1);
    });
  });
}
