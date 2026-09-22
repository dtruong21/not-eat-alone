/// Create-meal screen (`/meals/new/details`).
///
/// Second and final step of meal creation: the host picks a future date and
/// time, optionally adds a note and flips "women only", then submits.
/// Submission is delegated entirely to [createMealControllerProvider]
/// ([CreateMealController]) — this screen only owns the form's local state
/// (date/time, note, switch) and renders whatever `AsyncValue<void>` state
/// comes back (idle / loading / error). On success it shows a confirmation
/// and returns to home.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/meal/application/create_meal_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

const _maxNoteLength = 200;

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats [dateTime] as e.g. "January 5, 2027 at 7:30 PM" without pulling
/// in `intl` (not a direct dependency of this package).
String _formatDateTime(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '${_monthNames[dateTime.month - 1]} ${dateTime.day}, '
      '${dateTime.year} at $hour12:$minute $period';
}

class CreateMealScreen extends ConsumerStatefulWidget {
  const CreateMealScreen({required this.restaurant, super.key});

  final Restaurant restaurant;

  @override
  ConsumerState<CreateMealScreen> createState() => CreateMealScreenState();
}

/// Public (not `_`-prefixed) so widget tests can reach
/// [debugSetSelectedDateTime] via a `GlobalKey<CreateMealScreenState>` —
/// driving `showDatePicker`/`showTimePicker` in a widget test is
/// awkward/unreliable, so tests inject the chosen date/time directly and
/// exercise the same submit path production code uses.
class CreateMealScreenState extends ConsumerState<CreateMealScreen> {
  final _noteController = TextEditingController();
  DateTime? _dateTime;
  bool _womenOnly = false;

  @visibleForTesting
  void debugSetSelectedDateTime(DateTime dateTime) {
    setState(() => _dateTime = dateTime);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _dateTime ?? now.add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    // Future only — silently ignore a same-day pick that lands in the past.
    if (!combined.isAfter(DateTime.now())) return;
    setState(() => _dateTime = combined);
  }

  Future<void> _submit() async {
    final dateTime = _dateTime;
    if (dateTime == null) return;

    final note = _noteController.text.trim();
    await ref.read(createMealControllerProvider.notifier).create(
          restaurant: widget.restaurant,
          dateTime: dateTime,
          note: note.isEmpty ? null : note,
          womenOnly: _womenOnly,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Success transition (loading -> data, no error): confirm + return home.
    // Guarded on the loading->data edge so this fires exactly once per
    // successful submit, never on every rebuild.
    ref.listen<AsyncValue<void>>(createMealControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.hasValue && !next.hasError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal created!')),
        );
        context.go('/discover');
      }
    });

    final state = ref.watch(createMealControllerProvider);
    final isSubmitting = state.isLoading;
    final hasError = state.hasError;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create a meal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const Key('create_meal_restaurant_card'),
                padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restaurant.name,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: WarmPlayfulType.h2Weight,
                      ),
                    ),
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Text(
                      widget.restaurant.address,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              OutlinedButton(
                key: const Key('create_meal_datetime_button'),
                onPressed: isSubmitting ? null : _pickDateTime,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: Text(
                  _dateTime == null
                      ? 'Pick date & time'
                      : _formatDateTime(_dateTime!),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              TextField(
                key: const Key('create_meal_note_field'),
                controller: _noteController,
                maxLength: _maxNoteLength,
                maxLines: 3,
                minLines: 2,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Women only',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: WarmPlayfulType.h2Weight,
                      ),
                    ),
                  ),
                  Switch(
                    key: const Key('create_meal_women_only_switch'),
                    value: _womenOnly,
                    onChanged: isSubmitting
                        ? null
                        : (value) => setState(() => _womenOnly = value),
                  ),
                ],
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              if (hasError) ...[
                Text(
                  'Something went wrong — please try again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ],
              FilledButton(
                key: const Key('create_meal_submit_button'),
                onPressed: (_dateTime == null || isSubmitting)
                    ? null
                    : _submit,
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
                    : const Text('Create meal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
