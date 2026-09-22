/// Pinned message input — a `TextField` + send button. Disabled while the
/// field is empty or while `chatControllerProvider` is submitting; surfaces
/// send failures via a SnackBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/chat/application/chat_controller.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    await ref
        .read(chatControllerProvider.notifier)
        .send(matchId: widget.matchId, text: text);
    if (!mounted) return;
    if (!ref.read(chatControllerProvider).hasError) {
      _controller.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Error transition (loading -> error): guarded on that edge so this
    // fires exactly once per failed send, never on every rebuild — same
    // pattern as `meal_detail_screen.dart`'s `_RequestToJoinButton`.
    ref.listen<AsyncValue<void>>(chatControllerProvider, (previous, next) {
      if (previous?.isLoading == true && next.hasError) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't send your message. Try again."),
          ),
        );
      }
    });

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSending = ref.watch(chatControllerProvider).isLoading;
    final hasText = _controller.text.trim().isNotEmpty;
    final canSend = hasText && !isSending;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WarmPlayfulSpacing.s3,
            vertical: WarmPlayfulSpacing.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('message_composer_field'),
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => canSend ? _send() : null,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(WarmPlayfulRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: WarmPlayfulSpacing.s4,
                      vertical: WarmPlayfulSpacing.s2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s2),
              IconButton(
                key: const Key('message_composer_send_button'),
                onPressed: canSend ? _send : null,
                icon: isSending
                    ? SizedBox(
                        height: WarmPlayfulSpacing.s4,
                        width: WarmPlayfulSpacing.s4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: canSend ? colors.primary : colors.outline,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
