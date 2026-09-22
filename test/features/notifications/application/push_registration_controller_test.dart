import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/application/push_registration_controller.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

class MockPushRepository extends Mock implements PushRepository {}

void main() {
  late MockPushRepository pushRepository;
  late ProviderContainer container;

  setUp(() {
    pushRepository = MockPushRepository();

    when(() => pushRepository.registerToken(any())).thenAnswer((_) async {});
    when(() => pushRepository.unregisterCurrentToken(any()))
        .thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        pushRepositoryProvider.overrideWithValue(pushRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('PushRegistrationController', () {
    test(
      'register() calls registerToken(uid) and leaves state AsyncData when '
      'permission is granted',
      () async {
        when(() => pushRepository.requestPermission())
            .thenAnswer((_) async => true);

        await container
            .read(pushRegistrationControllerProvider.notifier)
            .register('uid_1');

        verify(() => pushRepository.registerToken('uid_1')).called(1);

        final state = container.read(pushRegistrationControllerProvider);
        expect(state.hasError, isFalse);
        expect(state, isA<AsyncData<void>>());
      },
    );

    test(
      'register() does NOT call registerToken when permission is denied',
      () async {
        when(() => pushRepository.requestPermission())
            .thenAnswer((_) async => false);

        await container
            .read(pushRegistrationControllerProvider.notifier)
            .register('uid_1');

        verifyNever(() => pushRepository.registerToken(any()));

        final state = container.read(pushRegistrationControllerProvider);
        expect(state.hasError, isFalse);
      },
    );

    test('unregister() calls unregisterCurrentToken(uid)', () async {
      await container
          .read(pushRegistrationControllerProvider.notifier)
          .unregister('uid_1');

      verify(() => pushRepository.unregisterCurrentToken('uid_1')).called(1);
    });
  });
}
