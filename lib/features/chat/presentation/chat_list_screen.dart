/// Chats tab (`/chats`) — the signed-in user's matches as a chat list.
///
/// Body switches on [chatListProvider]: loading spinner, error message,
/// empty "match on a meal to start talking" hint, or a list of
/// [ChatListTile]s. Each tile owns its own row-level watches (other
/// participant + last message); this screen only renders the shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/chat_list_tile.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final chatsAsync = ref.watch(chatListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: SafeArea(
        child: chatsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Something went wrong — please try again.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colors.error),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
                  child: Text(
                    'No chats yet — match on a meal to start talking',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.outline,
                    ),
                  ),
                ),
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
