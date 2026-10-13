/// Host's request inbox (`/requests`) — every pending join request across
/// the signed-in host's meals, newest first, driven by [hostInboxProvider].
///
/// The Requests tab of the bottom-navigation shell (`app_shell.dart`), whose
/// badge count is also driven by `pendingRequestCountProvider`; each row is
/// a [RequestInboxTile] that lets the host Approve or Deny in place.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/request_inbox_tile.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

class RequestInboxScreen extends ConsumerWidget {
  const RequestInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostInboxProvider);

    final body = state.when(
      loading: () => const SkeletonList(),
      error: (error, stackTrace) =>
          ErrorState(onRetry: () => ref.invalidate(hostInboxProvider)),
      data: (requests) => requests.isEmpty
          ? EmptyState(
              icon: Icons.inbox_rounded,
              title: context.l10n.inboxEmptyTitle,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: WarmPlayfulSpacing.s3),
              itemBuilder: (context, index) =>
                  RequestInboxTile(request: requests[index]),
            ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.inboxTitle)),
      body: SafeArea(child: body),
    );
  }
}
