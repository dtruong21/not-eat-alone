import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/user/application/photo_storage_provider.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/data/datasources/photo_storage_datasource.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPhotoStorageDataSource extends Mock
    implements PhotoStorageDataSource {}

/// `analytics.track()` drops to `debugPrint` in debug builds (see
/// `lib/core/analytics/client.dart`) — intercept it here rather than mocking
/// analytics directly, since `track()` isn't provider-wired. [debugPrint] is
/// restored inside a `finally`, synchronously within the test body, rather
/// than via `tearDown()` — the flutter_test binding verifies foundation
/// debug variables are back to their defaults immediately after the test
/// body returns, which runs before a package:test `tearDown()` would fire.
Future<List<String>> _captureDebugLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) logs.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

AppUser _userWithPhotos(List<String> photoUrls) => AppUser(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      photoUrls: photoUrls,
    );

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late MockPhotoStorageDataSource photoStorage;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Gender.woman);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    photoStorage = MockPhotoStorageDataSource();

    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'u1'));
    when(() => authRepository.authStateChanges())
        .thenAnswer((_) => Stream.value(const AuthUser(uid: 'u1')));
    when(
      () => userRepository.updateProfile(
        uid: any(named: 'uid'),
        displayName: any(named: 'displayName'),
        photoUrls: any(named: 'photoUrls'),
        bio: any(named: 'bio'),
        gender: any(named: 'gender'),
      ),
    ).thenAnswer((_) async {});
  });

  ProviderContainer buildContainer({List<String> photoUrls = const []}) {
    when(() => userRepository.watch('u1'))
        .thenAnswer((_) => Stream.value(_userWithPhotos(photoUrls)));

    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        userRepositoryProvider.overrideWithValue(userRepository),
        photoStorageDataSourceProvider.overrideWithValue(photoStorage),
      ],
    );
  }

  /// Listens to [currentUserDocProvider] and resolves with the first
  /// `AsyncData` value matching [matches]. Mirrors the helper in
  /// `user_providers_test.dart` — a plain `container.read(
  /// currentUserDocProvider.future)` can hang without an active listener
  /// keeping the element alive across the `authStateProvider` rebuild.
  Future<AppUser?> waitForUserDoc(
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

  tearDown(() {
    container.dispose();
  });

  test('completeSetup writes required fields and fires profile_completed',
      () async {
    container = buildContainer();

    final logs = await _captureDebugLogs(() async {
      await container
          .read(profileControllerProvider.notifier)
          .completeSetup(displayName: 'Ada', gender: Gender.woman);
    });

    verify(
      () => userRepository.updateProfile(
        uid: 'u1',
        displayName: 'Ada',
        gender: Gender.woman,
        bio: null,
      ),
    ).called(1);
    expect(logs.any((l) => l.contains('profile_completed')), isTrue);

    final state = container.read(profileControllerProvider);
    expect(state.hasError, isFalse);
  });

  test('save writes given fields and fires profile_edited', () async {
    container = buildContainer();

    final logs = await _captureDebugLogs(() async {
      await container
          .read(profileControllerProvider.notifier)
          .save(bio: 'hi');
    });

    verify(
      () => userRepository.updateProfile(
        uid: 'u1',
        bio: 'hi',
        displayName: null,
        gender: null,
      ),
    ).called(1);
    expect(logs.any((l) => l.contains('profile_edited')), isTrue);
  });

  test(
    'addPhoto uploads at the next index, appends the url and fires '
    'profile_photo_added',
    () async {
      container = buildContainer();
      await waitForUserDoc(container, (value) => value?.photoUrls.isEmpty ?? false);
      when(
        () => photoStorage.upload(
          uid: any(named: 'uid'),
          index: any(named: 'index'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((_) async => 'https://example.com/photo0.jpg');

      final bytes = Uint8List.fromList([1, 2, 3]);
      final logs = await _captureDebugLogs(() async {
        await container
            .read(profileControllerProvider.notifier)
            .addPhoto(bytes);
      });

      verify(
        () => photoStorage.upload(uid: 'u1', index: 0, bytes: bytes),
      ).called(1);
      verify(
        () => userRepository.updateProfile(
          uid: 'u1',
          photoUrls: ['https://example.com/photo0.jpg'],
        ),
      ).called(1);
      expect(logs.any((l) => l.contains('profile_photo_added')), isTrue);
    },
  );

  test('removePhoto drops the url from photoUrls and deletes the object',
      () async {
    container = buildContainer(photoUrls: const ['u', 'v']);
    await waitForUserDoc(container, (value) => value != null);
    when(() => photoStorage.deleteByUrl(any())).thenAnswer((_) async {});

    await container.read(profileControllerProvider.notifier).removePhoto('u');

    verify(
      () => userRepository.updateProfile(uid: 'u1', photoUrls: ['v']),
    ).called(1);
    verify(() => photoStorage.deleteByUrl('u')).called(1);
  });
}
