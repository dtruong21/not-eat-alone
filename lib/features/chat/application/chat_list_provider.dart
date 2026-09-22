import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';

/// One row in the Chats tab.
class ChatListItem {
  const ChatListItem({
    required this.match,
    required this.otherUid,
    this.lastMessage,
    this.lastMessageAt,
    this.unread = false,
  });
  final Match match;
  final String otherUid;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool unread;
}

/// The signed-in user's matches as chat rows. Last-message/unread enrichment
/// is computed per row in the tile via chatMessagesProvider + the user's own
/// read doc; this provider supplies the base list (match + otherUid).
final chatListProvider = StreamProvider<List<ChatListItem>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(matchRepositoryProvider).watchMatchesForUser(uid).map(
        (matches) => matches
            .map((m) => ChatListItem(
                  match: m,
                  otherUid: m.hostId == uid ? m.guestId : m.hostId,
                ))
            .toList(growable: false),
      );
});
