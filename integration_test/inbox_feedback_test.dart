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
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/main_common.dart';

import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Swallows the expected avatar-image 404 noise (`NetworkImageLoadException`)
/// and restores the previous `FlutterError.onError` at teardown. See
/// `request_match_test.dart`'s copy of this helper for the full rationale.
void _suppressExpectedImageErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// A hand-rolled, bounded `pumpAndSettle` — see `request_match_test.dart`'s
/// copy for the rationale (never the unbounded 10-minute default).
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

/// Bounded pump loop that waits for [finder] to appear, then a short
/// best-effort [_settle]. See `request_match_test.dart`.
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

/// Boots the app for this test; same single-boot pattern as
/// `request_match_test.dart` (`bootstrap` may run once per process).
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
    final when = DateTime.now().subtract(const Duration(hours: 2));
    final mealId = await seedOpenMeal(hostId: host.uid, dateTime: when);
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
    expect(
      find.descendant(of: mealLine, matching: find.text('Seed Restaurant')),
      findsOneWidget,
    );
    // The app renders the instant in the viewer's local time, as does the
    // test process (same simulator timezone).
    expect(
      find.descendant(
        of: mealLine,
        matching: find.text(formatMealDateTime(when)),
      ),
      findsOneWidget,
    );

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
    final when = DateTime.now().add(const Duration(hours: 3));
    final mealId = await seedOpenMeal(hostId: host.uid, dateTime: when);
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
    expect(
      find.descendant(of: mealLine, matching: find.text('Seed Restaurant')),
      findsOneWidget,
    );
    // The app renders the instant in the viewer's local time, as does the
    // test process (same simulator timezone).
    expect(
      find.descendant(
        of: mealLine,
        matching: find.text(formatMealDateTime(when)),
      ),
      findsOneWidget,
    );
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

    await tester.tap(chatAction);
    await _settle(tester);

    final composer = find.byKey(const Key('message_composer_field'));
    await _pumpUntilFound(tester, composer);
    expect(
      composer,
      findsOneWidget,
      reason: "the snackbar's Chat action did not open the chat screen",
    );

    // Match doc is polled AFTER the UI path (tap first, then verify).
    final match = await pollUntil(() async {
      final m = await _db.collection('matches').doc(mealId).get();
      return m.exists ? m : null;
    });
    expect(
      match.data()!['participants'] as List<Object?>,
      containsAll([host.uid, guest.uid]),
    );

    expect(tester.takeException(), isNull);
  });
}
