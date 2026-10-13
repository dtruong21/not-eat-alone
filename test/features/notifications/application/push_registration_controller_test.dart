import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/application/push_registration_controller.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

import '../../../helpers/in_flight_dispose.dart';

class MockPushRepository extends Mock implements PushRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockPushRepository pushRepository;
  late MockAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    pushRepository = MockPushRepository();
    auth = MockAuthRepository();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'uid_1'));

    when(
      () => pushRepository.registerToken(any(), lang: any(named: 'lang')),
    ).thenAnswer((_) async {});
    when(
      () => pushRepository.updateTokenLanguage(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => pushRepository.unregisterCurrentToken(any()),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        pushRepositoryProvider.overrideWithValue(pushRepository),
        authRepositoryProvider.overrideWithValue(auth),
        deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('PushRegistrationController', () {
    test('register() calls registerToken(uid) and leaves state AsyncData when '
        'permission is granted', () async {
      when(
        () => pushRepository.requestPermission(),
      ).thenAnswer((_) async => true);

      await container
          .read(pushRegistrationControllerProvider.notifier)
          .register('uid_1');

      verify(() => pushRepository.registerToken('uid_1', lang: 'en')).called(1);

      final state = container.read(pushRegistrationControllerProvider);
      expect(state.hasError, isFalse);
      expect(state, isA<AsyncData<void>>());
    });

    test(
      'register() does NOT call registerToken when permission is denied',
      () async {
        when(
          () => pushRepository.requestPermission(),
        ).thenAnswer((_) async => false);

        await container
            .read(pushRegistrationControllerProvider.notifier)
            .register('uid_1');

        verifyNever(
          () => pushRepository.registerToken(any(), lang: any(named: 'lang')),
        );

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

  // Regression: the controller's only watcher unmounting mid-action used
  // to dispose it, so the trailing `state =` threw UnmountedRefException.
  test('PushRegistrationController.register survives its listener '
      'unmounting mid-flight', () async {
    final gate = Completer<void>();
    when(
      () => pushRepository.requestPermission(),
    ).thenAnswer((_) => gate.future.then((_) => true));
    final seen = await runWithListenerRemovedMidFlight(
      container,
      pushRegistrationControllerProvider,
      action: () => container
          .read(pushRegistrationControllerProvider.notifier)
          .register('uid_1'),
      release: gate.complete,
    );

    expect(seen.first.isLoading, isTrue);
    expect(seen.last, isA<AsyncData<void>>());
    verify(() => pushRepository.registerToken('uid_1', lang: 'en')).called(1);
  });

  group('language sync', () {
    Future<void> registerGranted() async {
      when(
        () => pushRepository.requestPermission(),
      ).thenAnswer((_) async => true);
      await container
          .read(pushRegistrationControllerProvider.notifier)
          .register('uid_1');
      // Nobody watches the controller: it must stay alive while registered.
      await container.pump();
    }

    test(
      'registers with the resolved language (choice beats device)',
      () async {
        container.read(localeControllerProvider.notifier).state = const Locale(
          'fr',
        );
        await registerGranted();
        verify(
          () => pushRepository.registerToken('uid_1', lang: 'fr'),
        ).called(1);
      },
    );

    test('a locale change during the permission prompt is not lost', () async {
      final gate = Completer<bool>();
      when(
        () => pushRepository.requestPermission(),
      ).thenAnswer((_) => gate.future);
      final registering = container
          .read(pushRegistrationControllerProvider.notifier)
          .register('uid_1');
      container.read(localeControllerProvider.notifier).state = const Locale(
        'fr',
      );
      gate.complete(true);
      await registering;
      verify(() => pushRepository.registerToken('uid_1', lang: 'fr')).called(1);
    });

    test('a locale change triggers exactly one updateTokenLanguage', () async {
      await registerGranted();
      container.read(localeControllerProvider.notifier).state = const Locale(
        'fr',
      );
      await container.pump();
      verify(() => pushRepository.updateTokenLanguage('uid_1', 'fr')).called(1);
    });

    test('a change that keeps the resolved language writes nothing', () async {
      await registerGranted();
      container.read(localeControllerProvider.notifier).state = const Locale(
        'en',
      );
      await container.pump();
      verifyNever(() => pushRepository.updateTokenLanguage(any(), any()));
    });

    test('never registered or permission denied: nothing is written', () async {
      container.listen(pushRegistrationControllerProvider, (_, _) {});
      container.read(localeControllerProvider.notifier).state = const Locale(
        'fr',
      );
      when(
        () => pushRepository.requestPermission(),
      ).thenAnswer((_) async => false);
      await container
          .read(pushRegistrationControllerProvider.notifier)
          .register('uid_1');
      container.read(localeControllerProvider.notifier).state = const Locale(
        'en',
      );
      await container.pump();
      verifyNever(() => pushRepository.updateTokenLanguage(any(), any()));
    });

    test('after unregister a locale change writes nothing', () async {
      await registerGranted();
      await container
          .read(pushRegistrationControllerProvider.notifier)
          .unregister('uid_1');
      container.read(localeControllerProvider.notifier).state = const Locale(
        'fr',
      );
      await container.pump();
      verifyNever(() => pushRepository.updateTokenLanguage(any(), any()));
    });

    test(
      'after a sign-out that bypassed the controller nothing is written',
      () async {
        await registerGranted();
        when(() => auth.currentUser).thenReturn(null);
        container.read(localeControllerProvider.notifier).state = const Locale(
          'fr',
        );
        await container.pump();
        verifyNever(() => pushRepository.updateTokenLanguage(any(), any()));
      },
    );

    test('a failing write does not throw out', () async {
      await registerGranted();
      when(
        () => pushRepository.updateTokenLanguage(any(), any()),
      ).thenThrow(StateError('boom'));
      container.read(localeControllerProvider.notifier).state = const Locale(
        'fr',
      );
      await container.pump();
      verify(() => pushRepository.updateTokenLanguage('uid_1', 'fr')).called(1);
    });

    test('an async failing write does not reach the zone', () async {
      await registerGranted();
      when(
        () => pushRepository.updateTokenLanguage(any(), any()),
      ).thenAnswer((_) async => throw StateError('boom'));
      container.read(localeControllerProvider.notifier).state = const Locale(
        'fr',
      );
      await container.pump();
      await Future<void>.delayed(Duration.zero);
    });
  });
}
