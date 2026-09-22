import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';

abstract class ChatRepository {
  /// Realtime messages for [matchId], oldest-first.
  Stream<List<ChatMessage>> watchMessages(String matchId);

  /// Append a text message (createdAt = serverTimestamp).
  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String text,
  });

  /// Upsert the user's lastReadAt = now for [matchId].
  Future<void> markRead({required String matchId, required String uid});

  /// Watch a participant's read state (drives "Seen").
  Stream<MessageRead?> watchRead({required String matchId, required String uid});
}
