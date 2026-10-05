/// Inbox feedback — a past-meal request is marked and clearable, and an
/// approve gives feedback and opens the chat. Both scenarios drive the real
/// host Requests-inbox UI (`RequestInboxTile`) against the Firebase emulators
/// with the real, enforced `firestore.rules`. Run via `make e2e` (see
/// `Makefile`).
///
/// A) Past meal: the `requests` create rule rejects a request on a past meal,
///    so the pending request is written through the admin REST helper. The
///    tile shows the meal line and the past chip, Approve is disabled, and
///    Deny clears it ("Request denied." snackbar, doc `denied`).
/// B) Future meal: the guest requests via the rules-enforced SDK helper; the
///    host approves, sees "Approved. You can chat now." and taps its Chat
///    action to open the chat.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:not_eat_alone/main_common.dart';

import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Installs a `FlutterError.onError` filter that SWALLOWS the expected
/// avatar-image 404 noise, and restores the previous handler at teardown.
///
/// `seedUserProfile` (`support/seed.dart`) writes a non-empty but
/// non-existent `photoUrls` entry (`https://example.com/avatar.png`) purely
/// to satisfy `AppUser.profileComplete`'s non-empty check
/// (`lib/features/user/domain/entities/app_user.dart`) — every real screen
/// this scenario visits (`discovery_screen.dart`'s `_HostInfo`,
/// `meal_detail_screen.dart`'s `_HostBlock`, `request_inbox_tile.dart`)
/// renders a `CircleAvatar(backgroundImage: NetworkImage(photoUrl))` off
/// that URL, so a 404 `NetworkImageLoadException` is EXPECTED noise here
/// (confirmed live — see task-4-report.md), not a real app defect.
///
/// Filtering it at the source (`FlutterError.onError`) — rather than draining
/// the binding's recorded exceptions after every pump — is robust to MULTIPLE
/// avatars failing within a single pumped frame (which happens on the
/// Discover -> meal-detail transition, when both screens' host avatars are in
/// the tree). Once 2+ exceptions have accumulated in the binding since the
/// last check, `tester.takeException()` throws a synthetic "Multiple
/// exceptions (N) were detected... at least one was unexpected" `TestFailure`
/// that discards the individual exceptions, so a post-pump drain can no
/// longer tell expected `NetworkImageLoadException`s from a real regression.
/// Swallowing at `onError` keeps those image errors from ever being recorded,
/// while every OTHER error still chains through to the binding's own handler
/// and fails the test loudly — so a genuine regression is never masked.
void _suppressExpectedImageErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// A hand-rolled, bounded `pumpAndSettle` (same loop shape — pump on [step]
/// while `binding.hasScheduledFrame`, bounded by [timeout]). Must never use
/// `pumpAndSettle()`'s unbounded 10-minute default: an actively-animating
/// widget (e.g. a `CircularProgressIndicator` shown while an upstream
/// provider is still `AsyncLoading`) would hang it (see task-3-report.md).
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
/// then does a short, best-effort [_settle]. Used at every async auth/
/// Firestore-stream boundary in this scenario (sign-in -> router redirect,
/// meal-list stream picking up a just-seeded doc, request-state stream
/// picking up the just-created request, host-inbox stream picking up the
/// just-created request) instead of a fixed `Future.delayed`.
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

/// Bounded pump loop that waits for [finder] to DISAPPEAR, up to [timeout].
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await _settle(tester);
}

/// Boots the app for this test. `bootstrap` (via `pumpApp`) may run only ONCE
/// per process (a second call would re-call `useFirestoreEmulator` on a
/// started instance and throw), so later tests in this file reuse the
/// already-initialized Firebase and just mount a fresh `ProviderScope` app.
Future<void> _boot(WidgetTester tester) async {
  _suppressExpectedImageErrors();
  if (Firebase.apps.isEmpty) {
    await pumpApp(tester);
  } else {
    // Previous scenario's session is still signed in; start unauthenticated.
    await signOutTestUser();
    await tester.pumpWidget(const ProviderScope(child: NotEatAloneApp()));
    await _settle(tester);
  }
}

/// With the host session signed in, waits for the authed Discover feed, then
/// opens the Requests tab.
Future<void> _openRequestsTab(WidgetTester tester) async {
  final discoverMarker = find.byKey(const Key('discovery_create_meal_button'));
  await _pumpUntilFound(tester, discoverMarker);
  expect(
    discoverMarker,
    findsOneWidget,
    reason: 'host session did not land on the authed Discover feed',
  );
  final requestsTab = find.text('Requests');
  expect(requestsTab, findsOneWidget);
  await tester.tap(requestsTab);
  await _settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets('past-meal request is marked, Approve disabled, Deny clears it', (
    tester,
  ) async {
    await _boot(tester);

    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    await signOutTestUser();
    final guest = await signInTestUser(uid: 'guest-1');
    await seedUserProfile(uid: guest.uid);

    // Past OPEN meal + pending request, both via admin REST (rules reject
    // both a past-dated meal create and a request on a past meal).
    final mealId = await seedOpenMeal(
      hostId: host.uid,
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
    );
    final requestId = '${mealId}_${guest.uid}';
    await adminSetDoc('requests', requestId, {
      'id': requestId,
      'mealId': mealId,
      'guestId': guest.uid,
      'hostId': host.uid,
      'status': 'pending',
      'createdAt': DateTime.now(),
    });
    await signOutTestUser();

    await signInTestUser(uid: host.uid);
    await _openRequestsTab(tester);

    final tile = find.byKey(Key('request_inbox_tile_$requestId'));
    await _pumpUntilFound(tester, tile);
    expect(tile, findsOneWidget, reason: 'host inbox did not render the tile');

    final mealLine = find.byKey(Key('request_inbox_meal_line_$requestId'));
    await _pumpUntilFound(tester, mealLine);
    expect(mealLine, findsOneWidget);
    expect(tester.widget<Text>(mealLine).data, contains('Seed Restaurant'));

    final pastChip = find.byKey(Key('request_inbox_past_chip_$requestId'));
    expect(pastChip, findsOneWidget);

    final approve = find.byKey(Key('request_inbox_approve_button_$requestId'));
    final deny = find.byKey(Key('request_inbox_deny_button_$requestId'));
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(deny).onPressed, isNotNull);

    await tester.tap(deny);
    await _settle(tester);

    final deniedSnack = find.text('Request denied.');
    await _pumpUntilFound(tester, deniedSnack);
    expect(deniedSnack, findsOneWidget);
    await _pumpUntilGone(tester, tile);
    expect(tile, findsNothing);

    final denied = await pollUntil(() async {
      final snap = await _db.collection('requests').doc(requestId).get();
      return snap.data()?['status'] == 'denied' ? snap : null;
    });
    expect(denied.data()!['status'], 'denied');

    expect(tester.takeException(), isNull);
  });

  testWidgets('approve shows feedback and its Chat action opens the chat', (
    tester,
  ) async {
    await _boot(tester);

    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final mealId = await seedOpenMeal(hostId: host.uid);
    await signOutTestUser();

    final guest = await signInTestUser(uid: 'guest-1');
    await seedUserProfile(uid: guest.uid);
    final requestId = await seedPendingRequest(
      mealId: mealId,
      guestId: guest.uid,
      hostId: host.uid,
    );
    await signOutTestUser();

    await signInTestUser(uid: host.uid);
    await _openRequestsTab(tester);

    final tile = find.byKey(Key('request_inbox_tile_$requestId'));
    await _pumpUntilFound(tester, tile);
    expect(tile, findsOneWidget, reason: 'host inbox did not render the tile');

    final mealLine = find.byKey(Key('request_inbox_meal_line_$requestId'));
    await _pumpUntilFound(tester, mealLine);
    expect(mealLine, findsOneWidget);
    expect(tester.widget<Text>(mealLine).data, contains('Seed Restaurant'));
    expect(find.byKey(Key('request_inbox_past_chip_$requestId')), findsNothing);

    final approve = find.byKey(Key('request_inbox_approve_button_$requestId'));
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.tap(approve);
    await _settle(tester);

    final approvedSnack = find.text('Approved. You can chat now.');
    await _pumpUntilFound(tester, approvedSnack);
    expect(approvedSnack, findsOneWidget);
    // The bottom nav also has a "Chats" label, hence the typed finder.
    final chatAction = find.widgetWithText(SnackBarAction, 'Chat');
    expect(chatAction, findsOneWidget);

    final match = await pollUntil(() async {
      final m = await _db.collection('matches').doc(mealId).get();
      return m.exists ? m : null;
    });
    expect(
      match.data()!['participants'] as List<Object?>,
      containsAll([host.uid, guest.uid]),
    );

    await tester.tap(chatAction);
    await _settle(tester);

    final composer = find.byKey(const Key('message_composer_field'));
    await _pumpUntilFound(tester, composer);
    expect(
      composer,
      findsOneWidget,
      reason: "the snackbar's Chat action did not open the chat screen",
    );

    expect(tester.takeException(), isNull);
  });
}
