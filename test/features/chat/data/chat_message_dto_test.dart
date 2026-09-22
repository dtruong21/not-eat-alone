import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/chat/data/dtos/chat_message_dto.dart';
import 'package:not_eat_alone/features/chat/data/mappers/chat_message_mapper.dart';

void main() {
  test('round-trips with null createdAt', () {
    final dto = ChatMessageDto(id: 'x', matchId: 'm1', senderId: 'u1', text: 'hi');
    final back = ChatMessageDto.fromJson(dto.toJson());
    expect(back.toEntity().text, 'hi');
    expect(back.toEntity().createdAt, isNull);
  });
}
