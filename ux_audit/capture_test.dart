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

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';

import '../integration_test/support/app_harness.dart';
import '../integration_test/support/auth.dart';
import '../integration_test/support/emulator_admin.dart';
import 'support/handoff.dart';
import 'support/world.dart';

/// Name of the screen state being photographed (for the overflow log).
String _current = 'boot';

/// Layout overflows found while capturing, `<state>: <first line>`.
final List<String> _overflows = <String>[];

/// Swallows only expected noise so it can't fail the run: avatar/image
/// network errors, and RenderFlex/RenderBox overflows (those are audit
/// findings, not harness failures: each is printed as a `UXOVERFLOW` line and
/// summarised at the end). Everything else still reaches the previous handler.
/// Restores the previous handler at teardown.
void _suppressExpectedErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      final line = text.split('\n').first;
      _overflows.add('$_current: $line');
      // Run-log diagnostic for the audit; there is no logger in dev tooling.
      // ignore: avoid_print
      print('UXOVERFLOW $_current: $line');
      return;
    }
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

/// Lets network images (avatars) finish, bounded, and pumps so they paint.
/// (Nunito is a bundled asset, so there is no font to wait for.)
Future<void> _awaitAssets(WidgetTester tester) async {
  // Network images have no completion hook here: a bounded run of frames.
  final end = DateTime.now().add(const Duration(milliseconds: 1500));
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
    print(
      'UXFONT ${e.key} family=${e.value?.fontFamily} '
      'weight=${e.value?.fontWeight}',
    );
  }
}

// ---------------------------------------------------------------------------
// Interaction helpers
// ---------------------------------------------------------------------------

/// A context under the router (for `GoRouter.of`).
BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

/// Test-side navigation, used ONLY where the UI offers no path to a screen
/// (each use is listed in `ux_audit/README.md`).
GoRouter _router(WidgetTester tester) => GoRouter.of(_context(tester));

/// A destination of the bottom navigation bar.
Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Scrolls [target] into view (builds lazy list items if needed), bounded.
Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: scrollable ?? find.byType(Scrollable).first,
      maxScrolls: 40,
    );
  }
  await tester.ensureVisible(target.first);
  await _settle(tester);
}

/// Reveals, taps, and settles.
Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  await _reveal(tester, target, scrollable: scrollable);
  await tester.tap(target.first);
  await _settle(tester);
}

/// Runs [body] while the [target] emulator (`firestore` or `auth`) is frozen
/// by the host (SIGSTOP), and thaws it afterwards, whatever happens.
Future<void> _frozen(String target, Future<void> Function() body) async {
  await hostCommand('freeze-$target');
  try {
    await body();
  } finally {
    await hostCommand('thaw-$target');
  }
}

/// Taps [target] with the emulator [freeze] (`firestore` or `auth`) frozen and
/// photographs the screen as [name]: the "in flight" state (spinner on the
/// button, disabled controls) held for as long as the host needs, because the
/// server never answers while it is frozen. Afterwards the emulator thaws,
/// the action completes and the run carries on. Without the freeze the
/// round trip to a local emulator finishes within a frame or two (the live
/// binding renders frames between pumps), too fast to photograph.
Future<void> _tapInFlight(
  WidgetTester tester,
  Finder target,
  String name, {
  required String freeze,
  Finder? mustShow,
}) async {
  await _reveal(tester, target);
  await _frozen(freeze, () async {
    // At large text sizes a button can end up under the keyboard or off the
    // screen on a non-scrolling screen: the tap then misses, which is itself
    // a finding (UXMISSING below), not a harness failure.
    await tester.tap(target.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    if (mustShow != null) {
      // The frame that shows the indicator may take a few pumps to appear.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (mustShow.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    // Photograph first, so a missing indicator can be looked at; then fail.
    await _snap(tester, name, assets: false);
    if (mustShow != null && mustShow.evaluate().isEmpty) {
      _missing.add(name);
      // Run-log diagnostic for the audit; there is no logger in dev tooling.
      // ignore: avoid_print
      print('UXMISSING $name: no in-flight indicator after the tap');
    }
  });
  // A missed tap can leave a sheet or dialog open: close it.
  await _dismissPopups(tester);
}

/// Spinners currently built.
Finder get _spinner => find.byType(CircularProgressIndicator);

/// Closes any snackbar left over by a submitted action.
Future<void> _clearSnackBars(WidgetTester tester) async {
  ScaffoldMessenger.of(_context(tester)).clearSnackBars();
  await _settle(tester);
}

/// Pumps until [finder] no longer matches (bounded; a leftover is reported by
/// the next step failing, not here).
Future<void> _pumpWhileFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await _settle(tester);
}

/// Lets the screen settle, then photographs it as [name].
Future<void> _snap(
  WidgetTester tester,
  String name, {
  bool assets = true,
}) async {
  _current = name;
  if (assets) await _awaitAssets(tester);
  await shot(name);
}

/// Taps outside the topmost popup/sheet/dialog (the modal barrier) to close
/// it.
Future<void> _tapBarrier(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 60));
  await _settle(tester);
}

/// Pops the current route through its back button; a no-op (never a failure)
/// when there is none, e.g. after a failed step already recovered.
Future<void> _back(WidgetTester tester) async {
  try {
    await tester.pageBack();
  } on Object {
    // Nothing to go back from.
  }
  await _settle(tester);
}

/// In-flight states whose indicator never appeared (see [_tapInFlight]).
final List<String> _missing = <String>[];

/// Closes any dialog, bottom sheet or popup menu that is still open (without
/// leaving the current page).
Future<void> _dismissPopups(WidgetTester tester) async {
  try {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((route) => route is! PopupRoute);
    await _settle(tester);
  } on Object {
    // Nothing open.
  }
}

/// Opens the chat with [matchId] from the Chats tab, from a clean start.
Future<void> _openChatFromList(WidgetTester tester, String matchId) async {
  await _recover(tester);
  await _tap(tester, _tab('Chats'));
  await _tap(tester, find.byKey(Key('chat_list_tile_$matchId')));
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('message_composer_field')),
  );
}

/// Makes sure the chat with [matchId] is on screen, navigating there from
/// scratch if an earlier step failed and left the app elsewhere.
Future<void> _ensureChat(WidgetTester tester, String matchId) async {
  if (find.byKey(const Key('chat_messages_list')).evaluate().isNotEmpty ||
      find.byKey(const Key('message_composer_field')).evaluate().isNotEmpty) {
    return;
  }
  await _recover(tester);
  await _tap(tester, _tab('Chats'));
  await _tap(tester, find.byKey(Key('chat_list_tile_$matchId')));
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('message_composer_field')),
  );
}

/// Steps that failed, `<name>: <error>`; the run fails at the end if any.
final List<String> _failures = <String>[];

/// Back to a known place after a failed step: close every pushed route and
/// open Discover.
Future<void> _recover(WidgetTester tester) async {
  try {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((route) => route.isFirst);
    await _settle(tester);
    _router(tester).go('/discover');
    await _settle(tester);
  } on Object catch (e) {
    // Run-log diagnostic for the audit; there is no logger in dev tooling.
    // ignore: avoid_print
    print('UXSTEP recovery failed: $e');
  }
}

/// Runs one screen-state capture. A failure is recorded and the run moves on
/// (so one broken state costs one PNG, not the whole 10-minute run); the test
/// fails at the end listing every failed step.
Future<void> _step(
  WidgetTester tester,
  String name,
  Future<void> Function() body,
) async {
  _current = name;
  try {
    await body();
  } on Object catch (e) {
    _failures.add('$name: ${e.toString().split('\n').first}');
    // Run-log diagnostic for the audit; there is no logger in dev tooling.
    // ignore: avoid_print
    print('UXSTEP FAIL $name: $e');
    await _recover(tester);
  }
}

// ---------------------------------------------------------------------------
// The run
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture every screen state', (tester) async {
    // No red DEBUG ribbon in the photographs.
    WidgetsApp.debugAllowBannerOverride = false;
    _suppressExpectedErrors();
    _answerPushPermissionPrompt(tester);

    await pumpApp(tester);
    // A previous run's session can survive in the simulator keychain even
    // though the emulator was reset: always start from signed out.
    await signOutTestUser();

    await _captureSignedOut(tester);

    // ---- Stage 1 of the world: users only (Discover/Chats/Requests empty).
    final users = await seedUsers();
    await _captureEmptyStates(tester);

    // ---- Stage 2: meals, requests, matches, chats.
    final world = await seedMeals(users);
    await _captureDiscover(tester, world);
    await _captureMealDetail(tester, world);
    await _captureCreateMeal(tester);
    await _captureRequests(tester);
    await _captureChats(tester, world);
    await _captureProfileAndSettings(tester);
    await _captureInboxInFlight(tester, world);
    await _captureWomenOnlyAsMan(tester, world);
    await _captureFeedErrors(tester, world);

    // ---- Onboarding screens need a user without a profile: last.
    await _captureOnboarding(tester, world);

    // Run-log summaries for the audit.
    // ignore: avoid_print
    print(
      'UXSUMMARY overflows=${_overflows.length} '
      'missingIndicators=${_missing.length} failedSteps=${_failures.length}',
    );
    expect(
      _failures,
      isEmpty,
      reason: 'screen states that could not be captured',
    );
  }, timeout: const Timeout(Duration(minutes: 25)));
}

// ---- Signed out: sign-in and phone verification ---------------------------

Future<void> _captureSignedOut(WidgetTester tester) async {
  final signInField = find.byKey(const Key('signin_phone_field'));
  await _step(tester, '01_signin', () async {
    await _pumpUntilFound(tester, signInField);
    await _awaitAssets(tester);
    _logFontDiagnostics(tester);
    await _snap(tester, '01_signin');
  });

  // Real UI: an implausible number; since plan 17a the screen refuses it
  // itself (no round trip) and shows the hint on the field.
  await _step(tester, '02_signin_phone_error', () async {
    await tester.enterText(
      find.byKey(const Key('signin_phone_field')),
      '+33 12',
    );
    await _settle(tester);
    await _tap(tester, find.text('Send code'));
    await _pumpUntilFound(
      tester,
      find.textContaining('Enter a phone number with country code'),
      timeout: const Duration(seconds: 20),
    );
    await _snap(tester, '02_signin_phone_error');
  });

  // Real UI: a valid number; the emulator accepts it (no real SMS) and the
  // app moves on to the code screen.
  await _step(tester, '04_phone_verify', () async {
    await tester.enterText(
      find.byKey(const Key('signin_phone_field')),
      '+33612345678',
    );
    await _settle(tester);
    // Since plan 17a the button's spinner ("Sending code…") stays until
    // `codeSent` arrives, so the frozen Auth emulator shows it.
    await _tapInFlight(
      tester,
      find.text('Send code'),
      '03_signin_phone_waiting',
      freeze: 'auth',
      mustShow: _spinner,
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phone_verify_code_field')),
      timeout: const Duration(seconds: 20),
    );
    await _snap(tester, '04_phone_verify');
  });

  // Real UI: a wrong code against the placeholder id is rejected by the Auth
  // emulator. The 6th digit submits by itself (plan 17a), so the emulator is
  // frozen BEFORE the code is typed: the spinner is the in-flight shot.
  await _step(tester, '06_phone_verify_error', () async {
    await _frozen('auth', () async {
      await tester.enterText(
        find.byKey(const Key('phone_verify_code_field')),
        '123456',
      );
      await tester.pump(const Duration(milliseconds: 100));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (_spinner.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _snap(tester, '05_phone_verify_in_flight', assets: false);
      if (_spinner.evaluate().isEmpty) {
        _missing.add('05_phone_verify_in_flight');
        // Run-log diagnostic for the audit; there is no logger in dev tooling.
        // ignore: avoid_print
        print('UXMISSING 05_phone_verify_in_flight: no in-flight indicator');
      }
    });
    // Either the "code didn't work" line on the field or, for an error the
    // repository does not map, the generic sentence.
    await _pumpUntilFound(
      tester,
      find.byWidgetPredicate((w) {
        final text = w is Text ? w.data ?? '' : '';
        return text.contains("didn't work") ||
            text.contains('Something went wrong');
      }),
      timeout: const Duration(seconds: 20),
    );
    final fieldError = find
        .textContaining("didn't work")
        .evaluate()
        .isNotEmpty;
    // Run-log result for the verification doc; dev tooling has no logger.
    // ignore: avoid_print
    print('UXCHECK wrong code: ${fieldError ? "field error" : "generic"}');
    await _snap(tester, '06_phone_verify_error');
  });

  // Real UI: once the 30 s cooldown has run out, "Resend code" asks the Auth
  // emulator for a new code and the screen confirms it ("Code sent again",
  // countdown restarted).
  await _step(tester, '07_phone_verify_resent', () async {
    await _pumpUntilFound(
      tester,
      find.text('Resend code'),
      timeout: const Duration(seconds: 45),
    );
    await _tap(tester, find.text('Resend code'));
    await _pumpUntilFound(tester, find.text('Code sent again'));
    await _snap(tester, '07_phone_verify_resent');
  });
}

// ---- Stage 1: empty Discover / Chats / Requests ---------------------------

Future<void> _captureEmptyStates(WidgetTester tester) async {
  final createButton = find.byKey(const Key('discovery_create_meal_button'));

  // The app has not pumped since sign-in, so the first frames build Discover
  // from scratch with its feed still loading; Firestore is frozen so that stays
  // true while the host photographs it.
  await _step(tester, '20_discover_loading', () async {
    final spinner = find.descendant(
      of: find.byType(DiscoveryScreen),
      matching: find.byType(SkeletonList),
    );
    // Let the viewer's own user doc arrive (without it the router would send
    // them to the age gate), then freeze Firestore: the feed's meal query can
    // not answer, so the loading state holds for as long as the host needs.
    await Future<void>.delayed(const Duration(seconds: 2));
    await _frozen('firestore', () async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 16));
        if (createButton.evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(createButton, findsOneWidget);
      await _snap(tester, '20_discover_loading', assets: false);
      expect(spinner, findsOneWidget, reason: 'feed already loaded');
    });
  });

  await _step(tester, '21_discover_empty', () async {
    await _pumpUntilFound(tester, find.text('No meals near you yet'));
    await _snap(tester, '21_discover_empty');
  });

  await _step(tester, '60_chats_loading', () async {
    await _frozen('firestore', () async {
      await tester.tap(_tab('Chats'));
      await tester.pump(const Duration(milliseconds: 100));
      await _snap(tester, '60_chats_loading', assets: false);
      expect(
        find.byType(SkeletonList),
        findsOneWidget,
        reason: 'chat list already loaded',
      );
    });
  });

  await _step(tester, '61_chats_empty', () async {
    await _pumpUntilFound(
      tester,
      find.text('No chats yet — match on a meal to start talking'),
    );
    await _snap(tester, '61_chats_empty');
  });

  // (No requests-loading shot: the shell's badge already watches the inbox, so
  // it is loaded before the tab is first opened.)
  await _step(tester, '51_requests_empty', () async {
    await _tap(tester, _tab('Requests'));
    await _pumpUntilFound(tester, find.text('No pending requests'));
    await _snap(tester, '51_requests_empty');
  });

  await _step(tester, 'back_to_discover', () => _tap(tester, _tab('Discover')));
}

// ---- Discover with data ---------------------------------------------------

Future<void> _captureDiscover(WidgetTester tester, UxWorld world) async {
  final card = find.byKey(
    Key('discovery_meal_card_${world.openMealByOtherId}'),
  );
  final feed = find.descendant(
    of: find.byType(DiscoveryScreen),
    matching: find.byType(Scrollable),
  );

  await _step(tester, '22_discover_data', () async {
    await _pumpUntilFound(tester, card);
    await _snap(tester, '22_discover_data');
  });

  await _step(tester, '23_discover_scrolled', () async {
    await tester.drag(feed.first, const Offset(0, -700));
    await _settle(tester);
    await _snap(tester, '23_discover_scrolled');
    await tester.drag(feed.first, const Offset(0, 2000));
    await _settle(tester);
  });

  await _step(tester, '24_discover_notice_dismissed', () async {
    await _tap(tester, find.byKey(const Key('paris_notice_close_button')));
    await _snap(tester, '24_discover_notice_dismissed');
  });

  // Pull to refresh: the refresh spinner at the top of the feed.
  await _step(tester, '25_discover_refreshing', () async {
    await tester.drag(feed.first, const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 300));
    await _snap(tester, '25_discover_refreshing', assets: false);
    await _settle(tester);
  });
}

// ---- Meal detail states ---------------------------------------------------

Future<void> _openFromDiscover(WidgetTester tester, String mealId) async {
  final feed = find.descendant(
    of: find.byType(DiscoveryScreen),
    matching: find.byType(Scrollable),
  );
  // Back to the top first: `scrollUntilVisible` only scrolls downwards.
  await tester.drag(feed.first, const Offset(0, 3000));
  await _settle(tester);
  await _tap(
    tester,
    find.byKey(Key('discovery_meal_card_$mealId')),
    scrollable: feed.first,
  );
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('meal_detail_restaurant_card')),
  );
}

Future<void> _captureMealDetail(WidgetTester tester, UxWorld world) async {
  final requestsDocId = '${world.openMealByOtherId}_${world.viewerUid}';

  // Open, then a real "Request to join" tap, then the host approving it
  // (admin write standing in for the host's action).
  await _step(tester, '40_meal_detail_open', () async {
    await _openFromDiscover(tester, world.openMealByOtherId);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    await _snap(tester, '40_meal_detail_open');
  });

  // Settled as "Requested". (The in-flight spinner of the button is replaced
  // by the optimistic local write within a frame, so it cannot be held.)
  await _step(tester, '42_meal_detail_requested', () async {
    await _tap(
      tester,
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_requested_button')),
    );
    await _snap(tester, '42_meal_detail_requested');
  });

  await _step(tester, '43_meal_detail_matched', () async {
    await adminUpdateDoc('requests', requestsDocId, {'status': 'approved'});
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_matched_banner')),
    );
    await _snap(tester, '43_meal_detail_matched');
  });
  await _back(tester);

  // Seeded: Farid declined the viewer's request on his Kunitoraya dinner.
  await _step(tester, '44_meal_detail_not_selected', () async {
    await _openFromDiscover(tester, world.mealIds['kunitoraya']!);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_not_selected_button')),
    );
    await _snap(tester, '44_meal_detail_not_selected');
  });
  await _back(tester);

  // Women-only meal as a woman, then (admin flips the viewer's gender while
  // the screen is open; no UI shows a women-only meal to a non-woman) as a
  // non-woman: the disabled button and its note.
  await _step(tester, '45_meal_detail_women_only', () async {
    await _openFromDiscover(tester, world.mealIds['flore']!);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    await _snap(tester, '45_meal_detail_women_only');
  });
  await _step(tester, '47_meal_detail_menu', () async {
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    await _tap(tester, find.byKey(const Key('safety_actions_menu')));
    await _snap(tester, '47_meal_detail_menu');
    await _tapBarrier(tester);
  });
  await _back(tester);

  // No UI path to your own meal's detail (Discover hides own meals and there
  // is no "my meals" list): push the route with the seeded meal.
  await _step(tester, '48_meal_detail_own', () async {
    unawaited(_router(tester).push('/meals/detail', extra: world.ownMeal));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_your_meal_chip')),
    );
    await _snap(tester, '48_meal_detail_own');
  });
  await _back(tester);

  // Rejected request: the meal is flipped to matched (admin) after the detail
  // screen loaded it, so the server rules reject the request.
  await _step(tester, '49_meal_detail_request_rejected', () async {
    await _openFromDiscover(tester, world.mealIds['chartier']!);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    await adminUpdateDoc('meals', world.mealIds['chartier']!, {
      'status': 'matched',
    });
    await _tap(
      tester,
      find.byKey(const Key('meal_detail_request_to_join_button')),
    );
    // The server rejects the write. The button that listens for the failure is
    // swapped out by latency compensation (optimistic "Requested") and back,
    // so no error message is shown: photograph what the user is left with.
    final end = DateTime.now().add(const Duration(seconds: 6));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _settle(tester);
    await _snap(tester, '49_meal_detail_request_rejected');
  });
  await _recover(tester);
}

// ---- Create a meal --------------------------------------------------------

Future<void> _captureCreateMeal(WidgetTester tester) async {
  await _step(tester, '30_restaurant_search', () async {
    await _tap(tester, find.byKey(const Key('discovery_create_meal_button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('restaurant_search_field')),
    );
    await _pumpUntilFound(tester, find.text('Le Comptoir du Relais'));
    await _snap(tester, '30_restaurant_search');
  });

  await _step(tester, '31_restaurant_search_no_matches', () async {
    await tester.enterText(
      find.byKey(const Key('restaurant_search_field')),
      'zzzz',
    );
    await _pumpUntilFound(tester, find.text('No matches'));
    await _snap(tester, '31_restaurant_search_no_matches');
  });

  await _step(tester, '32_restaurant_search_filtered', () async {
    await tester.enterText(
      find.byKey(const Key('restaurant_search_field')),
      'Chez',
    );
    await _pumpUntilFound(tester, find.text('Chez Georges'));
    await _snap(tester, '32_restaurant_search_filtered');
  });

  await _step(tester, '33_create_meal_empty', () async {
    await _tap(tester, find.byKey(const Key('restaurant_row_fake_007')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('create_meal_datetime_button')),
    );
    await _snap(tester, '33_create_meal_empty');
  });

  await _step(tester, '34_create_meal_date_picker', () async {
    await _tap(tester, find.byKey(const Key('create_meal_datetime_button')));
    await _pumpUntilFound(tester, find.text('OK'));
    await _snap(tester, '34_create_meal_date_picker');
    await _tap(tester, find.text('OK'));
  });

  await _step(tester, '35_create_meal_time_picker', () async {
    await _pumpUntilFound(tester, find.text('OK'));
    await _snap(tester, '35_create_meal_time_picker');
    await _tap(tester, find.text('OK'));
  });

  await _step(tester, '36_create_meal_filled', () async {
    await tester.enterText(
      find.byKey(const Key('create_meal_note_field')),
      'Looking for a lively table. I will bring a book in case I am early.',
    );
    await _tap(tester, find.byKey(const Key('create_meal_women_only_switch')));
    await _snap(tester, '36_create_meal_filled');
  });

  // Real submit: the new meal is the viewer's own, so it is not listed in
  // Discover; the confirmation snackbar is the state worth photographing.
  await _step(tester, '37_create_meal_in_flight', () async {
    await _tapInFlight(
      tester,
      find.byKey(const Key('create_meal_submit_button')),
      '37_create_meal_in_flight',
      freeze: 'firestore',
      mustShow: _spinner,
    );
  });

  await _step(tester, '26_discover_meal_created', () async {
    await _pumpUntilFound(
      tester,
      find.text('Meal created!'),
      timeout: const Duration(seconds: 60),
    );
    await _snap(tester, '26_discover_meal_created');
  });
}

// ---- Requests inbox -------------------------------------------------------

Future<void> _captureRequests(WidgetTester tester) async {
  await _step(tester, '52_requests_data', () async {
    await _tap(tester, _tab('Requests'));
    await _pumpUntilFound(tester, find.text('Approve'));
    // Let the per-row meal lookups (restaurant line, past-meal chip) land.
    await _awaitAssets(tester);
    await _snap(tester, '52_requests_data');
  });

  await _step(tester, '53_requests_scrolled', () async {
    final list = find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(Scrollable),
    );
    await tester.drag(list.first, const Offset(0, -600));
    await _settle(tester);
    await _snap(tester, '53_requests_scrolled');
  });
}

// ---- Chats ----------------------------------------------------------------

Future<void> _captureChats(WidgetTester tester, UxWorld world) async {
  final matchTile = find.byKey(Key('chat_list_tile_${world.matchMealId}'));
  final messages = find.byKey(const Key('chat_messages_list'));

  await _step(tester, '62_chats_data', () async {
    await _tap(tester, _tab('Chats'));
    await _pumpUntilFound(tester, matchTile);
    await _snap(tester, '62_chats_data');
  });

  await _step(tester, '63_chat_messages', () async {
    await _tap(tester, matchTile);
    await _pumpUntilFound(tester, messages);
    await _snap(tester, '63_chat_messages');
  });

  await _step(tester, '64_chat_messages_older', () async {
    await tester.drag(messages, const Offset(0, 900));
    await _settle(tester);
    await _snap(tester, '64_chat_messages_older');
    await tester.drag(messages, const Offset(0, -2000));
    await _settle(tester);
  });

  await _step(tester, '67_chat_menu', () async {
    await _ensureChat(tester, world.matchMealId);
    await _tap(tester, find.byKey(const Key('safety_actions_menu')));
    await _snap(tester, '67_chat_menu');
  });

  await _step(tester, '68_chat_report_sheet', () async {
    await _ensureChat(tester, world.matchMealId);
    await _tap(tester, find.byKey(const Key('safety_actions_report_item')));
    await _pumpUntilFound(tester, find.byKey(const Key('report_note_field')));
    await _snap(tester, '68_chat_report_sheet');
  });

  await _step(tester, '69_chat_report_filled', () async {
    await _tap(tester, find.byKey(const Key('report_reason_chip_harassment')));
    await tester.enterText(
      find.byKey(const Key('report_note_field')),
      'Keeps messaging after I asked to stop.',
    );
    await _settle(tester);
    await _snap(tester, '69_chat_report_filled');
  });

  // Real submit: the report is written, the sheet closes with a snackbar.
  await _step(tester, '70_chat_report_in_flight', () async {
    await _tapInFlight(
      tester,
      find.byKey(const Key('report_submit_button')),
      '70_chat_report_in_flight',
      freeze: 'firestore',
      mustShow: _spinner,
    );
    await _pumpWhileFound(tester, find.byKey(const Key('report_note_field')));
    await _clearSnackBars(tester);
  });

  await _step(tester, '71_chat_block_dialog', () async {
    await _ensureChat(tester, world.matchMealId);
    await _tap(tester, find.byKey(const Key('safety_actions_menu')));
    await _tap(tester, find.byKey(const Key('safety_actions_block_item')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('safety_actions_block_cancel')),
    );
    await _snap(tester, '71_chat_block_dialog');
    await _tap(tester, find.byKey(const Key('safety_actions_block_cancel')));
  });

  await _step(tester, '65_chat_empty', () async {
    await _openChatFromList(tester, world.mealIds['emptyChat']!);
    await _pumpUntilFound(tester, find.text('Say hi \u{1F44B}'));
    await _snap(tester, '65_chat_empty');
  });

  // Real send: the message is on its way (spinner in the send button).
  await _step(tester, '66_chat_send_pending', () async {
    await _ensureChat(tester, world.mealIds['emptyChat']!);
    await tester.enterText(
      find.byKey(const Key('message_composer_field')),
      'Hi Inès! Looking forward to the dumplings.',
    );
    await _settle(tester);
    await _tapInFlight(
      tester,
      find.byKey(const Key('message_composer_send_button')),
      '66_chat_send_pending',
      freeze: 'firestore',
      mustShow: _spinner,
    );
    await _settle(tester);
  });

  // The past meal the viewer hosted: the "How was your meal?" card, then the
  // rating sheet (closed without submitting).
  await _step(tester, '72_chat_post_meal_card', () async {
    await _openChatFromList(tester, world.pastMatchMealId);
    await _pumpUntilFound(tester, find.byKey(const Key('post_meal_card')));
    await _snap(tester, '72_chat_post_meal_card');
  });

  await _step(tester, '73_rating_sheet', () async {
    await _ensureChat(tester, world.pastMatchMealId);
    await _tap(tester, find.byKey(const Key('post_meal_card_rate_button')));
    await _pumpUntilFound(tester, find.byKey(const Key('rating_star_5')));
    await _snap(tester, '73_rating_sheet');
  });

  await _step(tester, '74_rating_sheet_filled', () async {
    await _pumpUntilFound(tester, find.byKey(const Key('rating_star_4')));
    await _tap(tester, find.byKey(const Key('rating_star_4')));
    await tester.enterText(
      find.byKey(const Key('rating_comment_field')),
      'Great company, we talked for hours.',
    );
    await _settle(tester);
    await _snap(tester, '74_rating_sheet_filled');
  });

  // Real submit: the rating is written (Giulia's aggregate is updated by the
  // emulated Cloud Function), the sheet closes with a snackbar.
  await _step(tester, '75_rating_sheet_in_flight', () async {
    await _tapInFlight(
      tester,
      find.byKey(const Key('rating_submit_button')),
      '75_rating_sheet_in_flight',
      freeze: 'firestore',
      mustShow: _spinner,
    );
    await _pumpWhileFound(tester, find.byKey(const Key('rating_star_5')));
    await _clearSnackBars(tester);
  });
  await _recover(tester);
}

// ---- Profile and settings -------------------------------------------------

Future<void> _captureProfileAndSettings(WidgetTester tester) async {
  await _step(tester, '80_profile_edit', () async {
    await _tap(tester, _tab('Profile'));
    await _pumpUntilFound(tester, find.byKey(const Key('profile_name_field')));
    await _snap(tester, '80_profile_edit');
  });

  await _step(tester, '81_profile_edit_scrolled', () async {
    final form = find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(Scrollable),
    );
    await tester.drag(form.first, const Offset(0, -800));
    await _settle(tester);
    await _snap(tester, '81_profile_edit_scrolled');
    await tester.drag(form.first, const Offset(0, 2000));
    await _settle(tester);
  });

  await _step(tester, '83_settings', () async {
    await _tap(tester, find.byKey(const Key('profile_settings_button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('settings_app_version')),
    );
    await _snap(tester, '83_settings');
  });

  await _step(tester, '85_settings_delete_dialog', () async {
    await _tap(tester, find.byKey(const Key('settings_delete_account')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('settings_delete_account_cancel')),
    );
    await _snap(tester, '85_settings_delete_dialog');
    await _tap(tester, find.byKey(const Key('settings_delete_account_cancel')));
  });
  await _back(tester);

  await _recover(tester);
}

// ---- Approve / deny in flight ---------------------------------------------

/// Real taps on the inbox buttons, photographed while the write is in flight.
/// After the screens above, because approving creates a match (a third chat)
/// and a decided request leaves the inbox.
Future<void> _captureInboxInFlight(WidgetTester tester, UxWorld world) async {
  final darioRequest = '${world.ownMealId}_${world.uids['dario']}';
  final faridPastRequest =
      '${world.mealIds['pastOpen']}_${world.uids['farid']}';
  final inbox = find.descendant(
    of: find.byType(Scaffold).last,
    matching: find.byType(Scrollable),
  );

  await _step(tester, '54_requests_approve_in_flight', () async {
    await _tap(tester, _tab('Requests'));
    await _pumpUntilFound(tester, find.text('Approve'));
    await tester.drag(inbox.first, const Offset(0, 2000));
    await _settle(tester);
    await _tapInFlight(
      tester,
      find.byKey(Key('request_inbox_approve_button_$darioRequest')),
      '54_requests_approve_in_flight',
      freeze: 'firestore',
    );
    await _settle(tester);
    await _clearSnackBars(tester);
  });

  await _step(tester, '55_requests_deny_in_flight', () async {
    await _tapInFlight(
      tester,
      find.byKey(Key('request_inbox_deny_button_$faridPastRequest')),
      '55_requests_deny_in_flight',
      freeze: 'firestore',
    );
    await _settle(tester);
    await _clearSnackBars(tester);
  });
  await _recover(tester);
}

// ---- Onboarding: a user with no profile -----------------------------------

/// Picks [year] in the open Material date picker (year grid) and confirms.
Future<void> _pickYear(WidgetTester tester, int year) async {
  final monthYear = find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'^[A-Z][a-z]+ \d{4}$').hasMatch(w.data ?? ''),
  );
  // Plan 17a: the picker opens on the year grid; tapping the header there
  // would flip it back to the calendar.
  if (find.byType(YearPicker).evaluate().isEmpty) {
    await _tap(tester, monthYear);
  }
  await _tap(tester, find.text('$year'));
  await _tap(tester, find.text('OK'));
}

Future<void> _captureOnboarding(WidgetTester tester, UxWorld world) async {
  final selectDob = find.text('Select date of birth');
  final adultYear = DateTime.now().year - 10;

  // A brand-new Auth user has no user doc, so the router sends them to the
  // age gate.
  await _step(tester, '10_age_gate', () async {
    await signInTestUser(uid: 'ux-newbie');
    await _pumpUntilFound(tester, selectDob);
    await _snap(tester, '10_age_gate');
  });

  await _step(tester, '11_age_gate_picker', () async {
    await _tap(tester, selectDob);
    await _pumpUntilFound(tester, find.text('OK'));
    await _snap(tester, '11_age_gate_picker');
  });

  // Under 18: a 10-year-old's birth year.
  await _step(tester, '12_age_gate_under18_selected', () async {
    await _pickYear(tester, adultYear);
    await _pumpUntilFound(tester, find.text('Continue'));
    await _snap(tester, '12_age_gate_under18_selected');
  });

  // Submitting signs the user out locally and the router sends them straight
  // back to sign-in: the "blocked" screen is never on screen for a frame the
  // harness can photograph, and there is no server round trip to hold (see
  // ux_audit/README.md).
  await _step(tester, 'under18_submit', () async {
    await _tap(tester, find.text('Continue'));
    await _pumpUntilFound(tester, find.byKey(const Key('signin_phone_field')));
    // Plan 17a: the sign-in screen tells them why (dismissible banner).
    await _pumpUntilFound(
      tester,
      find.text('You must be 18 or older to use Convyve.'),
    );
    await _snap(tester, '13_signin_underage_notice');
  });

  // The adult path: the picker's default date is exactly 18 years ago. The
  // Continue tap is photographed in flight (spinner in the button).
  await _step(tester, 'adult_path', () async {
    await signInTestUser(uid: 'ux-newbie');
    await _pumpUntilFound(tester, selectDob);
    await _tap(tester, selectDob);
    await _pumpUntilFound(tester, find.text('OK'));
    await _tap(tester, find.text('OK'));
    // (The age write is applied locally at once, so the router leaves the
    // age gate before any spinner could be photographed: no in-flight shot.)
    await _tap(tester, find.text('Continue'));
  });

  await _step(tester, '14_profile_setup_empty', () async {
    await _pumpUntilFound(tester, find.byKey(const Key('profile_name_field')));
    await _snap(tester, '14_profile_setup_empty');
  });

  // The photo picker is a native sheet, so the form is shown without a photo
  // first (Continue disabled) and then with one added by an admin write.
  await _step(tester, '15_profile_setup_filled', () async {
    await tester.enterText(
      find.byKey(const Key('profile_name_field')),
      'Noor Haddad',
    );
    await _tap(tester, find.text('Woman'));
    await tester.enterText(
      find.byKey(const Key('profile_bio_field')),
      'New to Paris and hungry for good company.',
    );
    await _settle(tester);
    await _snap(tester, '15_profile_setup_filled');
  });

  await _step(tester, '16_profile_setup_ready', () async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await adminUpdateDoc('users', uid, {
      'photoUrls': ['$kAvatarBase/ines.png'],
    });
    await _pumpUntilFound(tester, find.byKey(const Key('add_photo_tile')));
    // Plan 16b: the router is built once, so a user-doc write (here a photo)
    // no longer rebuilds the screen with an empty form. Report whether the
    // typed name survived; fill the form in again only if it did not.
    final nameField = find.descendant(
      of: find.byKey(const Key('profile_name_field')),
      matching: find.byType(EditableText),
    );
    final kept =
        tester.widget<EditableText>(nameField).controller.text ==
        'Noor Haddad';
    // Run-log result for the verification doc; dev tooling has no logger.
    // ignore: avoid_print
    print('UXCHECK router: profile form kept its input after a user-doc '
        'write: $kept');
    if (!kept) {
      await tester.enterText(
        find.byKey(const Key('profile_name_field')),
        'Noor Haddad',
      );
      await _tap(tester, find.text('Woman'));
    }
    await _snap(tester, '16_profile_setup_ready');
  });
}

// ---- Women-only meal as a non-woman ---------------------------------------

/// Discover hides women-only meals from men, so there is no UI path to the
/// disabled button. (Changing the gender of the signed-in viewer is no way
/// either.) Sign in as Dario and push the route with
/// the seeded meal.
Future<void> _captureWomenOnlyAsMan(WidgetTester tester, UxWorld world) async {
  await _step(tester, '46_meal_detail_women_only_disabled', () async {
    await signInTestUser(uid: 'ux-dario');
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('discovery_create_meal_button')),
    );
    unawaited(
      _router(tester).push('/meals/detail', extra: world.womenOnlyMeal),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('meal_detail_women_only_disabled_button')),
    );
    await _snap(tester, '46_meal_detail_women_only_disabled');
  });
}

// ---- Error states of the feeds (last stage before onboarding) -------------

/// One malformed doc per feed makes its repository stream throw
/// `RepositoryParseException` (see `seedMalformed`), which the screens render
/// as the shared ErrorState ("Couldn't load this"). Written one at a time and
/// only now, so they cannot affect any earlier shot: each poisoned feed stays
/// in its error state. Order matters: the chat first (it is opened from the
/// chats list, which is poisoned third).
Future<void> _captureFeedErrors(WidgetTester tester, UxWorld world) async {
  final error = find.text("Couldn't load this");

  await _step(tester, 'errors_viewer_signin', () async {
    await signInTestUser(uid: 'ux-viewer');
    // Since plan 16b the router is not rebuilt on a user change, so the
    // meal-detail route pushed for Dario stays on top: go to Discover.
    await _recover(tester);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('discovery_create_meal_button')),
    );
  });

  // Riverpod retries a failed provider (10 times, with a back-off of up to
  // 6.4 s, about 40 s in all) and shows its loading state in between; only
  // when the retries are exhausted does the error stay on screen. All four
  // feeds are poisoned together so that wait happens once.
  const retriesExhausted = Duration(seconds: 90);

  await _step(tester, '90_chat_error', () async {
    await _openChatFromList(tester, world.matchMealId);
    for (final kind in ['message', 'request', 'match', 'meal']) {
      await seedMalformed(kind, world);
    }
    await _pumpUntilFound(tester, error, timeout: retriesExhausted);
    await _snap(tester, '90_chat_error');
  });

  await _step(tester, '91_requests_error', () async {
    await _recover(tester);
    await _tap(tester, _tab('Requests'));
    await _pumpUntilFound(tester, error, timeout: retriesExhausted);
    await _snap(tester, '91_requests_error');
  });

  await _step(tester, '92_chats_error', () async {
    await _tap(tester, _tab('Chats'));
    await _pumpUntilFound(tester, error, timeout: retriesExhausted);
    await _snap(tester, '92_chats_error');
  });

  await _step(tester, '93_discover_error', () async {
    await _tap(tester, _tab('Discover'));
    await _pumpUntilFound(tester, error, timeout: retriesExhausted);
    await _snap(tester, '93_discover_error');
  });
}
