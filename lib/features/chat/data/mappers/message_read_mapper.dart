import 'package:not_eat_alone/features/chat/data/dtos/message_read_dto.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';

extension MessageReadDtoX on MessageReadDto {
  MessageRead toEntity() => MessageRead(uid: uid, lastReadAt: lastReadAt);
}

extension MessageReadX on MessageRead {
  MessageReadDto toDto() => MessageReadDto(uid: uid, lastReadAt: lastReadAt);
}
