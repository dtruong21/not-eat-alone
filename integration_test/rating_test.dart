/// Scenario 4 — rating: both parties rate each other after a past-dated
/// meal via the real Chats-tab -> chat -> post-meal card -> rating sheet UI,
/// and `onRatingCreated` (`firebase/functions/src/triggers/rating_created.ts`)
/// is exercised live on BOTH directions: it aggregates each rating onto the
/// TARGET user's `users/{uid}` doc (`ratingSum`/`ratingCount`/`ratingAvg`)
/// and marks each rating doc `aggregated: true` (idempotency guard). The
/// host's rating includes a comment; the guest's does not (the sheet's own
/// default), exercising the `ratings` create rule's `comment` clause fix
/// (a present `comment: null` used to be denied — see the fix commit). A
/// final negative case asserts a non-participant's direct-SDK rating create
/// is denied by `ratingParticipantsValid` (`firebase/firestore.rules`). Run
/// via `make e2e` (see `Makefile`).
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
/// See `chat_test.dart`'s copy of this helper for the full rationale
/// (`seedUserProfile`'s `photoUrls` entry 404s on every `NetworkImage`
/// avatar this scenario's screens render).
void _suppressExpectedImageErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// A hand-rolled, bounded `pumpAndSettle` — see `chat_test.dart`'s copy for
/// why the unbounded default must never be used here.
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
/// then does a short, best-effort [_settle]. See `chat_test.dart`.
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
/// Used to assert the post-meal card/rate button stops offering a rating
/// once `myRatingProvider` resolves the just-submitted rating.
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Navigates from the authed Discover feed to the seeded match's chat via
/// the real Chats-tab UI, then submits a [stars]-star rating of the other
/// participant through the real post-meal card -> rating sheet UI. Returns
/// once the sheet has closed (submit succeeded or the sheet is gone).
Future<void> _rateThroughUi(
  WidgetTester tester, {
  required String matchId,
  required int stars,
  String? comment,
}) async {
  final discoverMarker = find.byKey(
    const Key('discovery_create_meal_button'),
  );
  await _pumpUntilFound(tester, discoverMarker);
  expect(
    discoverMarker,
    findsOneWidget,
    reason: 'session did not land on the authed Discover feed',
  );

  final chatsTab = find.text('Chats');
  expect(chatsTab, findsOneWidget);
  await tester.tap(chatsTab);
  await _settle(tester);

  final chatTile = find.byKey(Key('chat_list_tile_$matchId'));
  await _pumpUntilFound(tester, chatTile);
  expect(
    chatTile,
    findsOneWidget,
    reason: 'Chats tab did not render the seeded match',
  );

  await tester.tap(chatTile);
  await _settle(tester);

  final rateButton = find.byKey(const Key('post_meal_card_rate_button'));
  await _pumpUntilFound(tester, rateButton);
  expect(
    rateButton,
    findsOneWidget,
    reason: 'post-meal card did not offer a rating for this past meal',
  );

  await tester.tap(rateButton);
  await _settle(tester);

  final starButton = find.byKey(Key('rating_star_$stars'));
  await _pumpUntilFound(tester, starButton);
  expect(starButton, findsOneWidget);
  await tester.tap(starButton);
  await _settle(tester);

  if (comment != null) {
    final commentField = find.byKey(const Key('rating_comment_field'));
    expect(commentField, findsOneWidget);
    await tester.enterText(commentField, comment);
    await _settle(tester);
  }

  final submitButton = find.byKey(const Key('rating_submit_button'));
  expect(submitButton, findsOneWidget);
  await tester.tap(submitButton);
  await _settle(tester);

  // The sheet's own submit handler pops it on success — wait for that pop
  // before returning, so callers see the settled post-submit tree.
  await _pumpUntilGone(tester, submitButton);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets(
      'rating a match updates the target aggregate via onRatingCreated',
      (tester) async {
    _suppressExpectedImageErrors();
    await pumpApp(tester);

    // Arrange: host + guest profiles (rating fields start at 0 — see
    // `seedUserProfile`), then a matched meal DATED IN THE PAST so
    // `PostMealCard` (`lib/features/rating/presentation/widgets/
    // post_meal_card.dart`) shows: it self-hides unless
    // `meal.dateTime.isBefore(DateTime.now())` AND the caller hasn't already
    // rated this match (`myRatingProvider` resolves `null`). `seedMatch`
    // must run while signed in as the host (`matches` create requires
    // `hostId == auth.uid`); its `dateTime` param threads through to the
    // underlying `seedOpenMeal`.
    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final guest = await signInTestUser(uid: 'guest-1');
    await seedUserProfile(uid: guest.uid);
    await signInTestUser(uid: host.uid);
    final matchId = await seedMatch(
      hostId: host.uid,
      guestId: guest.uid,
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
    );

    // Act (host): rate the guest 5 stars, showedUp stays the sheet's
    // default `true` (per the brief), through the real UI.
    await _rateThroughUi(
      tester,
      matchId: matchId,
      stars: 5,
      comment: 'Great meal!',
    );

    // Assert: the rating doc exists (own-doc `get`, exercising the fixed
    // `ratings` get-rule) with the stars submitted through the UI.
    final ratingDocId = '${matchId}_${host.uid}';
    final ratingDoc = await pollUntil(() async {
      final r = await _db.collection('ratings').doc(ratingDocId).get();
      return r.exists ? r : null;
    });
    expect(ratingDoc.data()!['stars'], 5);
    expect(ratingDoc.data()!['showedUp'], true);
    expect(ratingDoc.data()!['raterUid'], host.uid);
    expect(ratingDoc.data()!['targetUid'], guest.uid);

    // Assert: the post-meal card no longer offers a rating for this match —
    // `myRatingProvider`'s `watchMyRating` resolved the just-created rating,
    // which exercises the fixed `ratings` get-rule's "own doc, exists" arm
    // via a live snapshot listener (not the `get` above).
    expect(
      find.byKey(const Key('post_meal_card_rate_button')),
      findsNothing,
      reason: 'post-meal card should hide once the caller has rated',
    );

    // Function under test: poll `users/{guestUid}` until `onRatingCreated`
    // has applied the aggregate. The emulator dispatches Firestore triggers
    // asynchronously, so this can take a few seconds after the write above.
    final updatedGuest = await pollUntil(() async {
      final u = await _db.collection('users').doc(guest.uid).get();
      final count = (u.data()?['ratingCount'] as num?)?.toInt() ?? 0;
      return count == 1 ? u : null;
    }, timeout: const Duration(seconds: 20));
    expect((updatedGuest.data()!['ratingAvg'] as num).toDouble(), 5.0);
    expect(updatedGuest.data()!['ratingCount'], 1);
    expect((updatedGuest.data()!['ratingSum'] as num?)?.toInt(), 5);

    // Assert: the transaction's idempotency guard flagged the rating doc.
    final aggregatedRating =
        await _db.collection('ratings').doc(ratingDocId).get();
    expect(aggregatedRating.data()!['aggregated'], true);

    await signOutAndAwaitSignIn(tester);

    // Act (guest): rate the host 4 stars, WITHOUT a comment (the sheet's own
    // default) — exercises the fixed `ratings` create rule's `comment`
    // clause on the path that used to be denied (`comment: null` written by
    // `RatingRepositoryImpl.submit` is now omitted from the write entirely;
    // see `rating_dto.dart`'s `@JsonKey(includeIfNull: false)`).
    await signInTestUser(uid: guest.uid);
    await _rateThroughUi(tester, matchId: matchId, stars: 4);

    final guestRatingDoc = await pollUntil(() async {
      final r = await _db
          .collection('ratings')
          .doc('${matchId}_${guest.uid}')
          .get();
      return r.exists ? r : null;
    });
    expect(guestRatingDoc.data()!['stars'], 4);
    expect(guestRatingDoc.data()!['targetUid'], host.uid);
    expect(
      guestRatingDoc.data()!.containsKey('comment'),
      isFalse,
      reason: 'a no-comment rating should not write an explicit null field',
    );

    final updatedHost = await pollUntil(() async {
      final u = await _db.collection('users').doc(host.uid).get();
      final count = (u.data()?['ratingCount'] as num?)?.toInt() ?? 0;
      return count == 1 ? u : null;
    }, timeout: const Duration(seconds: 20));
    expect((updatedHost.data()!['ratingAvg'] as num).toDouble(), 4.0);
    expect(updatedHost.data()!['ratingCount'], 1);

    await signOutTestUser();

    // Negative (cheap, SDK): a third user — not a participant of this match
    // — cannot create a rating for it. `ratingParticipantsValid`
    // (`firebase/firestore.rules`) `get`s the match and requires the
    // rater/target pair to be exactly (host, guest) in either direction.
    final outsider = await signInTestUser(uid: 'outsider-1');
    await expectLater(
      _db.collection('ratings').doc('${matchId}_${outsider.uid}').set({
        'matchId': matchId,
        'raterUid': outsider.uid,
        'targetUid': guest.uid,
        'stars': 3,
        'showedUp': true,
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
