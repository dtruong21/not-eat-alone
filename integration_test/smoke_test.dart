/// Scenario 1 — smoke: sign in a seeded test user, boot the real app
/// against the Firebase Emulator Suite, and confirm it lands on the authed
/// Discover feed without error. Run via `make e2e` (see `Makefile`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets('signed-in user boots to the Discover feed', (tester) async {
    // Act: boot the real app against the emulators FIRST — `pumpApp` is
    // what calls `Firebase.initializeApp()` (via `bootstrap`). Calling
    // `signInTestUser`/`seedUserProfile` before this throws `[core/no-app]
    // No Firebase App '[DEFAULT]' has been created` (confirmed live — see
    // task-3-report.md), since both read `FirebaseAuth.instance`/
    // `FirebaseFirestore.instance`, which need an initialized app. The app
    // boots to the sign-in screen (no user yet); signing in afterwards
    // mutates the same `FirebaseAuth` session the app's
    // `authStateProvider` stream is already watching, so the router reacts
    // and redirects same as a real sign-in.
    await pumpApp(tester);

    // Arrange: sign in a test user with a valid (profile-complete)
    // profile, now that Firebase is initialized. Seed under the
    // SDK-assigned uid (`user.uid`), not the `sub` we requested — the Auth
    // emulator's `signInWithIdp` is confirmed (see task-3-report.md) to
    // mint a Firebase uid equal to the requested `sub`/`uid`, but seeding
    // off the SDK's own return value is the robust choice regardless.
    final user = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: user.uid);

    // Assert: the app reached its authed home (Discover) without error.
    // The auth -> Firestore-profile redirect chain (authStateProvider +
    // currentUserDocProvider, both streams) resolves asynchronously, so
    // bound a pump loop on a marker that renders ONLY on the authed
    // Discover screen (`DiscoveryScreen`'s "Create a meal" FAB —
    // lib/features/meal/presentation/discovery_screen.dart:204) rather
    // than asserting immediately. The FAB is present regardless of the
    // meal-list AsyncValue state (loading/error/empty/data), so an empty
    // Discover feed (no seeded meal) is a valid "rendered" outcome here.
    final discoverMarker = find.byKey(
      const Key('discovery_create_meal_button'),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (discoverMarker.evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();

    expect(
      discoverMarker,
      findsOneWidget,
      reason: 'app did not land on the authed Discover feed',
    );
    expect(tester.takeException(), isNull);
  });
}
