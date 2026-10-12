import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';

class _MockBlocks extends Mock implements BlockRepository {}

void main() {
  test('streams the uids the signed-in user blocked', () async {
    final repo = _MockBlocks();
    when(
      () => repo.watchBlockedByMe('me'),
    ).thenAnswer((_) => Stream.value({'x'}));
    final container = ProviderContainer(
      overrides: [
        blockRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'me')),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(blockedByMeProvider, (_, _) {});

    expect(await container.read(blockedByMeProvider.future), {'x'});
  });

  test('signed out: empty set and no repository listener', () async {
    final repo = _MockBlocks();
    final container = ProviderContainer(
      overrides: [
        blockRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(blockedByMeProvider, (_, _) {});

    expect(await container.read(blockedByMeProvider.future), isEmpty);
    verifyNever(() => repo.watchBlockedByMe(any()));
  });
}
