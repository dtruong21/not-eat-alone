/// A single pending [JoinRequest] row on the host's request inbox
/// (`RequestInboxScreen`).
///
/// Watches `userDocProvider(request.guestId)` for the guest's photo/name/
/// derived age (own loading/error tolerated — falls back to a placeholder
/// row rather than blocking the whole tile), and drives Approve/Deny through
/// `inboxActionControllerProvider`. Both buttons disable while that
/// controller is submitting; a `MealNoLongerOpenException` from approve
/// surfaces as a SnackBar rather than an inline error, since the request
/// itself is still valid — only this particular meal raced shut.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/matching/application/inbox_action_controller.dart';
import 'package:not_eat_alone/features/matching/data/repositories/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

/// Age in whole years for someone born on [dob], as of [now] (defaults to
/// `DateTime.now()`). Duplicated from `meal_detail_screen.dart`'s
/// `_ageFromDob` — both are small, presentation-only, private helpers.
int _ageFromDob(DateTime dob, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dob.year;
  final hadBirthday = (today.month > dob.month) ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age;
}

class RequestInboxTile extends ConsumerWidget {
  const RequestInboxTile({required this.request, super.key});

  final JoinRequest request;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await ref.read(inboxActionControllerProvider.notifier).approve(request);
    final error = ref.read(inboxActionControllerProvider).error;
    if (error is MealNoLongerOpenException && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This meal is no longer open.')),
      );
    }
  }

  Future<void> _deny(WidgetRef ref) async {
    await ref.read(inboxActionControllerProvider.notifier).deny(request);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final guest = ref.watch(userDocProvider(request.guestId)).value;

    final photoUrl =
        (guest != null && guest.photoUrls.isNotEmpty)
            ? guest.photoUrls.first
            : null;
    final label = guest == null
        ? 'Guest'
        : '${guest.displayName ?? 'Guest'}, ${_ageFromDob(guest.dob)}';

    final isSubmitting = ref.watch(inboxActionControllerProvider).isLoading;

    return Container(
      key: Key('request_inbox_tile_${request.id}'),
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: WarmPlayfulSpacing.s5,
            backgroundColor: colors.surfaceContainerHighest,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Icon(
                    Icons.person_rounded,
                    size: WarmPlayfulSpacing.s5,
                    color: colors.outline,
                  )
                : null,
          ),
          const SizedBox(width: WarmPlayfulSpacing.s3),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: WarmPlayfulType.h2Weight,
              ),
            ),
          ),
          const SizedBox(width: WarmPlayfulSpacing.s2),
          OutlinedButton(
            key: Key('request_inbox_deny_button_${request.id}'),
            onPressed: isSubmitting ? null : () => _deny(ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
              ),
            ),
            child: const Text('Deny'),
          ),
          const SizedBox(width: WarmPlayfulSpacing.s2),
          FilledButton(
            key: Key('request_inbox_approve_button_${request.id}'),
            onPressed: isSubmitting ? null : () => _approve(context, ref),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
              ),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}
