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
    c.listen(userDocProvider('x'), (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(subscriptions, 1);
  });

  test(
    'sign-out then sign-in re-subscribes per-user streams',
    () async {
      final c = container();
      final sub = c.listen(userDocProvider('x'), (_, __) {});
      c.listen(authStateProvider, (_, __) {});
      auth.add(const AuthUser(uid: 'a'));
      await Future<void>.delayed(Duration.zero);
      expect(subscriptions, 1);

      auth.add(null); // sign-out
      await Future<void>.delayed(Duration.zero);
      sub.close(); // the screen is gone
      auth.add(const AuthUser(uid: 'b')); // someone signs in
      await Future<void>.delayed(Duration.zero);
      c.listen(userDocProvider('x'), (_, __) {});
      await Future<void>.delayed(Duration.zero);

      expect(
        subscriptions,
        2,
        reason: 'the cached provider keeps the pre-sign-out stream alive',
      );
    },
    skip:
        'BUG docs/bugs/2026-10-09-providers-survive-sign-out.md '
        '(un-skip when fixed)',
  );
}
