import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  Future<void> pumpBubble(WidgetTester tester, ChatMessage message) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: MessageBubble(message: message, mine: true)),
      ),
    );
  }

  testWidgets("shows a UTC createdAt in the viewer's local time",
      (tester) async {
    final createdAt = DateTime.utc(2027, 1, 5, 18, 30);
    await pumpBubble(
      tester,
      ChatMessage(
        id: 'a',
        matchId: 'm1',
        senderId: 'me',
        text: 'hello',
        createdAt: createdAt,
      ),
    );

    expect(find.text(formatClockTime(createdAt)), findsOneWidget);
    // Explicit local derivation (degenerates to UTC on a UTC machine).
    final local = createdAt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    expect(find.text('$hour12:$minute $period'), findsOneWidget);
  });

  testWidgets('shows no time when createdAt is not yet set', (tester) async {
    await pumpBubble(
      tester,
      const ChatMessage(id: 'b', matchId: 'm1', senderId: 'me', text: 'hi'),
    );

    expect(find.text('hi'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+:\d\d (AM|PM)')), findsNothing);
  });
}
