/// Screenshot capture run: boots the REAL app on the iOS Simulator against the
/// Firebase emulators, seeds a realistic world (`support/world.dart`), drives
/// to each screen and hands the live screen to the host for
/// `xcrun simctl io screenshot` (`support/handoff.dart`, `tool/ux_capture.sh`).
///
/// Run via `make ux-capture` (never part of `make e2e` / CI / `flutter test`).
/// It lives outside `integration_test/` on purpose, so it is started with
/// `flutter drive --driver ux_audit/driver.dart --target
/// ux_audit/capture_test.dart` (see `driver.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

import '../integration_test/support/app_harness.dart';
import '../integration_test/support/auth.dart';
import 'support/handoff.dart';
import 'support/world.dart';

/// Swallows only avatar/image network errors (any 404 or refused fetch must
/// not fail the run); restores the previous handler at teardown.
void _suppressExpectedImageErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Bounded stand-in for `pumpAndSettle` (never the unbounded default).
Future<void> _settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.pump(const Duration(milliseconds: 100));
  } while (tester.binding.hasScheduledFrame &&
      DateTime.now().isBefore(deadline));
}

/// Pumps until [finder] matches (bounded), then a short bounded settle.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets, reason: 'not found within $timeout: $finder');
  await _settle(tester);
}

/// Answers firebase_messaging's `Messaging#requestPermission` with "denied"
/// so iOS never shows its blocking native "Would Like to Send You
/// Notifications" alert over the photographed screens. `simctl privacy` can't
/// pre-decide notifications, and the app asks as soon as a signed-in user
/// reaches Discover. Every other call on the channel passes straight through
/// to the real plugin.
void _answerPushPermissionPrompt(WidgetTester tester) {
  const channelName = 'plugins.flutter.io/firebase_messaging';
  const codec = StandardMethodCodec();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMessageHandler(channelName, (message) async {
    if (message != null &&
        codec.decodeMethodCall(message).method ==
            'Messaging#requestPermission') {
      // authorizationStatus 0 == AuthorizationStatus.denied.
      return codec.encodeSuccessEnvelope(<String, int>{
        'authorizationStatus': 0,
      });
    }
    return await messenger.delegate.send(channelName, message);
  });
  addTearDown(() => messenger.setMockMessageHandler(channelName, null));
}

/// Lets runtime-fetched fonts (google_fonts downloads Nunito on first use) and
/// network images (avatars) finish, bounded, and pumps so they paint.
Future<void> _awaitAssets(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await GoogleFonts.pendingFonts().timeout(
      const Duration(seconds: 15),
      onTimeout: () => const [],
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  // Network images have no completion hook here: a bounded run of frames.
  final end = DateTime.now().add(const Duration(milliseconds: 2500));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _settle(tester);
}

/// Prints which font family each text style of the app theme actually carries
/// (diagnostic for the "is it really Nunito" question; shows in the run log).
void _logFontDiagnostics(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  final t = Theme.of(context).textTheme;
  final styles = <String, TextStyle?>{
    'displayLarge': t.displayLarge,
    'headlineLarge': t.headlineLarge,
    'headlineSmall': t.headlineSmall,
    'titleLarge': t.titleLarge,
    'titleMedium': t.titleMedium,
    'titleSmall': t.titleSmall,
    'bodyLarge': t.bodyLarge,
    'bodyMedium': t.bodyMedium,
    'bodySmall': t.bodySmall,
    'labelLarge': t.labelLarge,
    'labelMedium': t.labelMedium,
  };
  for (final e in styles.entries) {
    // Run-log diagnostic for the audit; there is no logger in dev tooling.
    // ignore: avoid_print
    print('UXFONT ${e.key} family=${e.value?.fontFamily} '
        'weight=${e.value?.fontWeight}');
  }
  // Same diagnostic as above.
  // ignore: avoid_print
  print('UXFONT runtimeFetching=${GoogleFonts.config.allowRuntimeFetching}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture the proof screens',
    (tester) async {
      // No red DEBUG ribbon in the photographs.
      WidgetsApp.debugAllowBannerOverride = false;
      _suppressExpectedImageErrors();
      _answerPushPermissionPrompt(tester);

      await pumpApp(tester);
      // A previous run's session can survive in the simulator keychain even
      // though the emulator was reset: always start from signed out.
      await signOutTestUser();

      // 01: sign-in, signed out.
      final signInField = find.byKey(const Key('signin_phone_field'));
      await _pumpUntilFound(tester, signInField);
      await _awaitAssets(tester);
      _logFontDiagnostics(tester);
      await shot('01_signin');

      // Seed the world; the session ends signed in as the viewer.
      final world = await seedWorld();

      // 02: Discover with data.
      final discoverMarker = find.byKey(
        const Key('discovery_create_meal_button'),
      );
      await _pumpUntilFound(tester, discoverMarker);
      final card = find.byKey(
        Key('discovery_meal_card_${world.openMealByOtherId}'),
      );
      await _pumpUntilFound(tester, card);
      await _awaitAssets(tester);
      await shot('02_discover');

      // 03: meal detail of an open meal by another host.
      await tester.ensureVisible(card);
      await _settle(tester);
      await tester.tap(card);
      final requestButton = find.byKey(
        const Key('meal_detail_request_to_join_button'),
      );
      await _pumpUntilFound(tester, requestButton);
      await _awaitAssets(tester);
      await shot('03_meal_detail');

      // 04: the seeded match's chat.
      await tester.pageBack();
      await _pumpUntilFound(tester, discoverMarker);
      final chatsTab = find.text('Chats');
      expect(chatsTab, findsOneWidget);
      await tester.tap(chatsTab);
      await _settle(tester);
      final tile = find.byKey(Key('chat_list_tile_${world.matchMealId}'));
      await _pumpUntilFound(tester, tile);
      await tester.tap(tile);
      final list = find.byKey(const Key('chat_messages_list'));
      await _pumpUntilFound(tester, list);
      await _awaitAssets(tester);
      await shot('04_chat');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
