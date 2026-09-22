/// One row in the Chats tab — the other participant's photo/name, a
/// last-message preview, a relative timestamp, and an unread dot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

/// "1m" / "2h" / "3d" / falls back to a short date beyond a week — kept as a
/// small private helper (same pattern as `meal_detail_screen.dart`'s
/// `_formatDateTime`) rather than a shared util, since this is the only
/// place that needs it.
String _relativeTime(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dateTime);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dateTime.month}/${dateTime.day}';
}

/// A single chat row. Watches [userDocProvider] for the other participant's
/// photo/name (tolerates loading/null with a placeholder) and
/// [chatMessagesProvider] for the last-message preview + unread state.
///
/// Unread is derived simply: the last message exists and was sent by the
/// other participant — a full compare against the viewer's own `reads` doc
/// is deferred (optional per the chat spec) since this dot is a secondary
/// affordance, not the read-receipt system of record.
class ChatListTile extends ConsumerWidget {
  const ChatListTile({required this.item, super.key});

  final ChatListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final user = ref.watch(userDocProvider(item.otherUid)).value;
    final messages =
        ref.watch(chatMessagesProvider(item.match.id)).value ??
            const <ChatMessage>[];
    final myUid = ref.watch(authStateProvider).value?.uid;

    final lastMessage = messages.isNotEmpty ? messages.last : null;
    final preview = lastMessage?.text ?? 'Say hi \u{1F44B}';
    final unread = lastMessage != null &&
        myUid != null &&
        lastMessage.senderId != myUid;

    final photoUrl =
        (user?.photoUrls.isNotEmpty ?? false) ? user!.photoUrls.first : null;
    final name = user?.displayName ?? 'Chat';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
      child: InkWell(
        key: Key('chat_list_tile_${item.match.id}'),
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        onTap: () => context.push('/chats/${item.match.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WarmPlayfulSpacing.s4,
            vertical: WarmPlayfulSpacing.s3,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: WarmPlayfulSpacing.s5,
                backgroundColor: colors.surfaceContainerHighest,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.person_rounded, color: colors.outline)
                    : null,
              ),
              const SizedBox(width: WarmPlayfulSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: WarmPlayfulType.h2Weight,
                      ),
                    ),
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastMessage?.createdAt != null)
                    Text(
                      _relativeTime(lastMessage!.createdAt!),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  if (unread) ...[
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Container(
                      key: Key('chat_list_tile_unread_${item.match.id}'),
                      width: WarmPlayfulSpacing.s2,
                      height: WarmPlayfulSpacing.s2,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
