import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_read_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_screen.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/rating/application/my_rating_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockUserRepository extends Mock implements UserRepository {}

const _match = Match(id: 'm1', mealId: 'm1', hostId: 'me', guestId: 'them');
const _item = ChatListItem(match: _match, otherUid: 'them');

final _otherUser = AppUser(
  uid: 'them',
  dob: DateTime(1995, 1, 1),
  displayName: 'Amélie',
);

final _theirMessage = ChatMessage(
  id: 'msg1',
  matchId: 'm1',
  senderId: 'them',
  text: 'hi there',
  createdAt: DateTime(2027, 1, 5, 19, 29),
);

final _myMessage = ChatMessage(
  id: 'msg2',
  matchId: 'm1',
  senderId: 'me',
  text: 'hey!',
  createdAt: DateTime(2027, 1, 5, 19, 30),
);

void main() {
  late MockAuthRepository authRepository;
  late MockChatRepository chatRepository;
  late MockUserRepository userRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    chatRepository = MockChatRepository();
    userRepository = MockUserRepository();

    when(() => authRepository.currentUser)
        .thenReturn(const AuthUser(uid: 'me'));
    when(() => chatRepository.markRead(
          matchId: any(named: 'matchId'),
          uid: any(named: 'uid'),
        )).thenAnswer((_) async {});
    when(() => chatRepository.sendMessage(
          matchId: any(named: 'matchId'),
          senderId: any(named: 'senderId'),
          text: any(named: 'text'),
        )).thenAnswer((_) async {});
    when(() => userRepository.watch('them'))
        .thenAnswer((_) => Stream.value(_otherUser));
  });

  Future<void> pumpChatScreen(
    WidgetTester tester, {
    DateTime? otherLastReadAt,
    Stream<List<ChatMessage>> Function()? messages,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          chatRepositoryProvider.overrideWithValue(chatRepository),
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          chatListProvider.overrideWith(
            (ref) => Stream.value(const [_item]),
          ),
          chatMessagesProvider('m1').overrideWith(
            (ref) => messages != null
                ? messages()
                : Stream.value([_theirMessage, _myMessage]),
          ),
          otherReadProvider.overrideWith(
            (ref, key) => Stream.value(
              MessageRead(
                uid: key.otherUid,
                lastReadAt: otherLastReadAt ?? DateTime(2027),
              ),
            ),
          ),
          // The post-meal card's own providers — stubbed out so the widget
          // tree never reaches the real Firestore-backed repositories (no
          // Firebase app is initialized in these widget tests). Returning no
          // meal keeps `PostMealCard` self-hidden, which is the behaviour
          // these existing tests (no meal past-due) expect anyway.
          matchMealProvider.overrideWith((ref, matchId) async => null),
          myRatingProvider.overrideWith((ref, matchId) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ChatScreen(matchId: 'm1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders both my and their message bubbles', (tester) async {
    await pumpChatScreen(
      tester,
      otherLastReadAt: DateTime(2027, 1, 5, 19, 31),
    );

    expect(find.text('hi there'), findsOneWidget);
    expect(find.text('hey!'), findsOneWidget);
  });

  testWidgets(
    'shows "Seen" under my latest message once the other has read past it',
    (tester) async {
      await pumpChatScreen(
        tester,
        otherLastReadAt: DateTime(2027, 1, 5, 19, 31),
      );

      expect(find.text('Seen'), findsOneWidget);
    },
  );

  testWidgets(
    'does not show "Seen" when the other has not read my latest message yet',
    (tester) async {
      await pumpChatScreen(
        tester,
        otherLastReadAt: DateTime(2027, 1, 5, 19, 29, 30),
      );

      expect(find.text('Seen'), findsNothing);
    },
  );

  testWidgets(
    'composer send button is disabled empty, enabled after typing',
    (tester) async {
      await pumpChatScreen(
        tester,
        otherLastReadAt: DateTime(2027, 1, 5, 19, 31),
      );

      final sendButtonKey = find.byKey(
        const Key('message_composer_send_button'),
      );
      var button = tester.widget<IconButton>(sendButtonKey);
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('message_composer_field')),
        'hello',
      );
      await tester.pump();

      button = tester.widget<IconButton>(sendButtonKey);
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('loading shows message skeletons, not a spinner', (tester) async {
    await pumpChatScreen(
      tester,
      messages: () => const Stream<List<ChatMessage>>.empty(),
    );

    expect(find.byType(SkeletonMessages), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no messages shows the Say hi empty state', (tester) async {
    await pumpChatScreen(tester, messages: () => Stream.value(const []));

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Say hi \u{1F44B}'), findsOneWidget);
  });

  testWidgets('error shows ErrorState; Try again re-fetches the messages', (
    tester,
  ) async {
    var calls = 0;
    await pumpChatScreen(
      tester,
      messages: () => ++calls == 1
          ? Stream<List<ChatMessage>>.error(StateError('boom'))
          : Stream.value([_theirMessage]),
    );
    expect(find.byType(ErrorState), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('hi there'), findsOneWidget);
  });
}
