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

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
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
/// `'message'` — see the spec's `reports` model). [targetName] (a person's
/// name) titles the sheet "Report NAME"; without it a meal reads "Report
/// this meal" and anything else just "Report".
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? targetName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetName,
  });

  final String targetType;
  final String targetId;
  final String? targetName;

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

    await ref
        .read(reportControllerProvider.notifier)
        .submit(
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
    final name = widget.targetName;
    final title = name != null
        ? 'Report $name'
        : widget.targetType == 'meal'
        ? 'Report this meal'
        : 'Report';

    return Padding(
      padding: EdgeInsets.only(
        left: WarmPlayfulSpacing.s5,
        right: WarmPlayfulSpacing.s5,
        top: WarmPlayfulSpacing.s5,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + WarmPlayfulSpacing.s5,
      ),
      // Scrolls when the keyboard / large text leave less room than the
      // content needs (otherwise the field and Submit end up hidden).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
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
                    // The theme's label is dark brown, unreadable on the
                    // dark-mode coral fill; onAccent is made for it.
                    labelStyle: _reason == entry.key
                        ? textTheme.bodySmall?.copyWith(
                            color: context.wp.onAccent,
                          )
                        : null,
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
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                // The sheet and the field share a fill: draw the edge.
                enabledBorder: sheetFieldBorder(context),
                disabledBorder: sheetFieldBorder(context),
              ),
            ),
            const SizedBox(height: WarmPlayfulSpacing.s4),
            AppButton(
              label: 'Submit',
              loadingLabel: 'Submitting…',
              isLoading: isSubmitting,
              key: const Key('report_submit_button'),
              onPressed: (_reason == null || isSubmitting) ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
