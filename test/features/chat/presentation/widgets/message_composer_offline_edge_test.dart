import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_composer.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockChat extends Mock implements ChatRepository {}

/// QA sweep 2026-10-09 (edge case 2, offline). Firestore completes a write's
/// Future only on server acknowledgement, so while offline `sendMessage`
/// stays pending. The composer must not hold the user hostage meanwhile.
/// Open bug: docs/bugs/2026-10-09-awaited-writes-block-ui-offline.md
void main() {
  late _MockAuth auth;
  late _MockChat chat;
  var serverAck = Completer<void>();

  setUp(() {
    auth = _MockAuth();
    chat = _MockChat();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    when(
      () => chat.sendMessage(
        matchId: any(named: 'matchId'),
        senderId: any(named: 'senderId'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) => serverAck.future);
  });

  Future<void> pump(WidgetTester tester) async {
    // Created here, inside the test's fake-async zone, so completing it
    // resumes the awaiting controller during `pump`.
    serverAck = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(chat),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(
            body: Center(child: MessageComposer(matchId: 'm')),
          ),
        ),
      ),
    );
  }

  testWidgets('online: send clears the field once the write is acknowledged', (
    tester,
  ) async {
    await pump(tester);
    serverAck.complete();
    await tester.enterText(
      find.byKey(const Key('message_composer_field')),
      'hello',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('message_composer_send_button')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    verify(
      () => chat.sendMessage(matchId: 'm', senderId: 'me', text: 'hello'),
    ).called(1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('message_composer_field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('offline (write never acknowledged): composer is free again', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const Key('message_composer_field')),
      'hello',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('message_composer_send_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    final field = tester.widget<TextField>(
      find.byKey(const Key('message_composer_field')),
    );
    // The queued message is already in the thread via the local cache, so the
    // draft must be cleared and a second message must be sendable.
    expect(field.controller!.text, isEmpty);
    serverAck.complete();
    await tester.pump();
  }, skip: true); // BUG awaited-writes-block-ui-offline
}
