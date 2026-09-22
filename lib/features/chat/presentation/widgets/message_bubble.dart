/// A single chat message bubble — mine right-aligned + primary-tinted,
/// theirs left-aligned + neutral. Shows a "Seen" marker under the sender's
/// own latest message once the other participant has read past it.
library;

import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';

/// "7:30 PM" — same shape as `meal_detail_screen.dart`'s `_formatDateTime`,
/// duplicated (not shared) since it's a small, presentation-only helper.
String _formatTime(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.mine,
    this.showSeen = false,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final bool showSeen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bubbleColor = mine ? colors.primaryContainer : colors.surface;
    final textColor = mine ? colors.onPrimaryContainer : colors.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            key: Key('message_bubble_${message.id}'),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: WarmPlayfulSpacing.s4,
              vertical: WarmPlayfulSpacing.s3,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
            ),
            child: Text(
              message.text,
              style: textTheme.bodyMedium?.copyWith(color: textColor),
            ),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s1),
          if (message.createdAt != null)
            Text(
              _formatTime(message.createdAt!),
              style: textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
          if (showSeen)
            Text(
              'Seen',
              style: textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
        ],
      ),
    );
  }
}
