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
import 'package:not_eat_alone/features/meal/data/repositories/meal_repository_impl.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

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

/// The host + guest + other-user + open-meal + pending-request fixture shared
/// by the `matches create — approval integrity` and `meals — integrity` groups
/// (see `_buildWorld`).
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

// host: profile + open meal. guest: profile + pending request. `other`: a
// third user (optionally with their own pending request on the same meal).
// Returns signed in as the HOST again (uid equality asserted).
Future<_MatchWorld> _buildWorld(
  WidgetTester tester,
  String suffix, {
  bool guestRequests = true,
  bool otherRequests = false,
  String prefix = 'mi',
}) async {
  await _bootOnce(tester);
  final hostClaim = '$prefix-host-$suffix';
  final guestClaim = '$prefix-guest-$suffix';
  final otherClaim = '$prefix-other-$suffix';
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
  //
  // The `ratings` create rule also requires the meal to have happened
  // (`meals/{matchId}.dateTime <= request.time`), so the helper admin-seeds the
  // match's meal too: dated two hours ago by default, [mealDateTime] overrides
  // it, and [withMeal] false leaves the meal doc out entirely.
  Future<({String matchId, String hostUid, String guestUid})> seedRatingMatch(
    WidgetTester tester,
    String suffix, {
    DateTime? mealDateTime,
    bool withMeal = true,
  }) async {
    await _bootOnce(tester);
    final host = await signInTestUser(uid: 'rules-rating-comment-host-$suffix');
    final matchId = 'rules-rating-comment-match-$suffix';
    const guestUid = 'rules-rating-comment-guest-not-a-real-uid';
    if (withMeal) {
      await adminSetDoc('meals', matchId, {
        'hostId': host.uid,
        'guestId': guestUid,
        'status': 'matched',
        'geohash': 'u09',
        'dateTime':
            mealDateTime ?? DateTime.now().subtract(const Duration(hours: 2)),
        'womenOnly': false,
        'restaurant': {
          'placeId': 'seed-place-id',
          'name': 'Seed Restaurant',
          'address': '1 Test Street',
          'lat': 48.8566,
          'lng': 2.3522,
        },
      });
    }
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
    // The app's approve transaction shape, with one knob per denial case.
    Future<void> approveTxn(
      _MatchWorld w, {
      bool updateMeal = true,
      bool updateRequest = true,
      String? mealGuestId,
      bool approveOtherRequest = false,
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
        if (approveOtherRequest) {
          txn.update(
            _db.collection('requests').doc('${w.mealId}_${w.otherUid}'),
            {'status': 'approved'},
          );
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
      final w = await _buildWorld(tester, 't1');
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
      final w = await _buildWorld(tester, 't2', guestRequests: false);
      await expectLater(
        approveTxn(w, updateRequest: false),
        permissionDenied(),
      );
    });

    testWidgets(
      '3. a request that the transaction does not approve is denied',
      (tester) async {
        final w = await _buildWorld(tester, 't3');
        await expectLater(
          approveTxn(w, updateRequest: false),
          permissionDenied(),
        );
      },
    );

    // Cases 3b2/3c isolate the `mealAfter` clauses: in each, the request goes
    // pending -> approved, the match body is fully valid, and the meal was
    // open and hosted by the caller, so ONLY the meal's after-state is wrong.
    // (3b leaves the meal without a guestId at all, so `mealAfter.guestId`
    // errors too: it is a denial case, not an isolating one.)
    testWidgets(
      '3b. a transaction that leaves the meal open (not matched) is denied',
      (tester) async {
        final w = await _buildWorld(tester, 't3b');
        await expectLater(approveTxn(w, updateMeal: false), permissionDenied());
      },
    );

    testWidgets(
      '3b2. a meal given the guest but left open (status not matched) is '
      'denied',
      (tester) async {
        final w = await _buildWorld(tester, 't3b2');
        // Meal is admin-seeded `open` WITH the guest's id (so
        // `mealAfter.guestId == guestId` holds) and the transaction leaves it
        // alone (no `meals` write): ONLY `mealAfter.status == 'matched'` in
        // the `matches` rule can deny.
        await adminUpdateDoc('meals', w.mealId, {'guestId': w.guestUid});
        await expectLater(approveTxn(w, updateMeal: false), permissionDenied());
      },
    );

    testWidgets(
      '3c. a meal matched with a different guest than the match names is '
      'denied',
      (tester) async {
        final w = await _buildWorld(tester, 't3c', otherRequests: true);
        // Meal -> matched with `other`, whose own pending request is approved
        // in the same transaction (a genuine approve for `other`, so the
        // `meals` update rule admits it — a meal flip without a request is no
        // longer legal for the host). The guest's request is approved and the
        // match names `guest`, so ONLY `mealAfter.guestId == guestId` in the
        // `matches` rule can deny.
        await expectLater(
          approveTxn(
            w,
            mealGuestId: w.otherUid,
            approveOtherRequest: true,
          ),
          permissionDenied(),
        );
      },
    );

    testWidgets('4a. an already-approved request is denied', (tester) async {
      final w = await _buildWorld(tester, 't4a');
      await forceRequestStatus(w, 'approved');
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets('4b. an already-denied request is denied', (tester) async {
      final w = await _buildWorld(tester, 't4b');
      await forceRequestStatus(w, 'denied');
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets('5. a meal that is already matched is denied', (tester) async {
      final w = await _buildWorld(tester, 't5');
      // Pre-state the meals update rule forbids a client to reach (matched
      // without an approve transaction): seeded through the admin REST write,
      // already naming the guest. The transaction leaves the meal alone (a
      // meal write from `matched` is denied by the `meals` rule itself), so
      // ONLY `mealBefore.status == 'open'` in the `matches` rule can deny.
      await adminUpdateDoc('meals', w.mealId, {
        'status': 'matched',
        'guestId': w.guestUid,
      });
      await expectLater(approveTxn(w, updateMeal: false), permissionDenied());
    });

    testWidgets(
      "6. a match on another host's meal (their pending request) is denied",
      (tester) async {
        final w = await _buildWorld(tester, 't6');
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
        final w = await _buildWorld(tester, 't7', otherRequests: true);
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
        final w = await _buildWorld(tester, 't8');
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
      final w = await _buildWorld(tester, 't9');
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
      final w = await _buildWorld(tester, 't9b');
      await expectLater(
        approveTxn(w, matchOverrides: {'mealId': 'not-the-meal-id'}),
        permissionDenied(),
      );
    });

    testWidgets('9c. a match body id that is not the doc id is denied', (
      tester,
    ) async {
      final w = await _buildWorld(tester, 't9c');
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
      final w = await _buildWorld(tester, 't11');
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
      final w = await _buildWorld(tester, 't12a');
      await expectLater(
        approveTxn(w, matchOverrides: {'createdAt': 'zzz'}),
        permissionDenied(),
      );
    });

    testWidgets('12b. a missing createdAt is denied', (tester) async {
      final w = await _buildWorld(tester, 't12b');
      await expectLater(
        approveTxn(w, matchOmit: {'createdAt'}),
        permissionDenied(),
      );
    });

    testWidgets('12c. an extra key on the match is denied', (tester) async {
      final w = await _buildWorld(tester, 't12c');
      await expectLater(
        approveTxn(w, matchOverrides: {'extra': 'junk'}),
        permissionDenied(),
      );
    });

    testWidgets('12d. a client timestamp that is not the server time is denied',
        (tester) async {
      final w = await _buildWorld(tester, 't12d');
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
      final w = await _buildWorld(tester, 't10a');
      await setBlock('${w.hostUid}_${w.guestUid}', w.hostUid, w.guestUid);
      await expectLater(approveTxn(w), permissionDenied());
    });

    testWidgets('10b. a block (guest blocked host) between them is denied', (
      tester,
    ) async {
      final w = await _buildWorld(tester, 't10b');
      final g = await signInTestUser(uid: w.guestClaim);
      expect(g.uid, w.guestUid);
      await setBlock('${w.guestUid}_${w.hostUid}', w.guestUid, w.hostUid);
      final h = await signInTestUser(uid: w.hostClaim);
      expect(h.uid, w.hostUid);
      await expectLater(approveTxn(w), permissionDenied());
    });
  });
  // ---- `meals` — integrity ----
  // The `meals` rules: create only an `open`, guest-less, future-dated meal as
  // yourself (exactly what `MealRepositoryImpl.createMeal` writes); update only
  // `status`/`guestId`, only `open -> matched`, only together with a genuine
  // pending -> approved request from that guest in the same transaction
  // (`mealApprovalLink`); delete only while `open`. Real emulator-minted uids;
  // each denial varies ONE property of a valid body. Forbidden pre-states
  // (matched meal, decided request) are seeded through the admin REST writes.
  group('meals — integrity', () {
    // By default a `matches/{mealId}` doc is admin-seeded: the meals update
    // rule requires the match to exist after the write (`existsAfter`), so
    // seeding it keeps that clause satisfied and lets each case isolate ONE
    // other clause without writing a match (the `matches` create rule has its
    // own group). Pass `withMatch: false` for the cases about the match itself.
    Future<_MatchWorld> world(
      WidgetTester tester,
      String suffix, {
      bool guestRequests = true,
      bool withMatch = true,
    }) async {
      final w = await _buildWorld(
        tester,
        suffix,
        guestRequests: guestRequests,
        prefix: 'mv',
      );
      if (withMatch) {
        await adminSetDoc('matches', w.mealId, {
          'id': w.mealId,
          'mealId': w.mealId,
          'hostId': w.hostUid,
          'guestId': w.guestUid,
          'participants': [w.hostUid, w.guestUid],
          'createdAt': DateTime.now(),
        });
      }
      return w;
    }

    DocumentReference<Map<String, dynamic>> mealRef(_MatchWorld w) =>
        _db.collection('meals').doc(w.mealId);

    // One transaction: a meal update (defaults to the real approve's
    // `status: matched` + `guestId: guest`; [meal] entries override/extend it),
    // unless [approveRequest] is false the request `approved` write, and with
    // [createMatch] the `matches/{mealId}` create (the full real approve).
    Future<void> mealTxn(
      _MatchWorld w, {
      Map<String, Object?> meal = const {},
      bool approveRequest = true,
      String? requestId,
      bool createMatch = false,
    }) {
      return _db.runTransaction((txn) async {
        txn.update(mealRef(w), {
          'status': 'matched',
          'guestId': w.guestUid,
          ...meal,
        });
        if (approveRequest) {
          txn.update(_db.collection('requests').doc(requestId ?? w.reqId), {
            'status': 'approved',
          });
        }
        if (createMatch) {
          txn.set(_db.collection('matches').doc(w.mealId), {
            'id': w.mealId,
            'mealId': w.mealId,
            'hostId': w.hostUid,
            'guestId': w.guestUid,
            'participants': [w.hostUid, w.guestUid],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }

    // The key set `MealRepositoryImpl.createMeal` writes (`MealDto.toJson()`
    // with `restaurant` flattened, `dateTime` a Timestamp, `createdAt` the
    // server timestamp) — including `guestId: null` and `note: null`.
    // [overrides] vary one property; [omit] drops keys.
    Future<void> createRaw(
      String hostUid, {
      Map<String, Object?> overrides = const {},
      Set<String> omit = const {},
    }) {
      final ref = _db.collection('meals').doc();
      final body = <String, Object?>{
        'id': ref.id,
        'hostId': hostUid,
        'restaurant': {
          'placeId': 'p1',
          'name': 'Chez Test',
          'address': '1 Rue Test',
          'lat': 48.8566,
          'lng': 2.3522,
        },
        'dateTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 3)),
        ),
        'geohash': 'u09tun',
        'note': null,
        'womenOnly': false,
        'seats': 2,
        'status': 'open',
        'guestId': null,
        'createdAt': FieldValue.serverTimestamp(),
        ...overrides,
      }..removeWhere((k, _) => omit.contains(k));
      return ref.set(body);
    }

    // ---- allowed ----

    testWidgets(
      "A1. the app's own create (MealRepositoryImpl.createMeal) is allowed",
      (tester) async {
        await _bootOnce(tester);
        final host = await signInTestUser(uid: 'mv-create-real');
        final id = await MealRepositoryImpl(firestore: _db).createMeal(
          Meal(
            id: '',
            hostId: host.uid,
            restaurant: const Restaurant(
              placeId: 'p1',
              name: 'Chez Test',
              address: '1 Rue Test',
              lat: 48.8566,
              lng: 2.3522,
            ),
            dateTime: DateTime.now().add(const Duration(hours: 3)),
            geohash: '',
            seats: 2,
          ),
        );
        final snap = await _db.collection('meals').doc(id).get();
        expect(snap.exists, isTrue);
        final data = snap.data()!;
        // The exact payload shape the rule has to admit.
        expect(data.containsKey('guestId'), isTrue);
        expect(data['guestId'], isNull);
        expect(data.containsKey('note'), isTrue);
        expect(data['note'], isNull);
        expect(data['status'], 'open');
        expect(data['seats'], 2);
      },
    );

    testWidgets(
      'A1b. a create with the exact createMeal key set (guestId: null, note: '
      'null, serverTimestamp createdAt) is allowed',
      (tester) async {
        await _bootOnce(tester);
        final host = await signInTestUser(uid: 'mv-create-raw');
        await createRaw(host.uid);
      },
    );

    testWidgets('A1c. a create with no guestId key at all is allowed', (
      tester,
    ) async {
      await _bootOnce(tester);
      final host = await signInTestUser(uid: 'mv-create-noguest');
      await createRaw(host.uid, omit: {'guestId'});
    });

    testWidgets(
      'A2. the real approve (meal + request + match in one transaction) is '
      'allowed',
      (tester) async {
        final w = await world(tester, 'a2', withMatch: false);
        await mealTxn(w, createMatch: true);
        final meal = await mealRef(w).get();
        expect(meal.data()!['status'], 'matched');
        expect(meal.data()!['guestId'], w.guestUid);
        final match = await _db
            .collection('matches')
            .doc(w.mealId)
            .get(const GetOptions(source: Source.server));
        expect(match.exists, isTrue);
      },
    );

    // The meals rule has no client delete: deleting an open meal and
    // re-creating it at the same id would keep the `{mealId}_{guestId}`
    // requests attached to a different restaurant/dateTime (bait and switch).
    testWidgets(
      'A3. the host deleting an open meal is denied, so delete + recreate at '
      'the same id is closed',
      (tester) async {
        final w = await world(tester, 'a3');
        await expectLater(mealRef(w).delete(), permissionDenied());
        // The recreate step is also unreachable: a `set` over the existing
        // id is an update, which may not change the restaurant.
        await expectLater(
          mealRef(w).set({
            'hostId': w.hostUid,
            'status': 'open',
            'geohash': 'u09',
            'dateTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 5)),
            ),
            'womenOnly': false,
            'restaurant': {
              'placeId': 'other-place',
              'name': 'Elsewhere',
              'address': '2 Rue Autre',
              'lat': 1.0,
              'lng': 2.0,
            },
          }),
          permissionDenied(),
        );
        final snap = await mealRef(w).get(
          const GetOptions(source: Source.server),
        );
        expect(snap.exists, isTrue);
        expect(
          (snap.data()!['restaurant'] as Map<String, dynamic>)['placeId'],
          'seed-place-id',
        );
      },
    );

    // ---- immutable fields ----

    testWidgets('D1. the host reassigning hostId is denied', (tester) async {
      final w = await world(tester, 'd1');
      await expectLater(
        mealRef(w).update({'hostId': w.otherUid}),
        permissionDenied(),
      );
    });

    testWidgets('D1b. changing dateTime is denied', (tester) async {
      final w = await world(tester, 'd1b');
      await expectLater(
        mealRef(w).update({
          'dateTime': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 9)),
          ),
        }),
        permissionDenied(),
      );
    });

    testWidgets('D1c. changing restaurant is denied', (tester) async {
      final w = await world(tester, 'd1c');
      await expectLater(
        mealRef(w).update({
          'restaurant': {
            'placeId': 'other-place',
            'name': 'Elsewhere',
            'address': '2 Rue Autre',
            'lat': 1.0,
            'lng': 2.0,
          },
        }),
        permissionDenied(),
      );
    });

    testWidgets('D1d. changing womenOnly is denied', (tester) async {
      final w = await world(tester, 'd1d');
      await expectLater(
        mealRef(w).update({'womenOnly': true}),
        permissionDenied(),
      );
    });

    // Each of these carries a COMPLETELY valid approve (status, guestId, the
    // request pending -> approved) plus one extra key, so ONLY the
    // `affectedKeys().hasOnly(['status', 'guestId'])` whitelist can deny.
    final extraKeys = <String, Object?>{
      'hostId': 'someone-else',
      'dateTime': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 9)),
      ),
      'restaurant': {
        'placeId': 'other-place',
        'name': 'Elsewhere',
        'address': '2 Rue Autre',
        'lat': 1.0,
        'lng': 2.0,
      },
      'womenOnly': true,
    };
    for (final entry in extraKeys.entries) {
      testWidgets(
        'D2. a valid approve that also changes ${entry.key} is denied',
        (tester) async {
          final w = await world(tester, 'd2-${entry.key}');
          final value = entry.key == 'hostId' ? w.otherUid : entry.value;
          await expectLater(
            mealTxn(w, meal: {entry.key: value}),
            permissionDenied(),
          );
        },
      );
    }

    // ---- matched only through a genuine approve ----

    // The request stays pending after the write, so ONLY
    // `getAfter(request).status == 'approved'` can deny.
    testWidgets(
      "D3. status: matched with the guest's request still pending after the "
      'write is denied',
      (tester) async {
        final w = await world(tester, 'd3');
        await expectLater(
          mealRef(w).update({'status': 'matched', 'guestId': w.guestUid}),
          permissionDenied(),
        );
      },
    );

    testWidgets('D3b. status: matched with no request at all is denied', (
      tester,
    ) async {
      final w = await world(tester, 'd3b', guestRequests: false);
      await expectLater(
        mealRef(w).update({'status': 'matched', 'guestId': w.guestUid}),
        permissionDenied(),
      );
    });

    // Request already `approved` (admin-seeded), meal write only: the
    // request's after-state is still `approved`, so ONLY the
    // `get(request).status == 'pending'` pre-state can deny.
    testWidgets('D4a. a request that is already approved is denied', (
      tester,
    ) async {
      final w = await world(tester, 'd4a');
      await adminUpdateDoc('requests', w.reqId, {'status': 'approved'});
      await expectLater(
        mealRef(w).update({'status': 'matched', 'guestId': w.guestUid}),
        permissionDenied(),
      );
    });

    testWidgets('D4b. a request that is already denied is denied', (
      tester,
    ) async {
      final w = await world(tester, 'd4b');
      await adminUpdateDoc('requests', w.reqId, {'status': 'denied'});
      await expectLater(mealTxn(w), permissionDenied());
    });

    // `other`'s request (at the canonical `{meal}_{other}` id) names the guest
    // as its guestId; the host approves it and the meal names `other`. Request
    // pending -> approved and the host match, so ONLY the link's
    // `get(request).guestId == guestId` clause can deny.
    testWidgets(
      "D5. a meal guestId that is not the approved request's guest is denied",
      (tester) async {
        final w = await world(tester, 'd5');
        final spoofedId = '${w.mealId}_${w.otherUid}';
        await adminSetDoc('requests', spoofedId, {
          'id': spoofedId,
          'mealId': w.mealId,
          'guestId': w.guestUid,
          'hostId': w.hostUid,
          'status': 'pending',
          'createdAt': DateTime.now(),
        });
        await expectLater(
          mealTxn(w, meal: {'guestId': w.otherUid}, requestId: spoofedId),
          permissionDenied(),
        );
      },
    );

    testWidgets(
      'D5b. a meal guestId whose own request is not the one approved is '
      'denied',
      (tester) async {
        final w = await world(tester, 'd5b');
        await expectLater(
          mealTxn(w, meal: {'guestId': w.otherUid}),
          permissionDenied(),
        );
      },
    );

    // Valid approve otherwise; ONLY `request.resource.data.status == 'matched'`
    // can deny.
    testWidgets('D6. a status other than matched is denied', (tester) async {
      final w = await world(tester, 'd6');
      await expectLater(
        mealTxn(w, meal: {'status': 'completed'}),
        permissionDenied(),
      );
    });

    testWidgets('D6b. a matched meal with a null guestId is denied', (
      tester,
    ) async {
      final w = await world(tester, 'd6b');
      await expectLater(
        mealTxn(w, meal: {'guestId': null}),
        permissionDenied(),
      );
    });

    // Meal already `matched` (admin-seeded) while the request is still
    // pending: a valid approve write from this pre-state is denied ONLY by
    // `resource.data.status == 'open'`.
    testWidgets('D7. updating a meal that is already matched is denied', (
      tester,
    ) async {
      final w = await world(tester, 'd7');
      await adminUpdateDoc('meals', w.mealId, {
        'status': 'matched',
        'guestId': w.otherUid,
      });
      await expectLater(mealTxn(w), permissionDenied());
    });

    // Plain denial case (denied by the missing request, not an isolating case
    // for the meal-host clause: see D8b).
    testWidgets('D8. a non-host updating the meal is denied', (tester) async {
      final w = await world(tester, 'd8');
      final other = await signInTestUser(uid: w.otherClaim);
      expect(other.uid, w.otherUid);
      await expectLater(
        mealRef(w).update({'status': 'matched', 'guestId': w.otherUid}),
        permissionDenied(),
      );
    });

    // The meal + request flip without the match doc (skips the `matches` rule's
    // block check; the guest would see an approved request with no chat): no
    // match exists before or after, so ONLY `existsAfter(matches/{mealId})`
    // can deny.
    testWidgets(
      'D9. a meal + request approval that does not create the match is denied',
      (tester) async {
        final w = await world(tester, 'd9', withMatch: false);
        await expectLater(mealTxn(w), permissionDenied());
      },
    );

    // Forged host: `other` is the (admin-seeded) host of their own pending
    // request `{meal}_{other}` and approves it while flipping SOMEONE ELSE'S
    // meal to matched with themselves as guest. The requests update rule
    // passes (other is that request's host), the link passes
    // (`get(req).hostId == auth.uid`, guestId == other) and `matches/{meal}`
    // exists (seeded), so ONLY the meal's `resource.data.hostId ==
    // request.auth.uid` can deny. (A real match create can't be added: the
    // `matches` rule would deny it itself.)
    testWidgets(
      "D8b. approving one's own forged request to flip someone else's meal "
      'is denied',
      (tester) async {
        final w = await world(tester, 'd8b');
        final forgedId = '${w.mealId}_${w.otherUid}';
        await adminSetDoc('requests', forgedId, {
          'id': forgedId,
          'mealId': w.mealId,
          'hostId': w.otherUid,
          'guestId': w.otherUid,
          'status': 'pending',
          'createdAt': DateTime.now(),
        });
        final other = await signInTestUser(uid: w.otherClaim);
        expect(other.uid, w.otherUid);
        await expectLater(
          mealTxn(w, meal: {'guestId': w.otherUid}, requestId: forgedId),
          permissionDenied(),
        );
      },
    );

    // ---- create ----

    testWidgets('C1. creating a meal that is already matched is denied', (
      tester,
    ) async {
      await _bootOnce(tester);
      final host = await signInTestUser(uid: 'mv-create-matched');
      await expectLater(
        createRaw(host.uid, overrides: {'status': 'matched'}),
        permissionDenied(),
      );
    });

    testWidgets('C2. creating a meal with a guestId is denied', (tester) async {
      await _bootOnce(tester);
      final host = await signInTestUser(uid: 'mv-create-guest');
      await expectLater(
        createRaw(host.uid, overrides: {'guestId': 'someone'}),
        permissionDenied(),
      );
    });

    testWidgets('C3. creating a meal in the past is denied', (tester) async {
      await _bootOnce(tester);
      final host = await signInTestUser(uid: 'mv-create-past');
      await expectLater(
        createRaw(
          host.uid,
          overrides: {
            'dateTime': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 1)),
            ),
          },
        ),
        permissionDenied(),
      );
    });

    // ---- delete ----

    testWidgets('X1. deleting a matched meal is denied', (tester) async {
      final w = await world(tester, 'x1');
      await adminUpdateDoc('meals', w.mealId, {
        'status': 'matched',
        'guestId': w.guestUid,
      });
      await expectLater(mealRef(w).delete(), permissionDenied());
    });

    testWidgets("X2. deleting someone else's open meal is denied", (
      tester,
    ) async {
      final w = await world(tester, 'x2');
      final other = await signInTestUser(uid: w.otherClaim);
      expect(other.uid, w.otherUid);
      await expectLater(mealRef(w).delete(), permissionDenied());
    });
  });

  // ---- `requests` update — a request is decided once ----
  // The `requests` update rule is host-only, `status` only, to approved|denied,
  // and only FROM `pending`: an approved request can't be flipped to denied
  // (nor a denied one revived), so a decision is final. Every case is signed
  // in as the host (what `_buildWorld` returns). Non-pending pre-states are
  // admin-seeded (`adminUpdateDoc`), since no client path reaches them
  // without going through the very rule under test.
  group('requests update — decided once', () {
    Future<_MatchWorld> world(
      WidgetTester tester,
      String suffix, {
      bool otherRequests = false,
    }) =>
        _buildWorld(tester, suffix, otherRequests: otherRequests, prefix: 'rd');

    DocumentReference<Map<String, dynamic>> reqRef(String id) =>
        _db.collection('requests').doc(id);

    Future<String> statusOf(String id) async {
      final snap = await reqRef(
        id,
      ).get(const GetOptions(source: Source.server));
      return snap.data()!['status'] as String;
    }

    testWidgets('R1. a host denies a pending request (the app deny) is '
        'allowed', (tester) async {
      final w = await world(tester, 'r1');
      await reqRef(w.reqId).update({'status': 'denied'});
      expect(await statusOf(w.reqId), 'denied');
    });

    testWidgets('R1b. a host approves a pending request is allowed', (
      tester,
    ) async {
      final w = await world(tester, 'r1b');
      await reqRef(w.reqId).update({'status': 'approved'});
      expect(await statusOf(w.reqId), 'approved');
    });

    testWidgets(
      'R1c. the post-commit sibling-deny batch (pending -> denied) is allowed',
      (tester) async {
        final w = await world(tester, 'r1c', otherRequests: true);
        final siblingId = '${w.mealId}_${w.otherUid}';
        final batch = _db.batch()
          ..update(reqRef(w.reqId), {'status': 'denied'})
          ..update(reqRef(siblingId), {'status': 'denied'});
        await batch.commit();
        expect(await statusOf(w.reqId), 'denied');
        expect(await statusOf(siblingId), 'denied');
      },
    );

    testWidgets('R2. re-deciding an approved request (-> denied) is denied', (
      tester,
    ) async {
      final w = await world(tester, 'r2');
      await adminUpdateDoc('requests', w.reqId, {'status': 'approved'});
      await expectLater(
        reqRef(w.reqId).update({'status': 'denied'}),
        permissionDenied(),
      );
      expect(await statusOf(w.reqId), 'approved');
    });

    testWidgets('R3. reviving a denied request (-> approved) is denied', (
      tester,
    ) async {
      final w = await world(tester, 'r3');
      await adminUpdateDoc('requests', w.reqId, {'status': 'denied'});
      await expectLater(
        reqRef(w.reqId).update({'status': 'approved'}),
        permissionDenied(),
      );
      expect(await statusOf(w.reqId), 'denied');
    });

    testWidgets(
      'R4. re-writing an approved request as approved is denied (not only '
      'a flip is final)',
      (tester) async {
        final w = await world(tester, 'r4');
        await adminUpdateDoc('requests', w.reqId, {'status': 'approved'});
        await expectLater(
          reqRef(w.reqId).update({'status': 'approved'}),
          permissionDenied(),
        );
      },
    );

    testWidgets('R5. re-writing a denied request as denied is denied', (
      tester,
    ) async {
      final w = await world(tester, 'r5');
      await adminUpdateDoc('requests', w.reqId, {'status': 'denied'});
      await expectLater(
        reqRef(w.reqId).update({'status': 'denied'}),
        permissionDenied(),
      );
    });
  });

  // ---- `ratings` create — the meal has happened ----
  // The `ratings` create rule requires `meals/{matchId}.dateTime <=
  // request.time` (matchId == mealId). Everything else in each case is the
  // valid baseline from `seedRatingMatch` (host rates the guest, no comment);
  // the match's meal is admin-seeded with the date under test, since a client
  // can't create a past meal.
  group('ratings create — the meal has happened', () {
    testWidgets('G1. rating a meal dated in the past is allowed', (
      tester,
    ) async {
      final seed = await seedRatingMatch(tester, 'g1');
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
    });

    testWidgets('G2. rating a meal that is still in the future is denied', (
      tester,
    ) async {
      final seed = await seedRatingMatch(
        tester,
        'g2',
        mealDateTime: DateTime.now().add(const Duration(hours: 3)),
      );
      await expectLater(
        createRating(
          matchId: seed.matchId,
          raterUid: seed.hostUid,
          targetUid: seed.guestUid,
        ),
        permissionDenied(),
      );
    });

    testWidgets('G3. rating a match with no meal doc is denied', (
      tester,
    ) async {
      final seed = await seedRatingMatch(tester, 'g3', withMeal: false);
      await expectLater(
        createRating(
          matchId: seed.matchId,
          raterUid: seed.hostUid,
          targetUid: seed.guestUid,
        ),
        permissionDenied(),
      );
    });
  });
}
