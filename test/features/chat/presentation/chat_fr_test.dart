import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
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
import 'package:not_eat_alone/features/chat/presentation/chat_list_screen.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_screen.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/rating/application/my_rating_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockChat extends Mock implements ChatRepository {}

class _MockUsers extends Mock implements UserRepository {}

class _MockMatches extends Mock implements MatchRepository {}

const _match = Match(id: 'm1', mealId: 'm1', hostId: 'me', guestId: 'them');
const _item = ChatListItem(match: _match, otherUid: 'them');

const _longName = "Marie-Charlotte d'Aubigné-O'Brien de Castelnau";

const _restaurant = Restaurant(
  placeId: 'p1',
  name: "L'Auberge de la Grande Fontaine Saint-Honoré",
  address: '1 Rue X',
  lat: 0,
  lng: 0,
);

Meal _meal({bool host = true}) => Meal(
  id: 'm1',
  hostId: host ? 'me' : 'them',
  guestId: host ? 'them' : 'me',
  restaurant: _restaurant,
  dateTime: DateTime.now().add(const Duration(days: 3)),
  geohash: 'abc',
  status: MealStatus.matched,
);

ChatMessage _msg(String id, String sender, String text, DateTime at) =>
    ChatMessage(
      id: id,
      matchId: 'm1',
      senderId: sender,
      text: text,
      createdAt: at,
    );

void main() {
  setUpAll(loadAppFonts);

  late _MockAuth auth;
  late _MockChat chat;
  late _MockUsers users;
  late _MockMatches matches;

  setUp(() {
    auth = _MockAuth();
    chat = _MockChat();
    users = _MockUsers();
    matches = _MockMatches();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    when(
      () => chat.markRead(
        matchId: any(named: 'matchId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => chat.sendMessage(
        matchId: any(named: 'matchId'),
        senderId: any(named: 'senderId'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => matches.cancelMatchedMeal(mealId: any(named: 'mealId')),
    ).thenAnswer((_) async {});
    when(() => users.watch('them')).thenAnswer(
      (_) => Stream.value(
        AppUser(
          uid: 'them',
          dob: DateTime(1995),
          displayName: _longName,
          age: 31,
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required Widget home,
    List<ChatMessage> messages = const [],
    Object? messagesError,
    Meal? meal,
    List<ChatListItem> chats = const [_item],
    Stream<ChatMessage?>? last,
    bool narrow = false,
    double textScale = 1,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = narrow ? const Size(320, 640) : const Size(390, 844);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/chats',
          builder: (_, _) => const Scaffold(body: Text('chat list')),
        ),
        GoRoute(
          path: '/discover',
          builder: (_, _) => const Scaffold(body: Text('discover')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(chat),
          userRepositoryProvider.overrideWithValue(users),
          matchRepositoryProvider.overrideWithValue(matches),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          chatListProvider.overrideWith((ref) => Stream.value(chats)),
          chatMessagesProvider('m1').overrideWith(
            (ref) => messagesError != null
                ? Stream<List<ChatMessage>>.error(messagesError)
                : Stream.value(messages),
          ),
          lastMessageProvider(
            'm1',
          ).overrideWith((ref) => last ?? Stream.value(messages.lastOrNull)),
          otherReadProvider.overrideWith(
            (ref, key) => Stream.value(
              MessageRead(uid: key.otherUid, lastReadAt: DateTime.now()),
            ),
          ),
          matchMealProvider.overrideWith((ref, id) async => meal),
          myRatingProvider.overrideWith((ref, id) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildTheme(Brightness.light),
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  const chatScreen = ChatScreen(matchId: 'm1');
  const chatList = ChatListScreen();

  group('chat list', () {
    testWidgets('empty state is French', (tester) async {
      await pump(tester, home: chatList, chats: const []);

      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Pas encore de discussion'), findsOneWidget);
      expect(
        find.text('Fais un match sur un repas pour lancer la discussion.'),
        findsOneWidget,
      );
      expect(find.text('Trouver un repas'), findsOneWidget);
      for (final english in ['Chats', 'No chats yet', 'Find a meal']) {
        expect(find.text(english), findsNothing);
      }
      await tester.tap(find.text('Trouver un repas'));
      await tester.pumpAndSettle();
      expect(find.text('discover'), findsOneWidget);
    });

    testWidgets('row: preview, relative time and unread label are French', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        home: chatList,
        meal: _meal(),
        last: Stream.value(
          _msg(
            'x',
            'them',
            'salut',
            DateTime.now().subtract(const Duration(hours: 3, minutes: 5)),
          ),
        ),
      );

      expect(find.text(_longName), findsOneWidget);
      expect(find.text('3\u00a0h'), findsOneWidget);
      expect(find.text('salut'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Non lu',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('· '), findsOneWidget);
      expect(find.text('3h'), findsNothing);
      expect(find.text('Unread'), findsNothing);
      semantics.dispose();
    });

    // One test per row: a second pumpWidget would reuse the first
    // ProviderScope and keep its cached last-message stream.
    final cases = <Duration, String>{
      const Duration(seconds: 5): 'à l’instant',
      const Duration(minutes: 1, seconds: 10): '1\u00a0min',
      const Duration(minutes: 42): '42\u00a0min',
      const Duration(hours: 1, minutes: 1): '1\u00a0h',
      const Duration(days: 2, hours: 1): '2\u00a0j',
    };
    for (final entry in cases.entries) {
      testWidgets('relative time ${entry.value}', (tester) async {
        await pump(
          tester,
          home: chatList,
          last: Stream.value(
            _msg('x', 'them', 'hi', DateTime.now().subtract(entry.key)),
          ),
        );
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('a message older than a week shows a French short date', (
      tester,
    ) async {
      final old = DateTime(2026, 1, 5, 10);
      await pump(
        tester,
        home: chatList,
        last: Stream.value(_msg('x', 'them', 'hi', old)),
      );
      expect(find.text('5 janv.'), findsOneWidget);
    });

    testWidgets('a chat with no message says hi in French', (tester) async {
      await pump(tester, home: chatList);
      expect(find.text('Dis bonjour 👋'), findsOneWidget);
      expect(find.text('Say hi 👋'), findsNothing);
    });

    testWidgets('long names and meal line do not overflow at 320 px, 2.0x', (
      tester,
    ) async {
      await pump(
        tester,
        home: chatList,
        meal: _meal(),
        narrow: true,
        textScale: 2,
        last: Stream.value(
          _msg(
            'x',
            'them',
            'Un message assez long pour tester la troncature',
            DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('30\u00a0min'), findsOneWidget);
    });
  });

  group('chat screen', () {
    // Start of today / yesterday: always past, so never flaky at midnight.
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final thread = [
      _msg('a', 'them', 'Salut !', DateTime(now.year, now.month, now.day - 1)),
      _msg('b', 'me', 'À ce soir', now),
    ];

    testWidgets('header, separators, seen, composer and banner in French', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, home: chatScreen, messages: thread, meal: _meal());

      expect(find.text(_longName), findsOneWidget);
      expect(find.byKey(const Key('chat_meal_header')), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('Aujourd’hui'), findsOneWidget);
      expect(find.text('Vu'), findsOneWidget);
      expect(find.text('Seen'), findsNothing);
      expect(find.text('Message'), findsOneWidget);
      expect(find.byTooltip('Envoyer le message'), findsOneWidget);
      expect(find.byTooltip('Je ne peux pas venir'), findsOneWidget);
      expect(
        find.text('Bientôt à table\u00a0? Conseils de sécurité'),
        findsOneWidget,
      );
      expect(find.byTooltip('Fermer les conseils de sécurité'), findsOneWidget);
      expect(find.text('Meeting up? Safety tips'), findsNothing);
      expect(find.byTooltip('Send message'), findsNothing);
      semantics.dispose();
    });

    testWidgets('the safety sheet is French and the banner can be closed', (
      tester,
    ) async {
      await pump(tester, home: chatScreen, messages: thread, meal: _meal());

      await tester.tap(
        find.text('Bientôt à table\u00a0? Conseils de sécurité'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Bientôt à table\u00a0? Reste en sécurité'),
        findsOneWidget,
      );
      expect(
        find.text('Donne rendez-vous dans un lieu public'),
        findsOneWidget,
      );
      expect(
        find.text('Préviens un proche de l’endroit où tu vas'),
        findsOneWidget,
      );
      expect(find.text('Fie-toi à ton instinct'), findsOneWidget);
      expect(
        find.text('Tu peux bloquer ou signaler à tout moment'),
        findsOneWidget,
      );
      expect(find.text('Compris'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
      expect(find.text('Meet in a public place'), findsNothing);

      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fermer les conseils de sécurité'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety_tips_banner')), findsNothing);
    });

    testWidgets('an empty thread says hi in French', (tester) async {
      await pump(tester, home: chatScreen, meal: _meal());
      expect(find.text('Dis bonjour 👋'), findsOneWidget);
    });

    testWidgets('a failed send shows the French snackbar', (tester) async {
      when(
        () => chat.sendMessage(
          matchId: any(named: 'matchId'),
          senderId: any(named: 'senderId'),
          text: any(named: 'text'),
        ),
      ).thenThrow(StateError('boom'));
      await pump(tester, home: chatScreen, messages: thread, meal: _meal());

      await tester.enterText(
        find.byKey(const Key('message_composer_field')),
        'Coucou',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('message_composer_send_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible d’envoyer ton message. Réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled match shows the French unavailable state', (
      tester,
    ) async {
      await pump(
        tester,
        home: chatScreen,
        messagesError: RepositoryReadException(
          'messages',
          Exception('permission-denied'),
          StackTrace.current,
        ),
      );
      expect(
        find.text(
          'Cette discussion n’est plus disponible — le repas a été annulé.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retour aux messages'), findsOneWidget);
      expect(find.text('Back to chats'), findsNothing);
      await tester.tap(find.byKey(const Key('chat_unavailable_back_button')));
      await tester.pumpAndSettle();
      expect(find.text('chat list'), findsOneWidget);
    });

    testWidgets('French strings do not overflow at 320 px and 2.0x', (
      tester,
    ) async {
      await pump(
        tester,
        home: chatScreen,
        messages: [
          ...thread,
          _msg('c', 'them', 'Un message très long ' * 12, now),
        ],
        meal: _meal(),
        narrow: true,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chat_meal_header')), findsOneWidget);
    });

    testWidgets('the unavailable state does not overflow at 320 px, 2.0x', (
      tester,
    ) async {
      await pump(
        tester,
        home: chatScreen,
        messagesError: RepositoryReadException(
          'messages',
          Exception('permission-denied'),
          StackTrace.current,
        ),
        narrow: true,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Retour aux messages'), findsOneWidget);
    });
  });

  group('leave the meal', () {
    Future<void> open(WidgetTester tester, {required bool host}) async {
      await pump(
        tester,
        home: chatScreen,
        meal: _meal(host: host),
      );
      await tester.tap(find.byKey(const Key('leave_match_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('host dialog and snackbar are French', (tester) async {
      await open(tester, host: true);

      expect(find.text('Annuler ce repas\u00a0?'), findsOneWidget);
      expect(
        find.text('On préviendra $_longName et le repas sera supprimé.'),
        findsOneWidget,
      );
      expect(find.text('Garder le repas'), findsOneWidget);
      expect(find.text('Annuler le repas'), findsOneWidget);
      expect(find.text('Keep meal'), findsNothing);

      await tester.tap(find.byKey(const Key('leave_match_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Repas annulé.'), findsOneWidget);
    });

    testWidgets('guest dialog and snackbar are French', (tester) async {
      await open(tester, host: false);

      expect(find.text('Te retirer de ce repas\u00a0?'), findsOneWidget);
      expect(
        find.text(
          'On préviendra $_longName et le repas sera de nouveau ouvert '
          'aux autres.',
        ),
        findsOneWidget,
      );
      expect(find.text('Me retirer'), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave_match_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Tu as annulé ta participation.'), findsOneWidget);
    });

    testWidgets('a failed cancel shows the French snackbar', (tester) async {
      when(
        () => matches.cancelMatchedMeal(mealId: any(named: 'mealId')),
      ).thenThrow(StateError('boom'));
      await open(tester, host: true);

      await tester.tap(find.byKey(const Key('leave_match_confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text('Annulation impossible. Vérifie ta connexion et réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('Keep meal closes the dialog', (tester) async {
      await open(tester, host: true);
      await tester.tap(find.byKey(const Key('leave_match_keep')));
      await tester.pumpAndSettle();
      expect(find.text('Annuler ce repas\u00a0?'), findsNothing);
    });

    testWidgets('the dialog does not overflow at 320 px and 2.0x', (
      tester,
    ) async {
      await pump(
        tester,
        home: chatScreen,
        meal: _meal(host: false),
        narrow: true,
        textScale: 2,
      );
      await tester.tap(find.byKey(const Key('leave_match_button')));
      await tester.pumpAndSettle();
      expect(find.text('Te retirer de ce repas\u00a0?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
