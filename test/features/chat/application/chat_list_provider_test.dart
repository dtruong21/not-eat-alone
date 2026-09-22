import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';

class MockMatchRepository extends Mock implements MatchRepository {}

/// Waits for [chatListProvider] to settle on its first `AsyncData`/
/// `AsyncError`. `chatListProvider.future` ties itself to whichever stream
/// was live on the provider's first build and doesn't follow the rebuild
/// that happens once `authStateProvider` resolves, so it never completes
/// here; listening for the state change (same mechanism a widget's
/// `ref.watch(...)` uses) does — mirrors
/// `discovery_controller_test.dart`'s `_awaitDiscoveryResult`.
Future<List<ChatListItem>> _awaitChatListResult(
  ProviderContainer container,
) {
  final completer = Completer<List<ChatListItem>>();
  final sub = container.listen(chatListProvider, (prev, next) {
    next.when(
      data: (data) {
        if (!completer.isCompleted) completer.complete(data);
      },
      error: (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      loading: () {},
    );
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

const _matchWithOkGuest = Match(
  id: 'm1',
  mealId: 'meal1',
  hostId: 'me',
  guestId: 'ok',
);

const _matchWithBlockedGuest = Match(
  id: 'm2',
  mealId: 'meal2',
  hostId: 'me',
  guestId: 'blockedUid',
);

void main() {
  late MockMatchRepository matchRepository;

  setUp(() {
    matchRepository = MockMatchRepository();
    when(() => matchRepository.watchMatchesForUser('me')).thenAnswer(
      (_) => Stream.value([_matchWithOkGuest, _matchWithBlockedGuest]),
    );
  });

  ProviderContainer buildContainer({Set<String> blocked = const {}}) =>
      ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          matchRepositoryProvider.overrideWithValue(matchRepository),
          blockedUserIdsProvider.overrideWith(
            (ref) => Stream.value(blocked),
          ),
        ],
      );

  test('excludes matches whose other participant is blocked', () async {
    final container = buildContainer(blocked: const {'blockedUid'});
    addTearDown(container.dispose);

    final result = await _awaitChatListResult(container);

    expect(result.map((i) => i.otherUid), ['ok']);
  });

  test('includes all matches when no one is blocked', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    final result = await _awaitChatListResult(container);

    expect(result.map((i) => i.otherUid), ['ok', 'blockedUid']);
  });
}
