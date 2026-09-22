import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/notifications/push_listener.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';

/// Pumps a bare [PushListener] with every `FirebaseMessaging`-derived seam
/// stubbed (so no real plugin/`Firebase.initializeApp()` is ever touched)
/// and signed out (so the register-on-mount side effect is a no-op). Tests
/// override [foreground] and [navigate] as needed.
Future<PushListenerState> _pumpListener(
  WidgetTester tester, {
  Stream<RemoteMessage>? foreground,
  void Function(String location)? navigate,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        foregroundPushMessagesProvider.overrideWithValue(
          foreground ?? const Stream<RemoteMessage>.empty(),
        ),
        openedPushMessagesProvider
            .overrideWithValue(const Stream<RemoteMessage>.empty()),
        initialPushMessageProvider.overrideWithValue(() async => null),
        if (navigate != null) pushNavigateProvider.overrideWithValue(navigate),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(body: PushListener(child: SizedBox.shrink())),
      ),
    ),
  );
  await tester.pump();
  return tester.state<PushListenerState>(find.byType(PushListener));
}

void main() {
  testWidgets(
    'handlePayload maps a message payload and navigates to the chat',
    (tester) async {
      final navigated = <String>[];
      final state = await _pumpListener(tester, navigate: navigated.add);

      state.handlePayload({'type': 'message', 'matchId': 'm1'});

      expect(navigated, ['/chats/m1']);
    },
  );

  testWidgets(
    'handlePayload no-ops (no navigation, no throw) for an unknown type',
    (tester) async {
      final navigated = <String>[];
      final state = await _pumpListener(tester, navigate: navigated.add);

      expect(
        () => state.handlePayload({'type': 'unknown'}),
        returnsNormally,
      );
      expect(navigated, isEmpty);
    },
  );

  testWidgets(
    'handlePayload no-ops for a payload with no type at all',
    (tester) async {
      final navigated = <String>[];
      final state = await _pumpListener(tester, navigate: navigated.add);

      state.handlePayload(const {});

      expect(navigated, isEmpty);
    },
  );

  testWidgets(
    'a foreground message shows a SnackBar with its title and body',
    (tester) async {
      final controller = StreamController<RemoteMessage>.broadcast();
      addTearDown(controller.close);

      await _pumpListener(tester, foreground: controller.stream);

      controller.add(
        const RemoteMessage(
          data: {'type': 'message', 'matchId': 'm1'},
          notification: RemoteNotification(
            title: 'New message',
            body: 'Alex sent you a message',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('New message — Alex sent you a message'),
        findsOneWidget,
      );
    },
  );
}
