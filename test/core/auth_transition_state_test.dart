import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class _MockUsers extends Mock implements UserRepository {}

/// QA sweep 2026-10-09 (universal edge case 7, auth transitions): sign-out
/// must drop per-user listeners and cached documents, so a later sign-in
/// re-subscribes under the new session instead of reusing a stream that the
/// backend already terminated (permission-denied once signed out).
/// Lets auth emit, the per-user providers rebuild, and their streams subscribe.
Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _MockUsers users;
  late StreamController<AuthUser?> auth;
  var subscriptions = 0;

  setUp(() {
    users = _MockUsers();
    auth = StreamController<AuthUser?>.broadcast();
    subscriptions = 0;
    when(() => users.watch(any())).thenAnswer((inv) {
      subscriptions++;
      return Stream.value(
        AppUser(
          uid: inv.positionalArguments.first as String,
          dob: DateTime.utc(1990),
        ),
      );
    });
  });

  tearDown(() => auth.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(users),
        authStateProvider.overrideWith((ref) => auth.stream),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a viewed profile is read through one live subscription', () async {
    final c = container();
    c.listen(authStateProvider, (_, __) {});
    auth.add(const AuthUser(uid: 'a'));
    await settle();
    c.listen(userDocProvider('x'), (_, __) {});
    await settle();
    expect(subscriptions, 1);
  });

  test('nothing is read while signed out or while auth is resolving', () async {
    final c = container();
    c.listen(userDocProvider('x'), (_, __) {}); // auth hasn't emitted yet
    await settle();
    expect(subscriptions, 0, reason: 'auth still resolving');

    c.listen(authStateProvider, (_, __) {});
    auth.add(null);
    await settle();
    expect(subscriptions, 0, reason: 'signed out: no Firestore listener');
    expect(c.read(userDocProvider('x')).value, isNull);
  });

  test('a profile that nobody watches any more closes its listener', () async {
    final c = container();
    c.listen(authStateProvider, (_, __) {});
    auth.add(const AuthUser(uid: 'a'));
    await settle();
    final sub = c.listen(userDocProvider('x'), (_, __) {});
    await settle();
    expect(subscriptions, 1);

    sub.close(); // the screen is gone -> auto-disposed
    await settle();
    c.listen(userDocProvider('x'), (_, __) {});
    await settle();
    expect(subscriptions, 2, reason: 'a fresh listener, not a stale cache');
  });

  test(
    'sign-out then sign-in re-subscribes per-user streams',
    () async {
      final c = container();
      final sub = c.listen(userDocProvider('x'), (_, __) {});
      c.listen(authStateProvider, (_, __) {});
      auth.add(const AuthUser(uid: 'a'));
      await settle();
      expect(subscriptions, 1);

      auth.add(null); // sign-out
      await settle();
      sub.close(); // the screen is gone
      auth.add(const AuthUser(uid: 'b')); // someone signs in
      await settle();
      c.listen(userDocProvider('x'), (_, __) {});
      await settle();

      expect(
        subscriptions,
        2,
        reason: 'the provider re-subscribes under the new session',
      );
    },
  );
}
