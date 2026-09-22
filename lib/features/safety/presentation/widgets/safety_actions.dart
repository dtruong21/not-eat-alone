/// Reusable "Report" / "Block" overflow menu — the safety entry point wired
/// into the chat header and meal detail app bars (see
/// `docs/superpowers/specs/2026-09-22-safety-design.md § 3. Report`).
///
/// "Report" opens `showReportSheet` for the given target. "Block" (only
/// shown when [blockUid] is provided) confirms via an [AlertDialog], then
/// calls `BlockController.block`; on success [onBlocked] fires (chat uses it
/// to pop back to the chats list, since a blocked match should no longer be
/// open).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/safety/application/block_controller.dart';
import 'package:not_eat_alone/features/safety/presentation/report_sheet.dart';

enum _SafetyAction { report, block }

class SafetyActions extends ConsumerWidget {
  const SafetyActions({
    required this.reportTargetType,
    required this.reportTargetId,
    this.blockUid,
    this.onBlocked,
    super.key,
  });

  /// `'user'`, `'meal'`, or `'message'` — see the spec's `reports` model.
  final String reportTargetType;
  final String reportTargetId;

  /// The uid to block, if this menu should expose blocking at all. `null`
  /// hides the "Block" item entirely.
  final String? blockUid;

  /// Fires after a successful block — `null` if the caller has nothing to
  /// do (e.g. meal detail, which has no block entry point).
  final VoidCallback? onBlocked;

  Future<bool> _confirmBlock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          "You won't see each other in Convyve anymore.",
        ),
        actions: [
          TextButton(
            key: const Key('safety_actions_block_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('safety_actions_block_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final uid = blockUid;
    if (uid == null) return;

    final confirmed = await _confirmBlock(context);
    if (!confirmed) return;
    if (!context.mounted) return;

    await ref.read(blockControllerProvider.notifier).block(uid);

    if (!context.mounted) return;
    final error = ref.read(blockControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't block. Try again.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Blocked.')),
    );
    onBlocked?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              ),
            );
          case _SafetyAction.block:
            unawaited(_block(context, ref));
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          key: Key('safety_actions_report_item'),
          value: _SafetyAction.report,
          child: Text('Report'),
        ),
        if (blockUid != null)
          const PopupMenuItem(
            key: Key('safety_actions_block_item'),
            value: _SafetyAction.block,
            child: Text('Block'),
          ),
      ],
    );
  }
}
