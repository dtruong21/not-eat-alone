/// Blocked people (`/settings/blocked`): everyone the signed-in user blocked,
/// each with an Unblock action.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/avatar_image.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

class BlockedPeopleScreen extends ConsumerWidget {
  const BlockedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedByMeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked people')),
      body: SafeArea(
        child: blocked.when(
          skipLoadingOnReload: true,
          loading: () => const SkeletonList(),
          error: (error, stackTrace) =>
              ErrorState(onRetry: () => ref.invalidate(blockedByMeProvider)),
          data: (uids) => uids.isEmpty
              ? const EmptyState(
                  icon: Icons.block_rounded,
                  title: "You haven't blocked anyone",
                  message:
                      'People you block are hidden from your meals and chats.',
                )
              : ListView(
                  children: [
                    for (final uid in uids)
                      _BlockedRow(key: Key('blocked_row_$uid'), uid: uid),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BlockedRow extends ConsumerStatefulWidget {
  const _BlockedRow({required this.uid, super.key});

  final String uid;

  @override
  ConsumerState<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends ConsumerState<_BlockedRow> {
  bool _busy = false;

  Future<void> _unblock(String name) async {
    // Everything the post-await code needs is read first: the stream drops
    // this row (and unmounts it) as soon as the delete applies locally.
    final messenger = ScaffoldMessenger.of(context);
    final me = ref.read(authRepositoryProvider).currentUser?.uid;
    final repo = ref.read(blockRepositoryProvider);
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await repo.unblock(me, widget.uid);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Unblocked $name.')));
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't unblock. Try again.")),
        );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDocProvider(widget.uid)).value;
    final name = user?.displayName ?? 'Unknown user';
    final photoUrl = (user != null && user.photoUrls.isNotEmpty)
        ? user.photoUrls.first
        : null;
    final initial = user?.displayName?.trim().characters.firstOrNull;

    final button = AppButton(
      key: Key('unblock_button_${widget.uid}'),
      label: 'Unblock',
      // Several rows say 'Unblock': screen readers need to know who.
      semanticLabel: 'Unblock $name',
      loadingLabel: 'Unblocking…',
      variant: AppButtonVariant.outlined,
      expand: false,
      maxLines: 1,
      isLoading: _busy,
      onPressed: () => unawaited(_unblock(name)),
    );
    // At large text the button no longer fits beside the name: drop it below.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WarmPlayfulSpacing.s4,
        vertical: WarmPlayfulSpacing.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: WarmPlayfulSpacing.s5,
                backgroundImage: photoUrl != null
                    ? avatarImage(
                        context,
                        photoUrl,
                        radius: WarmPlayfulSpacing.s5,
                      )
                    : null,
                onBackgroundImageError: photoUrl != null
                    ? ignoreAvatarImageError
                    : null,
                child: photoUrl == null
                    ? (initial != null
                          ? Text(initial.toUpperCase())
                          : Icon(
                              Icons.person_rounded,
                              size: WarmPlayfulSpacing.s5,
                              color: context.wp.muted,
                            ))
                    : null,
              ),
              const SizedBox(width: WarmPlayfulSpacing.s3),
              Expanded(
                child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
              ),
              if (!stacked) ...[
                const SizedBox(width: WarmPlayfulSpacing.s3),
                button,
              ],
            ],
          ),
          if (stacked) button,
        ],
      ),
    );
  }
}
