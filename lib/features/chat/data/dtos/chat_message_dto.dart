import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_dto.freezed.dart';
part 'chat_message_dto.g.dart';

@freezed
abstract class ChatMessageDto with _$ChatMessageDto {
  const factory ChatMessageDto({
    required String id,
    required String matchId,
    required String senderId,
    required String text,
    DateTime? createdAt,
  }) = _ChatMessageDto;

  factory ChatMessageDto.fromJson(Map<String, Object?> json) =>
      _$ChatMessageDtoFromJson(json);
}
