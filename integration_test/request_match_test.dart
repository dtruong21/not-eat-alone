/// Scenario 2 — request → approve → match: a guest requests a host's open
/// meal via the real Discover -> meal-detail UI, the host approves via the
/// real Requests-inbox UI, and the client-side approve transaction
/// (`RequestRepositoryImpl.approve` — `lib/features/matching/data/
/// repositories/request_repository_impl.dart`) creates the match. Run via
/// `make e2e` (see `Makefile`).
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
/// widget (e.g. a loading indicator / skeleton shown while an upstream
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets('guest requests, host approves, match is created', (
    tester,
  ) async {
    // Boot the app once, before any Firebase Auth/Firestore calls —
    // `pumpApp` is what calls `Firebase.initializeApp()` (via `bootstrap`);
    // both `signInTestUser`/`seedUserProfile` need an initialized app first
    // (see smoke_test.dart / task-3-report.md). The rest of this scenario
    // reuses this SAME booted app instance across both the guest and host
    // sessions (sign-out/sign-in mutate the same `FirebaseAuth` session the
    // already-running app's `authStateProvider` stream watches, so its
    // router reacts each time) — deliberately NOT calling `pumpApp` a
    // second time, since `bootstrap` re-calling `Firebase.initializeApp()`
    // mid-test on an already-initialized default app is untested territory
    // this scenario doesn't need to exercise.
    // Installed first, before any frame renders an avatar (see the helper's
    // doc). Scoped to this test: restored via `addTearDown`, which runs
    // before the binding's own `postTest` teardown (tear-downs are LIFO).
    _suppressExpectedImageErrors();
    await pumpApp(tester);

    // Arrange: host seeds their profile + an open meal.
    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final mealId = await seedOpenMeal(hostId: host.uid);
    await signOutTestUser();

    // Act (guest): sign in, seed a profile-complete guest (a woman, so she's
    // eligible even if a meal happened to be women-only), then drive the
    // real UI: Discover -> the seeded meal's card -> meal detail -> "Request
    // to join".
    final guest = await signInTestUser(uid: 'guest-1');
    // `gender: 'woman'` is `seedUserProfile`'s default (see `support/
    // seed.dart`) — passed implicitly, but called out here since a
    // women-only seeded meal would otherwise silently exclude this guest.
    await seedUserProfile(uid: guest.uid);

    // Wait for the guest's session to land on Discover (same marker as
    // smoke_test.dart: outside the meal-list `AsyncValue.when`, so it
    // renders regardless of the list's own loading/data state).
    final discoverMarker = find.byKey(
      const Key('discovery_create_meal_button'),
    );
    await _pumpUntilFound(tester, discoverMarker);
    expect(
      discoverMarker,
      findsOneWidget,
      reason: 'guest session did not land on the authed Discover feed',
    );

    // Wait for the seeded meal's card specifically (the discovery stream is
    // a live Firestore query — `discoveryControllerProvider`, `lib/features/
    // meal/application/discovery_controller.dart` — that only starts once
    // `locationProvider`/`currentUserDocProvider` resolve, so the card can
    // arrive a beat after the marker above).
    final mealCard = find.byKey(Key('discovery_meal_card_$mealId'));
    await _pumpUntilFound(tester, mealCard);
    expect(
      mealCard,
      findsOneWidget,
      reason: 'seeded meal did not appear in the guest Discover feed',
    );

    await tester.tap(mealCard);
    await _settle(tester);

    final requestButton = find.byKey(
      const Key('meal_detail_request_to_join_button'),
    );
    await _pumpUntilFound(tester, requestButton);
    expect(
      requestButton,
      findsOneWidget,
      reason: 'meal detail did not render an enabled "Request to join"',
    );

    await tester.tap(requestButton);
    await _settle(tester);

    // Assert: the request doc exists and is pending (poll — the UI tap
    // above is not settled/awaited beyond a single frame, not a guarantee
    // the write has landed by the time this runs). A direct `get` by id
    // (`{mealId}_{guestId}` — `RequestRepositoryImpl._requestId`): an
    // unconstrained `where('mealId', ...)` list query is denied by the
    // `requests` list rule, which requires the query itself to pin
    // `guestId`/`hostId` to the caller.
    final requestId = '${mealId}_${guest.uid}';
    final reqDoc = await pollUntil(() async {
      final snap = await _db.collection('requests').doc(requestId).get();
      return snap.exists ? snap : null;
    });
    expect(reqDoc.data()!['status'], 'pending');

    await signOutTestUser();

    // Arrange: a SECOND guest also has a pending request on this meal, so
    // the approve below must deny it in its post-commit sibling query
    // (`RequestRepositoryImpl.approve`) — which has to pass the `requests`
    // list rule under enforcement (it's `hostId`-constrained for exactly
    // that reason). Seeded via the SDK as that guest, so the create rule
    // is enforced too.
    final rival = await signInTestUser(uid: 'guest-2');
    await seedUserProfile(uid: rival.uid);
    final rivalRequestId = await seedPendingRequest(
      mealId: mealId,
      guestId: rival.uid,
      hostId: host.uid,
    );
    await signOutTestUser();

    // Act (host): sign back in as the host and drive the real Requests-
    // inbox UI to approve.
    await signInTestUser(uid: host.uid);

    await _pumpUntilFound(tester, discoverMarker);
    expect(
      discoverMarker,
      findsOneWidget,
      reason: 'host session did not land on the authed Discover feed',
    );

    // Bottom-nav "Requests" tab (`app_shell.dart` — a `NavigationDestination`
    // labelled "Requests"; no dedicated `Key`, but the label is unique in
    // the tree).
    final requestsTab = find.text('Requests');
    expect(requestsTab, findsOneWidget);
    await tester.tap(requestsTab);
    await _settle(tester);

    final approveButton = find.byKey(
      Key('request_inbox_approve_button_$requestId'),
    );
    await _pumpUntilFound(tester, approveButton);
    expect(
      approveButton,
      findsOneWidget,
      reason: "host inbox did not render the guest's pending request",
    );

    await tester.tap(approveButton);
    await _settle(tester);

    // Assert: the approve transaction's effects. This is a CLIENT-SIDE
    // Firestore transaction (`RequestRepositoryImpl.approve`), not a Cloud
    // Function, so `pollUntil` here is absorbing UI/async timing (the tap
    // above vs. this read), not waiting on a Function trigger.
    final match = await pollUntil(() async {
      final m = await _db.collection('matches').doc(mealId).get();
      return m.exists ? m : null;
    });
    final participants = match.data()!['participants'] as List<Object?>;
    expect(participants, containsAll([host.uid, guest.uid]));

    final meal = await _db.collection('meals').doc(mealId).get();
    expect(meal.data()!['status'], 'matched');
    expect(meal.data()!['guestId'], guest.uid);

    final approved = await _db.collection('requests').doc(requestId).get();
    expect(approved.data()!['status'], 'approved');

    // The post-commit sibling batch runs after the transaction, so poll.
    final rivalRequest = await pollUntil(() async {
      final r = await _db.collection('requests').doc(rivalRequestId).get();
      return r.data()?['status'] == 'denied' ? r : null;
    });
    expect(rivalRequest.data()!['status'], 'denied');

    // Any non-image error would have been recorded by the binding here.
    expect(tester.takeException(), isNull);
  });
}
