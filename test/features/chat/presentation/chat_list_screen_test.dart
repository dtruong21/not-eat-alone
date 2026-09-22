import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_list_screen.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

const _match = Match(
  id: 'm1',
  mealId: 'm1',
  hostId: 'me',
  guestId: 'them',
);

const _item = ChatListItem(match: _match, otherUid: 'them');

final _otherUser = AppUser(
  uid: 'them',
  dob: DateTime(1995, 1, 1),
  displayName: 'Amélie',
);

void main() {
  late MockUserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('them'))
        .thenAnswer((_) => Stream.value(_otherUser));
  });

  Future<void> pumpChatList(
    WidgetTester tester, {
    required AsyncValue<List<ChatListItem>> chatListState,
  }) async {
    final router = GoRouter(
      initialLocation: '/chats',
      routes: [
        GoRoute(
          path: '/chats',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/chats/:matchId',
          builder: (context, state) =>
              Scaffold(body: Text('chat:${state.pathParameters['matchId']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          chatMessagesProvider('m1').overrideWith(
            (ref) => const Stream<List<ChatMessage>>.empty(),
          ),
          chatListProvider.overrideWith(
            (ref) => switch (chatListState) {
              AsyncData(:final value) => Stream.value(value),
              AsyncError(:final error) => Stream.error(error),
              _ => const Stream.empty(),
            },
          ),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('empty chat list shows the empty state', (tester) async {
    await pumpChatList(tester, chatListState: const AsyncData([]));

    expect(
      find.text('No chats yet — match on a meal to start talking'),
      findsOneWidget,
    );
  });

  testWidgets('one item shows the other participant name', (tester) async {
    await pumpChatList(tester, chatListState: const AsyncData([_item]));

    expect(find.textContaining('Amélie'), findsOneWidget);
  });

  testWidgets('tapping a tile navigates to /chats/:matchId', (tester) async {
    await pumpChatList(tester, chatListState: const AsyncData([_item]));

    await tester.tap(find.byKey(const Key('chat_list_tile_m1')));
    await tester.pumpAndSettle();

    expect(find.text('chat:m1'), findsOneWidget);
  });

  testWidgets('error state renders an error message', (tester) async {
    await pumpChatList(
      tester,
      chatListState: AsyncError(StateError('boom'), StackTrace.empty),
    );

    expect(
      find.text('Something went wrong — please try again.'),
      findsOneWidget,
    );
  });
}
