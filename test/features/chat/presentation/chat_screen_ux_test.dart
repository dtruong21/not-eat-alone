import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
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
import 'package:not_eat_alone/features/chat/presentation/widgets/message_bubble.dart';
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

const _item = ChatListItem(
  match: Match(id: 'm1', mealId: 'm1', hostId: 'me', guestId: 'them'),
  otherUid: 'them',
);

Meal _meal(DateTime dateTime) => Meal(
  id: 'm1',
  hostId: 'me',
  restaurant: const Restaurant(
    placeId: 'p',
    name: 'Pizzeria Popolare',
    address: '1 rue de Test, Paris',
    lat: 48.85,
    lng: 2.35,
  ),
  dateTime: dateTime,
  geohash: 'u09tv',
);

ChatMessage _msg(int i, {DateTime? at, String? sender}) => ChatMessage(
  id: 'msg$i',
  matchId: 'm1',
  senderId: sender ?? (i.isEven ? 'me' : 'them'),
  text: 'message number $i',
  createdAt: at ?? DateTime(2027, 1, 5, 19).add(Duration(minutes: i * 10)),
);

/// UX plan 18, task 2: the chat's top third is no longer spent on safety
/// copy, the meal is named under the app bar, the thread has day separators
/// and run timestamps, and the post-meal prompt scrolls with the messages.
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
    List<ChatMessage>? messages,
    Size size = const Size(360, 800),
    double keyboard = 0,
    double textScale = 1,
    Meal? meal,
    Future<Meal?> Function()? mealLoader,
    Stream<List<ChatMessage>> Function()? stream,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/chats/m1',
      routes: [
        GoRoute(
          path: '/chats/:matchId',
          builder: (context, state) => const ChatScreen(matchId: 'm1'),
        ),
        GoRoute(
          path: '/chats',
          builder: (context, state) => const Scaffold(body: Text('chat list')),
        ),
        GoRoute(
          path: '/meals/detail',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${(state.extra! as Meal).id}')),
        ),
      ],
    );
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
          chatMessagesProvider('m1').overrideWith(
            (ref) =>
                stream?.call() ??
                Stream.value(messages ?? [for (var i = 0; i < 6; i++) _msg(i)]),
          ),
          otherReadProvider.overrideWith((ref, key) => Stream.value(null)),
          matchMealProvider.overrideWith(
            (ref, matchId) =>
                mealLoader != null ? mealLoader() : Future.value(meal),
          ),
          myRatingProvider.overrideWith((ref, matchId) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    // Skeleton on screen: never pumpAndSettle (docs/MASTER-SPEC.md gotcha 6).
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    if (stream != null) {
      // An error needs one more frame to replace the skeleton.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  group('safety tips banner (CHAT-01)', () {
    testWidgets('is one line, not a Card above the list', (tester) async {
      await pump(tester);

      final banner = find.byKey(const Key('safety_tips_banner'));
      expect(banner, findsOneWidget);
      expect(find.text('Meeting up? Safety tips'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Scaffold), matching: find.byType(Card)),
        findsNothing,
      );
      final height = tester.getSize(banner).height;
      expect(height, lessThanOrEqualTo(56), reason: '$height dp');
      expect(
        tester.getBottomLeft(banner).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const Key('chat_messages_list'))).dy,
        ),
      );
    });

    testWidgets('tapping it opens the sheet with the four tips', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Meeting up? Safety tips'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safety_tips_sheet')), findsOneWidget);
      expect(find.text('Meet in a public place'), findsOneWidget);
      expect(find.text("Tell a friend where you're going"), findsOneWidget);
      expect(find.text('Trust your instincts'), findsOneWidget);
      expect(find.text('You can block or report anytime'), findsOneWidget);
    });

    testWidgets('can be dismissed for this chat', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Dismiss safety tips'));
      await tester.pump();

      expect(find.byKey(const Key('safety_tips_banner')), findsNothing);
      expect(find.byKey(const Key('chat_messages_list')), findsOneWidget);
    });

    testWidgets('is hidden while the keyboard is open', (tester) async {
      await pump(tester, keyboard: 260);
      expect(find.byKey(const Key('safety_tips_banner')), findsNothing);
    });
  });

  testWidgets(
    '320x568 at 2.0x text with the keyboard up: thread >= 200 dp, composer visible',
    (tester) async {
      await pump(
        tester,
        size: const Size(320, 568),
        keyboard: 216,
        textScale: 2,
        meal: _meal(DateTime(2020)),
      );
      expect(tester.takeException(), isNull);

      final list = tester.getSize(find.byKey(const Key('chat_messages_list')));
      expect(list.height, greaterThanOrEqualTo(200), reason: '${list.height}');
      final composer = tester.getRect(
        find.byKey(const Key('message_composer_field')),
      );
      expect(composer.bottom, lessThanOrEqualTo(568 - 216));
      expect(composer.top, greaterThanOrEqualTo(0));
    },
  );

  group('meal header (CHAT-02)', () {
    final mealAt = DateTime.now().add(const Duration(days: 3));

    testWidgets('names the restaurant and the date, one line', (tester) async {
      await pump(tester, meal: _meal(mealAt));

      final label = 'Pizzeria Popolare · ${formatMealDateTime(mealAt)}';
      final header = find.byKey(const Key('chat_meal_header'));
      expect(header, findsOneWidget);
      expect(find.text(label), findsOneWidget);
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getTopLeft(header).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(AppBar)).dy - 0.5,
        ),
      );
    });

    testWidgets('tapping it opens the meal detail', (tester) async {
      await pump(tester, meal: _meal(mealAt));
      await tester.tap(find.byKey(const Key('chat_meal_header')));
      await tester.pumpAndSettle();

      expect(find.text('detail:m1'), findsOneWidget);
    });

    testWidgets('is absent when the meal is unavailable', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('chat_meal_header')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('is hidden while the keyboard is open', (tester) async {
      await pump(tester, meal: _meal(mealAt), keyboard: 260);
      expect(find.byKey(const Key('chat_meal_header')), findsNothing);
    });
  });

  group('day separators and run timestamps (CHAT-05)', () {
    testWidgets('Yesterday / Today separators, one time per run', (
      tester,
    ) async {
      final n = DateTime.now();
      final yesterday = DateTime(n.year, n.month, n.day - 1, 12);
      final today = DateTime(n.year, n.month, n.day, 12);
      await pump(
        tester,
        messages: [
          _msg(1, at: yesterday, sender: 'them'),
          _msg(
            2,
            at: yesterday.add(const Duration(minutes: 1)),
            sender: 'them',
          ),
          _msg(3, at: today, sender: 'me'),
        ],
      );

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      // msg1 and msg2 are one run: only msg2 shows 12:01; msg1's 12:00 is
      // hidden. msg3 shows 12:00 (so exactly one 12:00 on screen).
      expect(find.text('12:01'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
    });
  });

  testWidgets('the post-meal card scrolls with the messages', (tester) async {
    await pump(tester, meal: _meal(DateTime(2020)));

    final card = find.byKey(const Key('post_meal_card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('chat_messages_list')),
        matching: card,
      ),
      findsOneWidget,
    );
  });

  group('post-meal card and keyboard (audit P0)', () {
    testWidgets(
      '320x568, 2.0x, keyboard up, unrated past meal: a message and the '
      'composer stay on screen, the card steps aside',
      (tester) async {
        await pump(
          tester,
          size: const Size(320, 568),
          keyboard: 216,
          textScale: 2,
          meal: _meal(DateTime(2020)),
        );
        expect(tester.takeException(), isNull);

        expect(find.byKey(const Key('post_meal_card')), findsNothing);
        final bubble = find.byKey(const Key('message_bubble_msg5'));
        expect(bubble.hitTestable(), findsOneWidget);
        final composer = tester.getRect(
          find.byKey(const Key('message_composer_field')),
        );
        expect(composer.bottom, lessThanOrEqualTo(568 - 216));
        expect(tester.getRect(bubble).bottom, lessThanOrEqualTo(composer.top));
      },
    );

    testWidgets(
      '320x568, 2.0x, no keyboard, header + banner + composer + card: no '
      'overflow, a message is still visible',
      (tester) async {
        await pump(
          tester,
          size: const Size(320, 568),
          textScale: 2,
          meal: _meal(DateTime(2020)),
        );
        expect(tester.takeException(), isNull);

        expect(find.byKey(const Key('chat_meal_header')), findsOneWidget);
        expect(find.byKey(const Key('safety_tips_banner')), findsOneWidget);
        expect(
          find.byKey(const Key('message_composer_field')).hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(MessageBubble).hitTestable(), findsWidgets);
        // On this short viewport the prompt sits above the oldest message:
        // the thread comes first, the prompt is a scroll away.
        await tester.drag(
          find.byKey(const Key('chat_messages_list')),
          const Offset(0, 3000),
        );
        await tester.pump();
        expect(find.byKey(const Key('post_meal_card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    group('post_meal_prompt_shown fires once per chat', () {
      late List<String> logged;

      setUp(() {
        logged = [];
        analytics.debugSetForceSend(true);
        analytics.debugSetLogSink((name, params) async => logged.add(name));
      });
      tearDown(analytics.debugResetAnalytics);

      int shown() => logged.where((n) => n == 'post_meal_prompt_shown').length;

      testWidgets('scrolling the card out of view and back does not re-fire', (
        tester,
      ) async {
        await pump(
          tester,
          messages: [
            for (var i = 0; i < 80; i++)
              _msg(i, at: DateTime(2027, 1, 5, 9).add(Duration(hours: i))),
          ],
          meal: _meal(DateTime(2020)),
        );
        expect(find.byKey(const Key('post_meal_card')), findsOneWidget);
        expect(shown(), 1);

        final list = find.byKey(const Key('chat_messages_list'));
        // Fling to the oldest messages (a reversed list: drag down), far
        // enough that the card is well outside the cache extent...
        for (var i = 0; i < 6; i++) {
          await tester.drag(list, const Offset(0, 3000));
          await tester.pump();
        }
        expect(
          find.byKey(const Key('message_bubble_msg0')).hitTestable(),
          findsOneWidget,
        );
        // ...and back down to it.
        for (var i = 0; i < 6; i++) {
          await tester.drag(list, const Offset(0, -3000));
          await tester.pump();
        }

        expect(find.byKey(const Key('post_meal_card')), findsOneWidget);
        expect(shown(), 1);
      });

      testWidgets('the keyboard going up and down does not re-fire', (
        tester,
      ) async {
        await pump(tester, meal: _meal(DateTime(2020)));
        expect(shown(), 1);

        tester.view.viewInsets = const FakeViewPadding(bottom: 216);
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('post_meal_card')), findsNothing);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        await tester.pump();

        expect(find.byKey(const Key('post_meal_card')), findsOneWidget);
        expect(shown(), 1);
      });
    });
  });

  group('meal header: loading and unavailable states', () {
    testWidgets('absent (and no spinner) while the meal is loading', (
      tester,
    ) async {
      final never = Completer<Meal?>();
      await pump(tester, mealLoader: () => never.future);
      expect(find.byKey(const Key('chat_meal_header')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('absent for a cancelled match even if a meal is known', (
      tester,
    ) async {
      await pump(
        tester,
        meal: _meal(DateTime.now().add(const Duration(days: 3))),
        stream: () =>
            Stream<List<ChatMessage>>.error(Exception('permission-denied')),
      );
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(find.byKey(const Key('chat_meal_header')), findsNothing);
      expect(find.byKey(const Key('safety_tips_banner')), findsNothing);
    });
  });

  testWidgets('a thread that failed to load shows Retry and no composer', (
    tester,
  ) async {
    await pump(
      tester,
      stream: () => Stream<List<ChatMessage>>.error(StateError('boom')),
    );
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.byKey(const Key('message_composer_field')), findsNothing);
  });
}
