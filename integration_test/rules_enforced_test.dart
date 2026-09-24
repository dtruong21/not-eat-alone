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
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets(
    'firestore.rules denies a meals/ create with a forged hostId',
    (tester) async {
      // Act: boot the app against the emulators (wires the Firestore SDK to
      // the emulator — see `pumpApp`) and sign in a test user, same
      // preconditions as `smoke_test.dart`.
      await pumpApp(tester);
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
}
