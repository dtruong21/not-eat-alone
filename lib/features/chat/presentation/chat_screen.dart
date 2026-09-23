/// Chat screen (`/chats/:matchId`) — realtime messages for one match, plus
/// the pinned composer.
///
/// The other participant's uid isn't in the route (only `matchId` is), so it
/// is looked up from [chatListProvider] — the signed-in user's matches,
/// already computed as `(match, otherUid)` pairs for the Chats tab — by
/// finding the row whose `match.id` equals this screen's `matchId`. This
/// reuses an existing provider instead of adding a new one, and gives the
/// app bar the other participant's name/photo even before any message has
/// been exchanged.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_controller.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_read_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_bubble.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_composer.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/post_meal_card.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_actions.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_tips_card.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

String? _otherUidFor(List<ChatListItem> items, String matchId) {
  for (final item in items) {
    if (item.match.id == matchId) return item.otherUid;
  }
  return null;
}

/// The id of the sender's own most recent message, or `null` if they haven't
/// sent one yet. Messages are ascending by `createdAt`.
String? _myLatestMessageId(List<ChatMessage> messages, String? myUid) {
  if (myUid == null) return null;
  for (final message in messages.reversed) {
    if (message.senderId == myUid) return message.id;
  }
  return null;
}

/// True once the other participant's last read timestamp is at or after
/// [message]'s send time. Pending (not-yet-server-timestamped) messages
/// never show "Seen".
bool _isSeenBy(ChatMessage message, MessageRead? otherRead) {
  final createdAt = message.createdAt;
  final lastReadAt = otherRead?.lastReadAt;
  if (createdAt == null || lastReadAt == null) return false;
  return !lastReadAt.isBefore(createdAt);
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // `initState` runs exactly once per screen instance, so this already
    // fires "once" without an extra guard flag.
    unawaited(analytics.track(const ChatOpened()));
    unawaited(
      ref.read(chatControllerProvider.notifier).markRead(widget.matchId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final myUid = ref.watch(authStateProvider).value?.uid;
    final chatItems =
        ref.watch(chatListProvider).value ?? const <ChatListItem>[];
    final otherUid = _otherUidFor(chatItems, widget.matchId);

    final messagesAsync = ref.watch(chatMessagesProvider(widget.matchId));

    // Mark read again whenever a new inbound message arrives while this
    // screen is open — the initial `markRead` in `initState` only covers
    // messages that existed on open.
    ref.listen<AsyncValue<List<ChatMessage>>>(
      chatMessagesProvider(widget.matchId),
      (previous, next) {
        final messages = next.value;
        if (messages == null || messages.isEmpty) return;
        final previousCount = previous?.value?.length ?? 0;
        if (messages.length <= previousCount) return;
        final last = messages.last;
        if (myUid != null && last.senderId != myUid) {
          ref.read(chatControllerProvider.notifier).markRead(widget.matchId);
        }
      },
    );

    final otherReadAsync = otherUid == null
        ? const AsyncValue<MessageRead?>.data(null)
        : ref.watch(
            otherReadProvider((matchId: widget.matchId, otherUid: otherUid)),
          );

    return Scaffold(
      appBar: AppBar(
        title: otherUid != null
            ? _ChatAppBarTitle(otherUid: otherUid)
            : const Text('Chat'),
        actions: otherUid == null
            ? null
            : [
                SafetyActions(
                  reportTargetType: 'user',
                  reportTargetId: otherUid,
                  blockUid: otherUid,
                  onBlocked: () => context.go('/chats'),
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (otherUid != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  WarmPlayfulSpacing.s4,
                  WarmPlayfulSpacing.s4,
                  WarmPlayfulSpacing.s4,
                  0,
                ),
                child: PostMealCard(
                  matchId: widget.matchId,
                  targetUid: otherUid,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
              child: const SafetyTipsCard(),
            ),
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Something went wrong — please try again.',
                    textAlign: TextAlign.center,
                    style:
                        textTheme.bodyMedium?.copyWith(color: colors.error),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Say hi \u{1F44B}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.outline,
                        ),
                      ),
                    );
                  }

                  final myLatestId = _myLatestMessageId(messages, myUid);
                  final ordered = messages.reversed.toList(growable: false);

                  return ListView.builder(
                    key: const Key('chat_messages_list'),
                    reverse: true,
                    padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
                    itemCount: ordered.length,
                    itemBuilder: (context, index) {
                      final message = ordered[index];
                      final mine = myUid != null && message.senderId == myUid;
                      final showSeen = mine &&
                          message.id == myLatestId &&
                          _isSeenBy(message, otherReadAsync.value);
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: WarmPlayfulSpacing.s3,
                        ),
                        child: MessageBubble(
                          message: message,
                          mine: mine,
                          showSeen: showSeen,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            MessageComposer(matchId: widget.matchId),
          ],
        ),
      ),
    );
  }
}

/// The other participant's photo + display name in the app bar.
class _ChatAppBarTitle extends ConsumerWidget {
  const _ChatAppBarTitle({required this.otherUid});

  final String otherUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final user = ref.watch(userDocProvider(otherUid)).value;
    final photoUrl =
        (user?.photoUrls.isNotEmpty ?? false) ? user!.photoUrls.first : null;

    return Row(
      children: [
        CircleAvatar(
          radius: WarmPlayfulSpacing.s4,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Icon(
                  Icons.person_rounded,
                  size: WarmPlayfulSpacing.s4,
                  color: colors.outline,
                )
              : null,
        ),
        const SizedBox(width: WarmPlayfulSpacing.s2),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? 'Chat',
                overflow: TextOverflow.ellipsis,
              ),
              RatingBadge(uid: otherUid),
            ],
          ),
        ),
      ],
    );
  }
}
