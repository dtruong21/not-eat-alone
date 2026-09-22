import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, matchId) {
  return ref.watch(chatRepositoryProvider).watchMessages(matchId);
});
