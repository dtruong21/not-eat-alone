import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

const _match = Match(id: 'm1', mealId: 'm1', hostId: 'me', guestId: 'them');
const _item = ChatListItem(match: _match, otherUid: 'them');

void main() {
  late MockUserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('them')).thenAnswer(
      (_) => Stream.value(
        AppUser(uid: 'them', dob: DateTime(1995), displayName: 'Amélie'),
      ),
    );
  });

  Future<void> pumpTile(WidgetTester tester, DateTime createdAt) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          chatMessagesProvider('m1').overrideWith(
            (ref) => Stream.value([
              ChatMessage(
                id: 'x',
                matchId: 'm1',
                senderId: 'them',
                text: 'hi',
                createdAt: createdAt,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: ChatListTile(item: _item)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  DateTime ago(Duration d) => DateTime.now().toUtc().subtract(d);

  testWidgets('a message from seconds ago reads "now"', (tester) async {
    await pumpTile(tester, ago(const Duration(seconds: 5)));
    expect(find.text('now'), findsOneWidget);
  });

  testWidgets('minutes ago reads "Xm"', (tester) async {
    await pumpTile(tester, ago(const Duration(minutes: 5, seconds: 10)));
    expect(find.text('5m'), findsOneWidget);
  });

  testWidgets('hours ago reads "Xh"', (tester) async {
    await pumpTile(tester, ago(const Duration(hours: 3, minutes: 10)));
    expect(find.text('3h'), findsOneWidget);
  });

  testWidgets('days ago reads "Xd"', (tester) async {
    await pumpTile(tester, ago(const Duration(days: 2, hours: 1)));
    expect(find.text('2d'), findsOneWidget);
  });

  testWidgets('a week or older falls back to the local M/D date', (
    tester,
  ) async {
    final createdAt = ago(const Duration(days: 10));
    await pumpTile(tester, createdAt);

    // Independent derivation (no toLocal on the instant under test). On a UTC
    // machine this degenerates to UTC; CI also runs this file under
    // TZ=Pacific/Kiritimati (UTC+14) so it cannot pass vacuously.
    final shifted = createdAt.add(createdAt.toLocal().timeZoneOffset);
    expect(find.text('${shifted.month}/${shifted.day}'), findsOneWidget);
  });
}
