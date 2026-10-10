import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_read_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_screen.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/rating/application/my_rating_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockChat extends Mock implements ChatRepository {}

class _MockUser extends Mock implements UserRepository {}

const _match = Match(id: 'm1', mealId: 'm1', hostId: 'me', guestId: 'them');
const _item = ChatListItem(match: _match, otherUid: 'them');

ChatMessage _msg(int i, {String? text}) => ChatMessage(
  id: 'msg$i',
  matchId: 'm1',
  senderId: i.isEven ? 'me' : 'them',
  text: text ?? 'message number $i',
  createdAt: DateTime(2027, 1, 5, 19).add(Duration(minutes: i)),
);

final _pastMeal = Meal(
  id: 'm1',
  hostId: 'me',
  restaurant: const Restaurant(
    placeId: 'p',
    name: 'Chez Test',
    address: '1 rue de Test, Paris',
    lat: 48.85,
    lng: 2.35,
  ),
  dateTime: DateTime(2020),
  geohash: 'u09tv',
);

/// QA sweep 2026-10-09 edge cases for the chat screen: long history, a
/// 2000-char message, and the keyboard-open layout on a small phone.
void main() {
  late _MockAuth auth;
  late _MockChat chat;
  late _MockUser users;

  setUpAll(loadAppFonts);

  setUp(() {
    auth = _MockAuth();
    chat = _MockChat();
    users = _MockUser();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    when(
      () => chat.markRead(
        matchId: any(named: 'matchId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async {});
    when(() => users.watch(any())).thenAnswer(
      (_) => Stream.value(
        AppUser(uid: 'them', dob: DateTime(1995), displayName: 'Amelie'),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required List<ChatMessage> messages,
    Size size = const Size(360, 640),
    double keyboard = 0,
    double textScale = 1,
    bool pastMeal = false,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(chat),
          userRepositoryProvider.overrideWithValue(users),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          chatListProvider.overrideWith((ref) => Stream.value(const [_item])),
          chatMessagesProvider(
            'm1',
          ).overrideWith((ref) => Stream.value(messages)),
          otherReadProvider.overrideWith((ref, key) => Stream.value(null)),
          matchMealProvider.overrideWith(
            (ref, matchId) async => pastMeal ? _pastMeal : null,
          ),
          myRatingProvider.overrideWith((ref, matchId) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: buildTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ChatScreen(matchId: 'm1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('120-message history builds lazily (ListView.builder)', (
    tester,
  ) async {
    await pump(tester, messages: [for (var i = 0; i < 120; i++) _msg(i)]);
    expect(tester.takeException(), isNull);
    // Only the visible window is built, not all 120 bubbles.
    final built = find.textContaining('message number').evaluate().length;
    expect(built, lessThan(40));
    expect(built, greaterThan(0));
  });

  testWidgets('a 2000-char message renders without overflow', (tester) async {
    await pump(
      tester,
      messages: [_msg(1, text: List.filled(2000, 'a').join())],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unbroken 2000-char token (no spaces) does not overflow', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(360, 800),
      messages: [
        _msg(1, text: 'x' * 2000),
        _msg(2, text: 'ok'),
      ],
    );
    expect(tester.takeException(), isNull);
  });

  // Fixed: docs/bugs/closed/2026-10-09-chat-keyboard-squeezes-message-list.md
  // The screen pins the safety-tips card (and, after the meal, the post-meal
  // card) above the thread in a non-scrolling Column.

  testWidgets('360x640, keyboard open: no overflow, thread stays readable', (
    tester,
  ) async {
    await pump(
      tester,
      messages: [for (var i = 0; i < 6; i++) _msg(i)],
      keyboard: 280,
    );
    expect(tester.takeException(), isNull);
    final listHeight = tester
        .getSize(find.byKey(const Key('chat_messages_list')))
        .height;
    expect(listHeight, greaterThanOrEqualTo(120));
  });

  testWidgets('360x800, 1.5x text, keyboard open, post-meal card shown', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(360, 800),
      messages: [for (var i = 0; i < 6; i++) _msg(i)],
      keyboard: 280,
      textScale: 1.5,
      pastMeal: true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('360x800, keyboard open, post-meal card: thread stays readable', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(360, 800),
      messages: [for (var i = 0; i < 6; i++) _msg(i)],
      keyboard: 280,
      pastMeal: true,
    );
    expect(tester.takeException(), isNull);
    final listHeight = tester
        .getSize(find.byKey(const Key('chat_messages_list')))
        .height;
    expect(listHeight, greaterThanOrEqualTo(120), reason: '$listHeight dp');
  });

  testWidgets('360x640, 1.5x text, no keyboard: no overflow', (tester) async {
    await pump(
      tester,
      messages: [for (var i = 0; i < 6; i++) _msg(i)],
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
  });
}
