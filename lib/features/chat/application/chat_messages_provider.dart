import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';

/// Realtime thread for [matchId]. Auto-disposed (listener closes when the
/// chat screen goes away) and tied to the signed-in uid (sign-out closes it).
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, matchId) {
      switch (watchSession(ref)) {
        case SessionState.resolving:
          return const Stream.empty();
        case SessionState.signedOut:
          return Stream.value(const <ChatMessage>[]);
        case SessionState.signedIn:
          break;
      }
      return ref.watch(chatRepositoryProvider).watchMessages(matchId);
    });

/// Only the newest message of [matchId], for the chat list preview. A
/// `limit(1)` query, so the list does not download every match's full history.
final lastMessageProvider = StreamProvider.autoDispose
    .family<ChatMessage?, String>((ref, matchId) {
      switch (watchSession(ref)) {
        case SessionState.resolving:
          return const Stream.empty();
        case SessionState.signedOut:
          return Stream.value(null);
        case SessionState.signedIn:
          break;
      }
      return ref.watch(chatRepositoryProvider).watchLastMessage(matchId);
    });
