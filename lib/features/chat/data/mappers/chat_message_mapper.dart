import 'package:not_eat_alone/features/chat/data/dtos/chat_message_dto.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';

extension ChatMessageDtoX on ChatMessageDto {
  ChatMessage toEntity() => ChatMessage(
        id: id, matchId: matchId, senderId: senderId, text: text,
        createdAt: createdAt,
      );
}

extension ChatMessageX on ChatMessage {
  ChatMessageDto toDto() => ChatMessageDto(
        id: id, matchId: matchId, senderId: senderId, text: text,
        createdAt: createdAt,
      );
}
