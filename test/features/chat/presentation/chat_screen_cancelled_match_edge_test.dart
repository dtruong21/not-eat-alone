import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_screen.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockChat extends Mock implements ChatRepository {}

/// QA sweep 2026-10-12: the other person cancelled / withdrew (cancelMatchedMeal)
/// or deleted their account, so `matches/{id}` and its messages are gone. Rules
/// answer every read and write under that match with PERMISSION_DENIED (the
/// participant check `get()`s a missing document). Opening such a chat (a stale
/// "You're in!" / reminder push, or a chat that was open when it happened)
/// must end in a clear "no longer available" state without an uncaught
/// error, because uncaught async errors are reported to Crashlytics as FATAL.
/// Bug: docs/bugs/closed/2026-10-12-chat-of-cancelled-match-shows-generic-error-and-reports-fatal.md
const _bug =
    'docs/bugs/closed/2026-10-12-chat-of-cancelled-match-shows-generic-error-and-reports-fatal.md';

void main() {
  late _MockAuth auth;
  late _MockChat chat;

  setUp(() {
    auth = _MockAuth();
    chat = _MockChat();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    // markRead on a deleted match: PERMISSION_DENIED, surfaced as the
    // repository's write exception.
    when(
      () => chat.markRead(
        matchId: any(named: 'matchId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer(
      (_) async => throw RepositoryWriteException(
        'reads',
        Exception('permission-denied'),
        StackTrace.current,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(chat),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          // The match no longer appears in the user's chat list.
          chatListProvider.overrideWith((ref) => Stream.value(const [])),
          chatMessagesProvider('m1').overrideWith(
            (ref) => Stream<List<Never>>.error(Exception('permission-denied')),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ChatScreen(matchId: 'm1'),
        ),
      ),
    );
    // Skeleton on screen while loading: never pumpAndSettle (MASTER-SPEC 6).
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('opening the chat of a deleted match raises no uncaught error', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull, reason: _bug);
  });

  testWidgets('a deleted match says the chat is no longer available', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(
      find.byKey(const Key('chat_unavailable_back_button')),
      findsOneWidget,
    );
  });

  testWidgets('a deleted match no longer offers the composer', (tester) async {
    await pump(tester);
    expect(
      find.byKey(const Key('message_composer_send_button')),
      findsNothing,
      reason: 'every send would be PERMISSION_DENIED. $_bug',
    );
  });
}
