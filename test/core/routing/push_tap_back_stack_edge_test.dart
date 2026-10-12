import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/notifications/push_listener.dart';
import 'package:not_eat_alone/core/routing/router.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockMatchRepository extends Mock implements MatchRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _NoopPushRepository implements PushRepository {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> registerToken(String uid) async {}

  @override
  Future<void> unregisterCurrentToken(String uid) async {}
}

/// QA sweep 2026-10-12: a tapped push navigates with `router.go(...)`
/// (`pushNavigateProvider`), whereas every in-app entry to a chat uses
/// `push(...)`. `go` to a top-level route replaces the whole stack, so the
/// chat opened from a push has nothing underneath it: no back arrow, and the
/// shell (with the `PushListener`) is gone.
const _bug = 'docs/bugs/2026-10-12-push-tap-strands-user-in-chat-without-back.md';

void main() {
  testWidgets('chat opened with push() keeps the shell underneath (baseline)', (
    tester,
  ) async {
    final c = await _mount(tester);
    unawaited(c.read(routerProvider).push<void>('/chats/m1'));
    await _settle(tester);
    expect(_stackDepth(c), 2);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a chat opened from a push tap can be left (has a way back)', (
    tester,
  ) async {
    final c = await _mount(tester);
    // Exactly what PushListener does for a tapped `message` push.
    c.read(pushNavigateProvider)('/chats/m1');
    await _settle(tester);
    expect(
      _stackDepth(c),
      2,
      reason: 'go() replaced the stack: the chat has no back arrow ($_bug)',
    );
    expect(
      find.byType(BackButton),
      findsOneWidget,
      reason: 'iOS has no system back: the user is stuck on the chat',
    );
  }, skip: true); // open bug: see _bug
}

int _stackDepth(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.matches.length;

Future<ProviderContainer> _mount(WidgetTester tester) async {
  FlavorConfig.current = FlavorConfig(flavor: Flavor.stage);
  final user = AppUser(
    uid: 'u1',
    dob: DateTime.utc(1990),
    ageVerified: true,
    displayName: 'Ana',
    photoUrls: const ['https://example.test/a.jpg'],
    gender: Gender.woman,
  );
  final chat = _MockChatRepository();
  when(() => chat.watchMessages(any())).thenAnswer((_) => Stream.value([]));
  when(
    () => chat.markRead(
      matchId: any(named: 'matchId'),
      uid: any(named: 'uid'),
    ),
  ).thenAnswer((_) async {});
  final matches = _MockMatchRepository();
  when(() => matches.watchMatchesForUser(any()))
      .thenAnswer((_) => Stream.value([]));
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'u1'));
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chat),
      matchRepositoryProvider.overrideWithValue(matches),
      authRepositoryProvider.overrideWithValue(auth),
      blockedUserIdsProvider.overrideWith((ref) => Stream.value(<String>{})),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(uid: 'u1')),
      ),
      currentUserDocProvider.overrideWith((ref) => Stream.value(user)),
      discoveryControllerProvider.overrideWith((ref) => Stream.value([])),
      pendingRequestCountProvider.overrideWithValue(0),
      appVersionProvider.overrideWith((ref) async => '1.0.0'),
      foregroundPushMessagesProvider.overrideWithValue(
        const Stream<RemoteMessage>.empty(),
      ),
      openedPushMessagesProvider.overrideWithValue(
        const Stream<RemoteMessage>.empty(),
      ),
      initialPushMessageProvider.overrideWithValue(() async => null),
      pushRepositoryProvider.overrideWithValue(_NoopPushRepository()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  // Firebase-backed screens we don't stub may throw while building.
  while (tester.takeException() != null) {}
}
