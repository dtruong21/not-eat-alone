/// Reusable "Report" / "Block" overflow menu — the safety entry point wired
/// into the chat header and meal detail app bars (see
/// `docs/superpowers/specs/2026-09-22-safety-design.md § 3. Report`).
///
/// The primary "Report" item opens `showReportSheet` for
/// [reportTargetType]/[reportTargetId]. An optional second report item
/// ([secondaryReportTargetType]/[secondaryReportTargetId]) covers meal
/// detail's need to report both the meal *and* its host from one menu
/// (pre-match — reporting a user is otherwise only reachable from chat,
/// post-match). "Block" (only shown when [blockUid] is provided) confirms
/// via an [AlertDialog], then calls `BlockController.block`; on success
/// [onBlocked] fires (chat uses it to pop back to the chats list, since a
/// blocked match should no longer be open).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/safety/application/block_controller.dart';
import 'package:not_eat_alone/features/safety/presentation/report_sheet.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

enum _SafetyAction { report, reportSecondary, block }

class SafetyActions extends ConsumerWidget {
  const SafetyActions({
    required this.reportTargetType,
    required this.reportTargetId,
    this.reportLabel,
    this.secondaryReportTargetType,
    this.secondaryReportTargetId,
    this.secondaryReportLabel,
    this.blockUid,
    this.blockLabel,
    this.onBlocked,
    super.key,
  });

  /// `'user'`, `'meal'`, or `'message'` — see the spec's `reports` model.
  final String reportTargetType;
  final String reportTargetId;

  /// Menu label for the primary report item — meal detail overrides this to
  /// "Report this meal" so it reads clearly alongside "Report host". `null`
  /// reads "Report".
  final String? reportLabel;

  /// A second, optional report target (meal detail uses this to also report
  /// the host: `targetType: 'user', targetId: meal.hostId`). Both
  /// [secondaryReportTargetType] and [secondaryReportTargetId] must be
  /// non-null for the item to show.
  final String? secondaryReportTargetType;
  final String? secondaryReportTargetId;
  final String? secondaryReportLabel;

  /// The uid to block, if this menu should expose blocking at all. `null`
  /// hides the "Block" item entirely.
  final String? blockUid;

  /// Menu label for the block item — meal detail overrides this to
  /// "Block host". `null` reads "Block".
  final String? blockLabel;

  /// Fires after a successful block — `null` if the caller has nothing to
  /// do.
  final VoidCallback? onBlocked;

  /// The person's display name when their profile is already loaded (chat and
  /// meal detail both show it), else null so titles fall back to generic copy.
  String? _nameOf(WidgetRef ref, String uid) =>
      ref.read(userDocProvider(uid)).value?.displayName;

  Future<bool> _confirmBlock(BuildContext context, String? name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // A long name at large text must scroll, not overflow.
        scrollable: true,
        title: Text(
          name != null
              ? dialogContext.l10n.safetyBlockTitleNamed(name)
              : dialogContext.l10n.safetyBlockTitleGeneric,
        ),
        content: Text(dialogContext.l10n.safetyBlockBody),
        actions: [
          TextButton(
            key: const Key('safety_actions_block_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            key: const Key('safety_actions_block_confirm'),
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.wp.dangerText,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.safetyBlockAction),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final uid = blockUid;
    if (uid == null) return;

    final confirmed = await _confirmBlock(context, _nameOf(ref, uid));
    if (!confirmed) return;
    if (!context.mounted) return;

    await ref.read(blockControllerProvider.notifier).block(uid);

    if (!context.mounted) return;
    final error = ref.read(blockControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.safetyBlockFailed)));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.safetyBlockDone)));
    onBlocked?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profiles that titles may name: `userDocProvider` is
    // autoDispose, so without a watcher `_nameOf`'s read would start a fresh
    // load (name unavailable) unless some other widget (chat title, meal
    // detail's RatingBadge) happened to watch the same uid.
    for (final uid in {
      if (reportTargetType == 'user') reportTargetId,
      if (secondaryReportTargetType == 'user') ?secondaryReportTargetId,
      ?blockUid,
    }) {
      ref.watch(userDocProvider(uid));
    }
    return PopupMenuButton<_SafetyAction>(
      key: const Key('safety_actions_menu'),
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) {
        switch (action) {
          case _SafetyAction.report:
            unawaited(
              showReportSheet(
                context,
                targetType: reportTargetType,
                targetId: reportTargetId,
                targetName: reportTargetType == 'user'
                    ? _nameOf(ref, reportTargetId)
                    : null,
              ),
            );
          case _SafetyAction.reportSecondary:
            final type = secondaryReportTargetType;
            final id = secondaryReportTargetId;
            if (type == null || id == null) return;
            unawaited(
              showReportSheet(
                context,
                targetType: type,
                targetId: id,
                targetName: type == 'user' ? _nameOf(ref, id) : null,
              ),
            );
          case _SafetyAction.block:
            unawaited(_block(context, ref));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('safety_actions_report_item'),
          value: _SafetyAction.report,
          child: Text(reportLabel ?? context.l10n.safetyReportAction),
        ),
        if (secondaryReportTargetType != null &&
            secondaryReportTargetId != null)
          PopupMenuItem(
            key: const Key('safety_actions_report_secondary_item'),
            value: _SafetyAction.reportSecondary,
            child: Text(
              secondaryReportLabel ?? context.l10n.safetyReportAction,
            ),
          ),
        if (blockUid != null)
          PopupMenuItem(
            key: const Key('safety_actions_block_item'),
            value: _SafetyAction.block,
            child: Text(blockLabel ?? context.l10n.safetyBlockAction),
          ),
      ],
    );
  }
}
