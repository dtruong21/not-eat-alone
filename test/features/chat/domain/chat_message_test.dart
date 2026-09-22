import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';

void main() {
  test('ChatMessage holds its fields; createdAt optional', () {
    const m = ChatMessage(id: 'x', matchId: 'm1', senderId: 'u1', text: 'hi');
    expect(m.text, 'hi');
    expect(m.createdAt, isNull);
    expect(m.copyWith(text: 'yo').text, 'yo');
  });
}
