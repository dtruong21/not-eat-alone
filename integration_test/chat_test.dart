/// Scenario 3 — chat: a host sends a message on a matched meal via the real
/// Chats-tab -> chat -> composer UI, the message-create rule
/// (`matchMessageCreateOk` — `firebase/firestore.rules`) is exercised live,
/// and the guest reads it (and the read-receipt path) back through the same
/// UI. A final negative case blocks the pair and asserts a direct SDK
/// message create is denied. Run via `make e2e` (see `Makefile`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Installs a `FlutterError.onError` filter that SWALLOWS the expected
/// avatar-image 404 noise, and restores the previous handler at teardown.
/// See `request_match_test.dart`'s copy of this helper for the full
/// rationale (`seedUserProfile`'s `photoUrls` entry 404s on every
/// `NetworkImage` avatar this scenario's screens render).
void _suppressExpectedImageErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// A hand-rolled, bounded `pumpAndSettle` — see `request_match_test.dart`'s
/// copy for why the unbounded default must never be used here.
Future<void> _settle(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 100),
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(step);
  } while (tester.binding.hasScheduledFrame &&
      DateTime.now().isBefore(deadline));
}

/// Bounded pump loop that waits for [finder] to appear, up to [timeout],
/// then does a short, best-effort [_settle]. See `request_match_test.dart`.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await _settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets('host sends a message the guest can read', (tester) async {
    // Same single-boot pattern as request_match_test.dart: `pumpApp` calls
    // `Firebase.initializeApp()` exactly once for this test process; the
    // rest of the scenario reuses that one booted app across the host and
    // guest sessions via sign-out/sign-in on the same `FirebaseAuth`
    // instance, which the already-running app's `authStateProvider` stream
    // reacts to.
    _suppressExpectedImageErrors();
    await pumpApp(tester);

    // Arrange: host + guest profiles, then a pre-matched meal seeded
    // directly (scenario 2 already exercises the request -> approve ->
    // match path live; this scenario starts post-match). `seedMatch` must
    // run while signed in as the host (`matches` create requires
    // `hostId == auth.uid`).
    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final guest = await signInTestUser(uid: 'guest-1');
    await seedUserProfile(uid: guest.uid);
    await signInTestUser(uid: host.uid);
    final matchId = await seedMatch(hostId: host.uid, guestId: guest.uid);

    // Wait for the host session to land on the authed Discover feed (same
    // marker as request_match_test.dart / smoke_test.dart).
    final discoverMarker = find.byKey(
      const Key('discovery_create_meal_button'),
    );
    await _pumpUntilFound(tester, discoverMarker);
    expect(
      discoverMarker,
      findsOneWidget,
      reason: 'host session did not land on the authed Discover feed',
    );

    // Bottom-nav "Chats" tab (`app_shell.dart` — a `NavigationDestination`
    // labelled "Chats"; no dedicated `Key`). Found before `ChatListScreen`
    // mounts, so this is the only "Chats" text in the tree — its own
    // `AppBar` title is also "Chats" (`chat_list_screen.dart:27`), which
    // would make the finder ambiguous once that screen is up.
    final chatsTab = find.text('Chats');
    expect(chatsTab, findsOneWidget);
    await tester.tap(chatsTab);
    await _settle(tester);

    final chatTile = find.byKey(Key('chat_list_tile_$matchId'));
    await _pumpUntilFound(tester, chatTile);
    expect(
      chatTile,
      findsOneWidget,
      reason: "host's Chats tab did not render the seeded match",
    );

    await tester.tap(chatTile);
    await _settle(tester);

    const messageText = 'Hey, excited for the meal!';
    final composerField = find.byKey(const Key('message_composer_field'));
    await _pumpUntilFound(tester, composerField);
    expect(
      composerField,
      findsOneWidget,
      reason: 'chat screen did not render the message composer',
    );

    await tester.enterText(composerField, messageText);
    // Settle so `MessageComposer`'s `onChanged` -> `setState` rebuild
    // enables the send button (`canSend = hasText && !isSending`) before
    // it's tapped below.
    await _settle(tester);

    final sendButton = find.byKey(
      const Key('message_composer_send_button'),
    );
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await _settle(tester);

    // Assert: the message doc exists with the sender/text the rule
    // enforced live (`matchMessageCreateOk`, `firebase/firestore.rules`).
    // Poll — the tap above isn't a guarantee the write has landed yet.
    final sentMessages = await pollUntil(() async {
      final s = await _db
          .collection('matches')
          .doc(matchId)
          .collection('messages')
          .get();
      return s.docs.isNotEmpty ? s : null;
    });
    expect(sentMessages.docs, hasLength(1));
    expect(sentMessages.docs.first['senderId'], host.uid);
    expect(sentMessages.docs.first['text'], messageText);

    await signOutTestUser();

    // Act (guest): sign back in and open the same chat through the real UI.
    await signInTestUser(uid: guest.uid);

    await _pumpUntilFound(tester, discoverMarker);
    expect(
      discoverMarker,
      findsOneWidget,
      reason: 'guest session did not land on the authed Discover feed',
    );

    final chatsTabGuest = find.text('Chats');
    expect(chatsTabGuest, findsOneWidget);
    await tester.tap(chatsTabGuest);
    await _settle(tester);

    final chatTileGuest = find.byKey(Key('chat_list_tile_$matchId'));
    await _pumpUntilFound(tester, chatTileGuest);
    expect(
      chatTileGuest,
      findsOneWidget,
      reason: "guest's Chats tab did not render the seeded match",
    );

    await tester.tap(chatTileGuest);
    await _settle(tester);

    // Assert: the host's message renders in the guest's chat.
    final renderedMessage = find.text(messageText);
    await _pumpUntilFound(tester, renderedMessage);
    expect(
      renderedMessage,
      findsOneWidget,
      reason: "guest's chat screen did not render the host's message",
    );

    // Assert: opening the chat wrote a read receipt (`ChatScreen.initState`
    // -> `ChatController.markRead` -> `matches/{matchId}/reads/{uid}`).
    // `lastReadAt` is a `FieldValue.serverTimestamp()`, and the app and this
    // test share one Firestore SDK instance, so a `get` can return the local
    // view of the still-pending write, where the unresolved server timestamp
    // reads as null. Wait for it to resolve, not just for the doc to exist.
    final readDoc = await pollUntil(() async {
      final r = await _db
          .collection('matches')
          .doc(matchId)
          .collection('reads')
          .doc(guest.uid)
          .get();
      return r.exists && r.data()?['lastReadAt'] != null ? r : null;
    });
    expect(readDoc.data()!['uid'], guest.uid);
    expect(readDoc.data()!['lastReadAt'], isNotNull);

    await signOutTestUser();

    // Negative case (optional per the brief, kept small): block the pair,
    // then assert a direct-SDK message create is denied by
    // `matchMessageCreateOk`'s `noBlockBetween` check. This is a rules
    // assertion, not a UI flow, so it goes straight through the SDK — the
    // create rule requires `blockerUid == auth.uid`, so it's seeded signed
    // in as the host.
    await signInTestUser(uid: host.uid);
    await _db.collection('blocks').doc('${host.uid}_${guest.uid}').set({
      'blockerUid': host.uid,
      'blockedUid': guest.uid,
      'pair': [host.uid, guest.uid],
    });

    await expectLater(
      _db.collection('matches').doc(matchId).collection('messages').add({
        'matchId': matchId,
        'senderId': host.uid,
        'text': 'should be blocked',
        'createdAt': FieldValue.serverTimestamp(),
      }),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );

    // Any non-image error would have been recorded by the binding here.
    expect(tester.takeException(), isNull);
  });
}
