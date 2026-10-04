/// Regression lock for the emulator-open-rules gap: proves the Firestore
/// emulator loads and ENFORCES `firebase/firestore.rules` for the `(default)`
/// database rather than silently running open. If the emulator invocation
/// regresses to unqualified `--only firestore` (see `Makefile`'s `e2e`
/// target comment), firebase-tools' `getFirestoreConfig()` sees both
/// `firebase.json` `firestore` array entries ((default) + stage), the
/// Firestore emulator bails with "does not support multiple databases yet"
/// and starts with OPEN rules, and the forbidden write below would silently
/// SUCCEED instead of throwing — failing this test. Run via `make e2e` (see
/// `Makefile`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Boots the app (which initializes Firebase + wires the emulators) only if
/// no earlier test in this file already did: a second `bootstrap` would
/// re-call `useFirestoreEmulator` on an already-started Firestore instance,
/// which throws. Keeps each test runnable on its own (`--plain-name`) too.
Future<void> _bootOnce(WidgetTester tester) async {
  if (Firebase.apps.isEmpty) await pumpApp(tester);
}

/// The host + guest + other-user + open-meal + pending-request fixture of the
/// `matches create — approval integrity` group (see `buildWorld` there).
typedef _MatchWorld = ({
  String hostClaim,
  String otherClaim,
  String guestClaim,
  String mealId,
  String reqId,
  String hostUid,
  String guestUid,
  String otherUid,
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // NOTE: tests below that need a pre-existing `matches` doc seed it through
  // `adminSetDoc` (rules bypassed): the `matches` create rule only admits the
  // real approve transaction, which the match-integrity group at the bottom
  // exercises through the SDK.

  setUp(clearEmulators);

  testWidgets(
    'firestore.rules denies a meals/ create with a forged hostId',
    (tester) async {
      // Act: boot the app against the emulators (wires the Firestore SDK to
      // the emulator — see `pumpApp`) and sign in a test user, same
      // preconditions as `smoke_test.dart`.
      await _bootOnce(tester);
      final user = await signInTestUser(uid: 'rules-deny-1');

      // `firebase/firestore.rules` `match /meals/{mealId}` create requires
      // `request.resource.data.hostId == request.auth.uid`. `hostId` below
      // is deliberately a DIFFERENT uid than the signed-in user, so this
      // write is unambiguously denied under enforced rules regardless of
      // any other field — and would silently succeed if the emulator were
      // running open.
      Future<void> forbiddenWrite() => _db.collection('meals').doc().set({
            'hostId': '${user.uid}-not-me',
            'status': 'open',
            'geohash': 'u09',
            'dateTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 3)),
            ),
          });

      // Assert: the write is rejected with `permission-denied` — proof the
      // emulator is enforcing `firebase/firestore.rules`, not running open.
      await expectLater(
        forbiddenWrite,
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  // `requests/{requestId}` get rule (firebase/firestore.rules): a guest may
  // read their OWN not-yet-created request (id `{mealId}_{guestId}` — see
  // `RequestRepositoryImpl._requestId`) so the meal-detail "Request to join"
  // listener resolves to "no request yet" instead of hanging on
  // PERMISSION_DENIED; the null case is scoped to the caller's own id so it
  // is not an existence oracle for anyone else's request.
  testWidgets(
    'a guest can get their own not-yet-created request (resolves '
    'not-exists, no error)',
    (tester) async {
      await _bootOnce(tester);
      final guest = await signInTestUser(uid: 'rules-own-request-1');

      final snap = await _db
          .collection('requests')
          .doc('some-meal_${guest.uid}')
          .get(const GetOptions(source: Source.server));

      expect(snap.exists, isFalse);
    },
  );

  testWidgets(
    "getting someone else's not-yet-created request is permission-denied "
    '(no existence oracle)',
    (tester) async {
      await _bootOnce(tester);
      final user = await signInTestUser(uid: 'rules-other-request-1');

      Future<void> probeOther() => _db
          .collection('requests')
          .doc('some-meal_${user.uid}-not-me')
          .get(const GetOptions(source: Source.server));

      await expectLater(
        probeOther,
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  // `matches/{matchId}` read rule (`firebase/firestore.rules`): split into
  // `get`/`list` so the Chats tab's `arrayContains('participants', uid)` +
  // `orderBy('createdAt')` query — which only the `list` rule's
  // `participants`-pinned condition can prove — succeeds, while a `get` by
  // a non-participant still denies.
  testWidgets(
    "a match participant's list query "
    '(participants array-contains + orderBy createdAt) succeeds',
    (tester) async {
      await _bootOnce(tester);
      final host = await signInTestUser(uid: 'rules-match-list-host');
      const matchId = 'rules-match-list-match-1';
      const otherUid = 'rules-match-list-guest';
      await adminSetDoc('matches', matchId, {
        'id': matchId,
        'mealId': matchId,
        'hostId': host.uid,
        'guestId': otherUid,
        'participants': [host.uid, otherUid],
        'createdAt': DateTime.now(),
      });

      final snap = await _db
          .collection('matches')
          .where('participants', arrayContains: host.uid)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));

      expect(snap.docs.map((d) => d.id), contains(matchId));
    },
  );

  testWidgets(
    "a non-participant's get on someone else's match is permission-denied",
    (tester) async {
      await _bootOnce(tester);
      final host = await signInTestUser(uid: 'rules-match-get-host');
      const matchId = 'rules-match-get-match-1';
      await adminSetDoc('matches', matchId, {
        'id': matchId,
        'mealId': matchId,
        'hostId': host.uid,
        'guestId': 'rules-match-get-guest',
        'participants': [host.uid, 'rules-match-get-guest'],
        'createdAt': DateTime.now(),
      });

      await signInTestUser(uid: 'rules-match-get-outsider');
      Future<void> probeOther() => _db
          .collection('matches')
          .doc(matchId)
          .get(const GetOptions(source: Source.server));

      await expectLater(
        probeOther,
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  // `ratings/{ratingId}` read rule: same get/list split shape as `requests`
  // (`c133e20`) and `matches` above — id is `{matchId}_{raterUid}`
  // (`RatingRepositoryImpl`), so a rater's own not-yet-created rating
  // resolves to "not rated yet" instead of hanging a listener on
  // PERMISSION_DENIED, narrowed to the caller's own id suffix.
  testWidgets(
    'a user can get their own not-yet-created rating (resolves '
    'not-exists, no error)',
    (tester) async {
      await _bootOnce(tester);
      final user = await signInTestUser(uid: 'rules-own-rating-1');

      final snap = await _db
          .collection('ratings')
          .doc('some-match_${user.uid}')
          .get(const GetOptions(source: Source.server));

      expect(snap.exists, isFalse);
    },
  );

  testWidgets(
    "getting someone else's not-yet-created rating is permission-denied "
    '(no existence oracle)',
    (tester) async {
      await _bootOnce(tester);
      final user = await signInTestUser(uid: 'rules-other-rating-1');

      Future<void> probeOther() => _db
          .collection('ratings')
          .doc('some-match_${user.uid}-not-me')
          .get(const GetOptions(source: Source.server));

      await expectLater(
        probeOther,
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  // `ratings/{ratingId}` create rule's `comment` clause: only special-cases
  // the KEY being absent, then requires a string `<= 200` chars once it IS
  // present. A present `comment: null` value used to throw a rule-evaluation
  // error on `.size()` and deny the whole create — the fix adds an explicit
  // `== null` arm and an `is string` guard before `.size()`. Each case here
  // seeds its own match (via a helper) as the host, then creates the rating
  // as that same host rating the guest — the only thing under test is the
  // `comment` clause, so every other field is a known-good baseline. Uses
  // the REAL emulator-assigned uids (`host.uid`) throughout, not the string
  // passed to `signInTestUser` — the Auth emulator mints its own random uid
  // per identity, it does NOT echo the claimed `sub` back as the Firebase
  // uid (confirmed via a REST probe in this task; see the task report).
  Future<({String matchId, String hostUid, String guestUid})> seedRatingMatch(
    WidgetTester tester,
    String suffix,
  ) async {
    await _bootOnce(tester);
    final host = await signInTestUser(uid: 'rules-rating-comment-host-$suffix');
    final matchId = 'rules-rating-comment-match-$suffix';
    const guestUid = 'rules-rating-comment-guest-not-a-real-uid';
    await adminSetDoc('matches', matchId, {
      'id': matchId,
      'mealId': matchId,
      'hostId': host.uid,
      'guestId': guestUid,
      'participants': [host.uid, guestUid],
      'createdAt': DateTime.now(),
    });
    return (matchId: matchId, hostUid: host.uid, guestUid: guestUid);
  }

  Future<void> createRating({
    required String matchId,
    required String raterUid,
    required String targetUid,
    Object? comment,
    bool includeCommentKey = true,
  }) {
    final data = <String, Object?>{
      'matchId': matchId,
      'raterUid': raterUid,
      'targetUid': targetUid,
      'stars': 5,
      'showedUp': true,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (includeCommentKey) data['comment'] = comment;
    return _db.collection('ratings').doc('${matchId}_$raterUid').set(data);
  }

  testWidgets(
    'a valid participant rating with no comment key is allowed',
    (tester) async {
      final seed = await seedRatingMatch(tester, 'no-key');
      await createRating(
        matchId: seed.matchId,
        raterUid: seed.hostUid,
        targetUid: seed.guestUid,
        includeCommentKey: false,
      );
      final snap = await _db
          .collection('ratings')
          .doc('${seed.matchId}_${seed.hostUid}')
          .get(const GetOptions(source: Source.server));
      expect(snap.exists, isTrue);
    },
  );

  testWidgets(
    'a valid participant rating with comment: null is allowed',
    (tester) async {
      final seed = await seedRatingMatch(tester, 'null');
      // `comment` defaults to `null`; not passed explicitly (redundant-arg
      // lint) — `includeCommentKey` (true by default) still writes the KEY
      // with that null value, which is exactly the case under test.
      await createRating(
        matchId: seed.matchId,
        raterUid: seed.hostUid,
        targetUid: seed.guestUid,
      );
      final snap = await _db
          .collection('ratings')
          .doc('${seed.matchId}_${seed.hostUid}')
          .get(const GetOptions(source: Source.server));
      expect(snap.exists, isTrue);
    },
  );

  testWidgets(
    'a valid participant rating with a 200-char comment is allowed',
    (tester) async {
      final seed = await seedRatingMatch(tester, '200');
      await createRating(
        matchId: seed.matchId,
        raterUid: seed.hostUid,
        targetUid: seed.guestUid,
        comment: 'a' * 200,
      );
      final snap = await _db
          .collection('ratings')
          .doc('${seed.matchId}_${seed.hostUid}')
          .get(const GetOptions(source: Source.server));
      expect(snap.exists, isTrue);
    },
  );

  testWidgets(
    'a rating with a 201-char comment is permission-denied',
    (tester) async {
      final seed = await seedRatingMatch(tester, '201');
      await expectLater(
        createRating(
          matchId: seed.matchId,
          raterUid: seed.hostUid,
          targetUid: seed.guestUid,
          comment: 'a' * 201,
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  testWidgets(
    'a rating with a non-string comment is permission-denied',
    (tester) async {
      final seed = await seedRatingMatch(tester, 'non-string');
      await expectLater(
        createRating(
          matchId: seed.matchId,
          raterUid: seed.hostUid,
          targetUid: seed.guestUid,
          comment: <String>['x'],
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );

  // ---- Doc-id pinning on create (`ratings` / `requests` / `blocks`) ----
  // Each create rule requires the doc id to be the caller's canonical id
  // (`{matchId}_{uid}`, `{mealId}_{uid}`, `{uid}_{blockedUid}`), the id the
  // app writes. Every case below is signed in as a valid participant with a
  // valid body; the ONLY varying thing is the doc id. All uids are the real
  // emulator-minted `.uid`s, not the literals passed to `signInTestUser`.
  Matcher permissionDenied() => throwsA(
    isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied'),
  );

  Future<void> setRating(String docId, String matchId, String me, String to) =>
      _db.collection('ratings').doc(docId).set({
        'matchId': matchId,
        'raterUid': me,
        'targetUid': to,
        'stars': 5,
        'showedUp': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

  testWidgets('ratings create: canonical {matchId}_{uid} is allowed', (
    tester,
  ) async {
    final seed = await seedRatingMatch(tester, 'pin-ok');
    await setRating(
      '${seed.matchId}_${seed.hostUid}',
      seed.matchId,
      seed.hostUid,
      seed.guestUid,
    );
  });

  testWidgets(
    'ratings create: an arbitrary id (rating stuffing) is permission-denied',
    (tester) async {
      final seed = await seedRatingMatch(tester, 'pin-stuff');
      await expectLater(
        setRating(
          '${seed.matchId}_stuffing1',
          seed.matchId,
          seed.hostUid,
          seed.guestUid,
        ),
        permissionDenied(),
      );
    },
  );

  testWidgets(
    "ratings create: squatting another user's id is permission-denied",
    (tester) async {
      await _bootOnce(tester);
      final victim = await signInTestUser(uid: 'rules-pin-rating-victim');
      final seed = await seedRatingMatch(tester, 'pin-squat');
      await expectLater(
        setRating(
          '${seed.matchId}_${victim.uid}',
          seed.matchId,
          seed.hostUid,
          seed.guestUid,
        ),
        permissionDenied(),
      );
    },
  );

  // Signs in a host, seeds an OPEN meal as them, then signs in the guest.
  // Returns the real uids and the meal id.
  Future<({String mealId, String hostUid, String guestUid})> seedOpenMealFor(
    WidgetTester tester,
    String suffix,
  ) async {
    await _bootOnce(tester);
    final host = await signInTestUser(uid: 'rules-pin-req-host-$suffix');
    final mealId = await seedOpenMeal(hostId: host.uid);
    final guest = await signInTestUser(uid: 'rules-pin-req-guest-$suffix');
    return (mealId: mealId, hostUid: host.uid, guestUid: guest.uid);
  }

  Future<void> setRequest(
    String docId,
    String mealId,
    String guestUid,
    String hostUid,
  ) => _db.collection('requests').doc(docId).set({
    'id': docId,
    'mealId': mealId,
    'guestId': guestUid,
    'hostId': hostUid,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  });

  testWidgets('requests create: canonical {mealId}_{uid} is allowed', (
    tester,
  ) async {
    final s = await seedOpenMealFor(tester, 'ok');
    await setRequest(
      '${s.mealId}_${s.guestUid}',
      s.mealId,
      s.guestUid,
      s.hostUid,
    );
  });

  testWidgets('requests create: an arbitrary id is permission-denied', (
    tester,
  ) async {
    final s = await seedOpenMealFor(tester, 'arb');
    await expectLater(
      setRequest('${s.mealId}_stuffing1', s.mealId, s.guestUid, s.hostUid),
      permissionDenied(),
    );
  });

  testWidgets(
    "requests create: squatting another user's id is permission-denied",
    (tester) async {
      await _bootOnce(tester);
      final victim = await signInTestUser(uid: 'rules-pin-req-victim');
      final s = await seedOpenMealFor(tester, 'squat');
      await expectLater(
        setRequest(
          '${s.mealId}_${victim.uid}',
          s.mealId,
          s.guestUid,
          s.hostUid,
        ),
        permissionDenied(),
      );
    },
  );

  Future<void> setBlock(String docId, String me, String blocked) =>
      _db.collection('blocks').doc(docId).set({
        'id': docId,
        'blockerUid': me,
        'blockedUid': blocked,
        'pair': [me, blocked],
        'createdAt': FieldValue.serverTimestamp(),
      });

  testWidgets('blocks create: canonical {me}_{other} is allowed', (
    tester,
  ) async {
    await _bootOnce(tester);
    final me = await signInTestUser(uid: 'rules-pin-block-me');
    await setBlock('${me.uid}_some-other-user', me.uid, 'some-other-user');
  });

  testWidgets(
    'blocks create: a stranger-to-stranger id with blockerUid = me is '
    'permission-denied',
    (tester) async {
      await _bootOnce(tester);
      final stranger1 = await signInTestUser(uid: 'rules-pin-block-s1');
      final stranger2 = await signInTestUser(uid: 'rules-pin-block-s2');
      final me = await signInTestUser(uid: 'rules-pin-block-me2');
      await expectLater(
        setBlock('${stranger1.uid}_${stranger2.uid}', me.uid, stranger2.uid),
        permissionDenied(),
      );
    },
  );

  // ---- `matches` create — approval integrity ----
  // The `matches` create rule (`matchApprovalValid`) only admits the REAL
  // approve transaction: request pending -> approved, meal open -> matched
  // with that guest, same id/participants shape, no block. Test 1 is shaped
  // exactly like `RequestRepositoryImpl.approve`; every denial case varies one
  // property of it. All uids are the real emulator-minted `.uid`s.
  group('matches create — approval integrity', () {
    // host: profile + open meal. guest: profile + pending request. `other`: a
    // third user (optionally with their own pending request on the same meal).
    // Returns signed in as the HOST again (uid equality asserted).
    Future<_MatchWorld> buildWorld(
      WidgetTester tester,
      String suffix, {
      bool guestRequests = true,
      bool otherRequests = false,
    }) async {
      await _bootOnce(tester);
      final hostClaim = 'mi-host-$suffix';
      final guestClaim = 'mi-guest-$suffix';
      final otherClaim = 'mi-other-$suffix';
      final host = await signInTestUser(uid: hostClaim);
      await seedUserProfile(uid: host.uid);
      final mealId = await seedOpenMeal(hostId: host.uid);
      final guest = await signInTestUser(uid: guestClaim);
      await seedUserProfile(uid: guest.uid);
      final reqId = guestRequests
          ? await seedPendingRequest(
              mealId: mealId,
              guestId: guest.uid,
              hostId: host.uid,
            )
          : '${mealId}_${guest.uid}';
      final other = await signInTestUser(uid: otherClaim);
      await seedUserProfile(uid: other.uid);
      if (otherRequests) {
        await seedPendingRequest(
          mealId: mealId,
          guestId: other.uid,
          hostId: host.uid,
        );
      }
      final hostAgain = await signInTestUser(uid: hostClaim);
      expect(hostAgain.uid, host.uid, reason: 'same claim -> same Auth user');
      return (
        hostClaim: hostClaim,
        otherClaim: otherClaim,
        guestClaim: guestClaim,
        mealId: mealId,
        reqId: reqId,
        hostUid: host.uid,
        guestUid: guest.uid,
        otherUid: other.uid,
      );
    }

    // The app's approve transaction shape, with one knob per denial case.
    Future<void> approveTxn(
      _MatchWorld w, {
      bool updateMeal = true,
      bool updateRequest = true,
      String? mealGuestId,
      String mealStatus = 'matched',
      String? matchDocId,
      Map<String, Object?> matchOverrides = const {},
      Set<String> matchOmit = const {},
    }) {
      return _db.runTransaction((txn) async {
        if (updateMeal) {
          txn.update(_db.collection('meals').doc(w.mealId), {
            'status': mealStatus,
            'guestId': mealGuestId ?? w.guestUid,
          });
        }
        if (updateRequest) {
          txn.update(_db.collection('requests').doc(w.reqId), {
            'status': 'approved',
          });
        }
        final body = <String, Object?>{
          'id': w.mealId,
          'mealId': w.mealId,
          'hostId': w.hostUid,
          'guestId': w.guestUid,
          'participants': [w.hostUid, w.guestUid],
          'createdAt': FieldValue.serverTimestamp(),
          ...matchOverrides,
        }..removeWhere((k, _) => matchOmit.contains(k));
        txn.set(_db.collection('matches').doc(matchDocId ?? w.mealId), body);
      });
    }

    // A request doc in a pre-state the rules forbid a client to reach.
    Future<void> forceRequestStatus(
      _MatchWorld w,
      String status,
    ) => adminSetDoc('requests', w.reqId, {
      'id': w.reqId,
      'mealId': w.mealId,
      'guestId': w.guestUid,
      'hostId': w.hostUid,
      'status': status,
      'createdAt': DateTime.now(),
    });

    testWidgets('1. the real approve transaction shape is allowed', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't1');
      await approveTxn(w);

      final match = await _db
          .collection('matches')
          .doc(w.mealId)
          .get(const GetOptions(source: Source.server));
      expect(match.exists, isTrue);
      expect(match.data()!['guestId'], w.guestUid);
      final meal = await _db.collection('meals').doc(w.mealId).get();
      expect(meal.data()!['status'], 'matched');
      expect(meal.data()!['guestId'], w.guestUid);
      final req = await _db.collection('requests').doc(w.reqId).get();
      expect(req.data()!['status'], 'approved');
    });

    testWidgets('2. a match with no request at all is denied', (tester) async {
      final w = await buildWorld(tester, 't2', guestRequests: false);
      await expectLater(
        approveTxn(w, updateRequest: false),
        permissionDenied(),
      );
    });

    testWidgets(
      '3. a request that the transaction does not approve is denied',
      (tester) async {
        final w = await buildWorld(tester, 't3');
        await expectLater(
          approveTxn(w, updateRequest: false),
          permissionDenied(),
        );
      },
    );

    // Cases 3b/3b2/3c isolate the `mealAfter` clauses: in each, the request goes
    // pending -> approved, the match body is fully valid, and the meal was
    // open and hosted by the caller, so ONLY the meal's after-state is wrong.
    testWidgets(
      '3b. a transaction that leaves the meal open (not matched) is denied',
      (tester) async {
        final w = await buildWorld(tester, 't3b');
        await expectLater(approveTxn(w, updateMeal: false), permissionDenied());
      },
    );

    testWidgets(
      '3b2. a meal given the guest but left open (status not matched) is '
      'denied',
      (tester) async {
        final w = await buildWorld(tester, 't3b2');
        // Meal keeps status `open` but gets the right guestId, so ONLY
        // `mealAfter.status == 'matched'` can deny.
        await expectLater(
          approveTxn(w, mealStatus: 'open'),
          permissionDenied(),
        );
      },
    );

    testWidgets(
      '3c. a meal matched with a different guest than the match names is '
      'denied',
      (tester) async {
        final w = await buildWorld(tester, 't3c');
        // Meal -> matched with `other` (legal for the host by the meals
        // update rule); request -> approved and the match both name `guest`.
        await expectLater(
          approveTxn(w, mealGuestId: w.otherUid),
          permissionDenied(),
        );
      },
    );

    testWidgets('4a. an already-approved request is denied', (tester) async {
      final w = await buildWorld(tester, 't4a');
      await forceRequestStatus(w, 'approved');
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets('4b. an already-denied request is denied', (tester) async {
      final w = await buildWorld(tester, 't4b');
      await forceRequestStatus(w, 'denied');
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets('5. a meal that is already matched is denied', (tester) async {
      final w = await buildWorld(tester, 't5');
      // Pre-state the meals update rule forbids a client to reach (matched
      // without an approve transaction): seeded through the admin REST write.
      await adminUpdateDoc('meals', w.mealId, {
        'status': 'matched',
        'guestId': w.otherUid,
      });
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets(
      "6. a match on another host's meal (their pending request) is denied",
      (tester) async {
        final w = await buildWorld(tester, 't6');
        // Host B (`other`) forges a match on host A's meal for A's guest. B
        // cannot write A's meal/request (host-only update rules), so this is
        // a single match write. It is denied, but ALSO by `reqAfter.status ==
        // 'approved'` (the request stays pending), so this case does not
        // isolate the `reqBefore.hostId` / `mealBefore.hostId` clauses: those
        // are belt-and-braces alongside the host-only update rules on
        // meals/requests.
        final b = await signInTestUser(uid: w.otherClaim);
        expect(b.uid, w.otherUid);
        await expectLater(
          _db.collection('matches').doc(w.mealId).set({
            'id': w.mealId,
            'mealId': w.mealId,
            'hostId': b.uid,
            'guestId': w.guestUid,
            'participants': [b.uid, w.guestUid],
            'createdAt': FieldValue.serverTimestamp(),
          }),
          permissionDenied(),
        );
      },
    );

    testWidgets(
      "7. a match whose guestId is not the approved request's guest is denied",
      (tester) async {
        final w = await buildWorld(tester, 't7', otherRequests: true);
        // Approves the guest's request + meal.guestId = guest, but the match
        // names `other` (who has their own, still-pending request).
        await expectLater(
          approveTxn(
            w,
            matchOverrides: {
              'guestId': w.otherUid,
              'participants': [w.hostUid, w.otherUid],
            },
          ),
          permissionDenied(),
        );
      },
    );

    testWidgets(
      '8. participants that disagree with host/guest, or guestId == hostId, '
      'are denied',
      (tester) async {
        final w = await buildWorld(tester, 't8');
        // Denied transactions write nothing, so one world serves all three.
        await expectLater(
          approveTxn(
            w,
            matchOverrides: {
              'participants': [w.guestUid, w.hostUid], // wrong order
            },
          ),
          permissionDenied(),
        );
        await expectLater(
          approveTxn(
            w,
            matchOverrides: {
              'participants': [w.hostUid, w.guestUid, w.otherUid], // extra
            },
          ),
          permissionDenied(),
        );
        await expectLater(
          approveTxn(
            w,
            matchOverrides: {
              'guestId': w.hostUid, // self-match
              'participants': [w.hostUid, w.hostUid],
            },
          ),
          permissionDenied(),
        );
      },
    );

    testWidgets('9. a match id that is not the meal id is denied', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't9');
      await expectLater(
        approveTxn(w, matchDocId: 'arbitrary-match-id'),
        permissionDenied(),
      );
    });

    // Cases 9b/9c: the doc id IS the real meal id (genuine pending request,
    // open meal, valid world), so `matchApprovalValid` passes; ONLY one body
    // field disagrees with the doc id.
    testWidgets('9b. a match body mealId that is not the doc id is denied', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't9b');
      await expectLater(
        approveTxn(w, matchOverrides: {'mealId': 'not-the-meal-id'}),
        permissionDenied(),
      );
    });

    testWidgets('9c. a match body id that is not the doc id is denied', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't9c');
      await expectLater(
        approveTxn(w, matchOverrides: {'id': 'not-the-meal-id'}),
        permissionDenied(),
      );
    });

    // Case 11: the approving host (caller) is genuine, with a genuine pending
    // request, but the match body names a third uid as host. Every other
    // clause holds (matchApprovalValid keys off the caller), so ONLY
    // `hostId == request.auth.uid` can deny.
    testWidgets('11. a match whose hostId is not the caller is denied', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't11');
      await expectLater(
        approveTxn(
          w,
          matchOverrides: {
            'hostId': w.otherUid,
            'participants': [w.otherUid, w.guestUid],
          },
        ),
        permissionDenied(),
      );
    });

    // Cases 12a-12d: payload pinning. A hostile approving host must not be
    // able to store a `createdAt` that breaks the guest's Chats list parse, or
    // extra keys. Everything else is the valid approve world.
    testWidgets('12a. a string createdAt is denied', (tester) async {
      final w = await buildWorld(tester, 't12a');
      await expectLater(
        approveTxn(w, matchOverrides: {'createdAt': 'zzz'}),
        permissionDenied(),
      );
    });

    testWidgets('12b. a missing createdAt is denied', (tester) async {
      final w = await buildWorld(tester, 't12b');
      await expectLater(
        approveTxn(w, matchOmit: {'createdAt'}),
        permissionDenied(),
      );
    });

    testWidgets('12c. an extra key on the match is denied', (tester) async {
      final w = await buildWorld(tester, 't12c');
      await expectLater(
        approveTxn(w, matchOverrides: {'extra': 'junk'}),
        permissionDenied(),
      );
    });

    testWidgets('12d. a client timestamp that is not the server time is denied',
        (tester) async {
      final w = await buildWorld(tester, 't12d');
      await expectLater(
        approveTxn(
          w,
          matchOverrides: {
            'createdAt': Timestamp.fromDate(DateTime(2001)),
          },
        ),
        permissionDenied(),
      );
    });

    testWidgets('10a. a block (host blocked guest) between them is denied', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't10a');
      await setBlock('${w.hostUid}_${w.guestUid}', w.hostUid, w.guestUid);
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets('10b. a block (guest blocked host) between them is denied', (
      tester,
    ) async {
      final w = await buildWorld(tester, 't10b');
      final g = await signInTestUser(uid: w.guestClaim);
      expect(g.uid, w.guestUid);
      await setBlock('${w.guestUid}_${w.hostUid}', w.guestUid, w.hostUid);
      final h = await signInTestUser(uid: w.hostClaim);
      expect(h.uid, w.hostUid);
      await expectLater(approveTxn(w), permissionDenied());
    });
  });
}
