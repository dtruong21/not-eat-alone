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

/// CHAT-06: the composer empties the moment Send is tapped (the thread already
/// shows the message) and gives the text back if the send fails.
void main() {
  late _MockAuth auth;
  late _MockChat chat;
  late Completer<void> write;

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
    ).thenAnswer((_) => write.future);
  });

  Future<void> pump(WidgetTester tester) async {
    // Created inside the test's fake-async zone so completing it resumes the
    // awaiting controller during `pump`.
    write = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(chat),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(matchId: 'm'),
            ),
          ),
        ),
      ),
    );
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('message_composer_field')))
      .controller!
      .text;

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(const Key('message_composer_field')),
      text,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('message_composer_send_button')));
    await tester.pump();
  }

  testWidgets('the field is empty while the write is still in flight', (
    tester,
  ) async {
    await pump(tester);
    await typeAndSend(tester, 'hello');

    expect(fieldText(tester), isEmpty);
    // The send button keeps its spinner and key while sending.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const Key('message_composer_send_button')),
      findsOneWidget,
    );

    write.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('a failed send puts the text back and says so', (tester) async {
    await pump(tester);
    await typeAndSend(tester, 'hello');
    expect(fieldText(tester), isEmpty);

    write.completeError(Exception('nope'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fieldText(tester), 'hello');
    expect(find.text("Couldn't send your message. Try again."), findsOneWidget);
    // And Send works again.
    final button = tester.widget<IconButton>(
      find.byKey(const Key('message_composer_send_button')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'a failed send keeps text typed meanwhile after the restored one',
    (tester) async {
      await pump(tester);
      await typeAndSend(tester, 'first');
      await tester.enterText(
        find.byKey(const Key('message_composer_field')),
        'second',
      );
      await tester.pump();

      write.completeError(Exception('nope'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fieldText(tester), 'first second');
    },
  );
}
