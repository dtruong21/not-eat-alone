/// The shared "Report" bottom sheet — reason chips + optional note, wired to
/// `reportControllerProvider`. See `docs/superpowers/specs/2026-09-22-safety-
/// design.md § 3. Report` for the model this feeds
/// (`reports/{autoId}`, admin-review-only).
///
/// [showReportSheet] is the only public entry point; entry points (chat
/// header, meal detail) call it via `SafetyActions` (see
/// `widgets/safety_actions.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/safety/application/report_controller.dart';

/// The 5 valid report reasons — key is the literal sent to
/// `ReportController.submit`, value is the chip label. Kept in this order
/// (least to most severe reads oddly, but this mirrors the spec's list
/// verbatim) so the UI and the accepted literals never drift apart.
const _reportReasons = <String, String>{
  'inappropriate': 'Inappropriate content',
  'spam': 'Spam',
  'harassment': 'Harassment',
  'fake': 'Fake profile',
  'other': 'Other',
};

/// Opens the report sheet for [targetType]/[targetId] (`'user'`, `'meal'`, or
/// `'message'` — see the spec's `reports` model).
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId});

  final String targetType;
  final String targetId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _reason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Submits with [reason] as the literal — a note (if entered) is appended
  /// as `'<literal>: <note>'` so the stored `reason` always starts with one
  /// of the 5 accepted literals for admin triage, never free text alone.
  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;

    final note = _noteController.text.trim();
    final payload = note.isEmpty ? reason : '$reason: $note';

    await ref.read(reportControllerProvider.notifier).submit(
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: payload,
        );

    if (!mounted) return;
    final error = ref.read(reportControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't submit your report. Try again."),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Thanks — we'll review this.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isSubmitting = ref.watch(reportControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: WarmPlayfulSpacing.s5,
        right: WarmPlayfulSpacing.s5,
        top: WarmPlayfulSpacing.s5,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            WarmPlayfulSpacing.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report',
            style: textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: WarmPlayfulType.h2Weight,
            ),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s4),
          Wrap(
            spacing: WarmPlayfulSpacing.s2,
            runSpacing: WarmPlayfulSpacing.s2,
            children: [
              for (final entry in _reportReasons.entries)
                ChoiceChip(
                  key: Key('report_reason_chip_${entry.key}'),
                  label: Text(entry.value),
                  selected: _reason == entry.key,
                  onSelected: isSubmitting
                      ? null
                      : (_) => setState(() => _reason = entry.key),
                ),
            ],
          ),
          const SizedBox(height: WarmPlayfulSpacing.s4),
          TextField(
            key: const Key('report_note_field'),
            controller: _noteController,
            enabled: !isSubmitting,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s4),
          FilledButton(
            key: const Key('report_submit_button'),
            onPressed: (_reason == null || isSubmitting) ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: WarmPlayfulSpacing.s4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
              ),
            ),
            child: isSubmitting
                ? SizedBox(
                    height: WarmPlayfulSpacing.s4,
                    width: WarmPlayfulSpacing.s4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
