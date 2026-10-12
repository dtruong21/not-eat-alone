/// Chats tab (`/chats`) — the signed-in user's matches as a chat list.
///
/// Body switches on [chatListProvider]: loading skeleton, error + retry,
/// empty "match on a meal to start talking" hint, or a list of
/// [ChatListTile]s. Each tile owns its own row-level watches (other
/// participant + last message); this screen only renders the shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/chat_list_tile.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: SafeArea(
        child: chatsAsync.when(
          loading: () => const SkeletonList(),
          error: (error, stackTrace) =>
              ErrorState(onRetry: () => ref.invalidate(chatListProvider)),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No chats yet — match on a meal to start talking',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: WarmPlayfulSpacing.s2),
              itemBuilder: (context, index) =>
                  ChatListTile(item: items[index]),
            );
          },
        ),
      ),
    );
  }
}
