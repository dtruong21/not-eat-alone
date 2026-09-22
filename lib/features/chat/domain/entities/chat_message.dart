import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String matchId,
    required String senderId,
    required String text,
    DateTime? createdAt,
  }) = _ChatMessage;
}
