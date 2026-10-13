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
import 'package:not_eat_alone/core/design/avatar_image.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_controller.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_read_provider.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';
import 'package:not_eat_alone/features/chat/presentation/group_messages.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/chat_meal_header.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/day_separator.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/leave_match_action.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_bubble.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_composer.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/post_meal_card.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/safety/presentation/safety_tips_sheet.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_actions.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_tips_banner.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

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

/// Thread height needed to keep the post-meal prompt below the latest
/// message; on less room it moves above the oldest one (see the list).
const _roomForCardBelow = WarmPlayfulSize.keyboardReveal * 2;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  /// The safety banner is hidden for this chat only; not persisted.
  bool _safetyDismissed = false;

  /// Where the post-meal card sits: after the newest message (true) or above
  /// the oldest (short viewport). Only updated while the keyboard is closed.
  bool _cardBelow = true;

  final _postMealCardKey = GlobalKey();

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

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final chatGone =
        messagesAsync.hasError && _isChatGone(messagesAsync.error!);

    return Scaffold(
      appBar: AppBar(
        title: otherUid != null
            ? _ChatAppBarTitle(otherUid: otherUid)
            : Text(context.l10n.chatTitleFallback),
        actions: otherUid == null
            ? null
            : [
                LeaveMatchAction(matchId: widget.matchId, otherUid: otherUid),
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
            // The meal header and safety banner are informational: hide them
            // while the keyboard is open so the thread keeps its room. The
            // post-meal prompt scrolls with the messages instead.
            if (!keyboardOpen && !chatGone)
              ChatMealHeader(matchId: widget.matchId),
            if (!keyboardOpen && !_safetyDismissed && !chatGone)
              SafetyTipsBanner(
                onOpen: () => showSafetyTipsSheet(context),
                onDismiss: () => setState(() => _safetyDismissed = true),
              ),
            Expanded(
              child: messagesAsync.when(
                // Riverpod auto-retries a failed stream: keep showing the error.
                skipLoadingOnReload: true,
                loading: () => const SkeletonMessages(),
                error: (error, stackTrace) => !_isChatGone(error)
                    ? ErrorState(
                        onRetry: () => ref.invalidate(
                          chatMessagesProvider(widget.matchId),
                        ),
                      )
                    // Every read under a deleted match is denied: the chat is
                    // gone (cancelled / account deleted).
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.chatUnavailable,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: WarmPlayfulSpacing.s3),
                              FilledButton(
                                key: const Key('chat_unavailable_back_button'),
                                onPressed: () => context.go('/chats'),
                                child: Text(context.l10n.chatBackToChats),
                              ),
                            ],
                          ),
                        ),
                      ),
                data: (messages) {
                  // Offstage (not removed) while the keyboard is up: it takes no
                  // room, yet keeps its state, so `post_meal_prompt_shown`
                  // still fires once. The keep-alive and the GlobalKey do the
                  // same across scrolling and the empty -> first message step.
                  final postMealCard = otherUid == null
                      ? null
                      : _KeepAlive(
                          key: _postMealCardKey,
                          child: Offstage(
                            offstage: keyboardOpen,
                            child: PostMealCard(
                              matchId: widget.matchId,
                              targetUid: otherUid,
                            ),
                          ),
                        );
                  if (messages.isEmpty) {
                    return Column(
                      children: [
                        // Horizontal padding only: a hidden card costs no height.
                        if (postMealCard != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: WarmPlayfulSpacing.s3,
                            ),
                            child: postMealCard,
                          ),
                        Expanded(
                          child: EmptyState(title: context.l10n.chatSayHi),
                        ),
                      ],
                    );
                  }

                  final myLatestId = _myLatestMessageId(messages, myUid);
                  // Newest first (the list is reversed); a day separator
                  // therefore comes after the first message of its day.
                  final ordered = groupMessages(
                    messages,
                    now: DateTime.now(),
                    locale: Localizations.localeOf(context),
                  ).reversed.toList(growable: false);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // The post-meal prompt follows the latest message (index
                      // 0, just above the composer) and scrolls away with it.
                      // On a short viewport (large text on a small phone) it
                      // would cover the whole thread, so it goes above the
                      // oldest message instead and the latest ones stay visible.
                      // Decided only while the keyboard is closed: the list
                      // shrinks when it opens, and moving the card then would
                      // drop its state and fire the analytics event again.
                      if (!keyboardOpen) {
                        _cardBelow = constraints.maxHeight >= _roomForCardBelow;
                      }
                      final cardBelow = _cardBelow;
                      final offset = postMealCard != null && cardBelow ? 1 : 0;
                      final count =
                          ordered.length + (postMealCard == null ? 0 : 1);
                      return ListView.builder(
                        key: const Key('chat_messages_list'),
                        reverse: true,
                        padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
                        itemCount: count,
                        itemBuilder: (context, index) {
                          if (postMealCard != null &&
                              index == (cardBelow ? 0 : count - 1)) {
                            return postMealCard;
                          }
                          final entry = ordered[index - offset];
                          if (entry is DaySeparatorEntry) {
                            return DaySeparator(label: entry.label);
                          }
                          entry as MessageEntry;
                          final message = entry.message;
                          final mine =
                              myUid != null && message.senderId == myUid;
                          final showSeen =
                              mine &&
                              message.id == myLatestId &&
                              _isSeenBy(message, otherReadAsync.value);
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.endsRun
                                  ? WarmPlayfulSpacing.s3
                                  : WarmPlayfulSpacing.s1,
                            ),
                            child: MessageBubble(
                              message: message,
                              mine: mine,
                              showSeen: showSeen,
                              showTimestamp: entry.endsRun,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // A thread that failed to load shows only Retry: nothing to reply
            // to (this also covers the cancelled-match state).
            if (!messagesAsync.hasError)
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
    final photoUrl = (user?.photoUrls.isNotEmpty ?? false)
        ? user!.photoUrls.first
        : null;

    return Row(
      children: [
        CircleAvatar(
          radius: WarmPlayfulSpacing.s4,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: photoUrl != null
              ? avatarImage(context, photoUrl, radius: WarmPlayfulSpacing.s4)
              : null,
          onBackgroundImageError: photoUrl != null
              ? ignoreAvatarImageError
              : null,
          child: photoUrl == null
              ? Icon(
                  Icons.person_rounded,
                  size: WarmPlayfulSpacing.s4,
                  color: context.wp.muted,
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
                user?.displayName ?? context.l10n.chatTitleFallback,
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

/// Rules answer every read under a cancelled / deleted match with
/// permission-denied (the participant check `get()`s a missing document).
bool _isChatGone(Object error) =>
    error.toString().contains('permission-denied');

/// Keeps its child mounted when the list scrolls it out of view, so the
/// post-meal card is not rebuilt (and its analytics event not re-fired).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child, super.key});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
