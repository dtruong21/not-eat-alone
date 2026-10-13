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

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/meal/application/create_meal_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

const _maxNoteLength = 200;

/// Minimum lead between "now" and a picked meal time. The `meals` create rule
/// requires `dateTime > request.time` on the SERVER, so a near-term pick, a
/// slow submit or a device clock slightly behind the server would otherwise
/// fail the create with a generic error.
const mealMinLead = Duration(minutes: 5);

/// Whether [picked] is at least [mealMinLead] after [now] (defaults to the
/// current time).
bool isMealTimeFarEnough(DateTime picked, {DateTime? now}) =>
    !picked.isBefore((now ?? DateTime.now()).add(mealMinLead));

/// Default meal time: one hour from [now], rounded UP to the next :00 or :30
/// (so "11:01" never shows up). Always at least [mealMinLead] after [now].
DateTime nextMealSlot(DateTime now) {
  final t = now.add(const Duration(hours: 1));
  final floor = DateTime(t.year, t.month, t.day, t.hour, t.minute ~/ 30 * 30);
  // DateTime() normalises minute 60 into the next hour / day.
  return floor.isBefore(t)
      ? DateTime(
          floor.year,
          floor.month,
          floor.day,
          floor.hour,
          floor.minute + 30,
        )
      : floor;
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
    final initial = _dateTime ?? nextMealSlot(now);

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
      // Match the 24 h format the app shows (formatMealDateTime).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    // Needs a lead (see [mealMinLead]): reject a same-day pick that is in the
    // past or too soon, and say why.
    if (!isMealTimeFarEnough(combined)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createMealTooSoon(mealMinLead.inMinutes)),
        ),
      );
      return;
    }
    setState(() => _dateTime = combined);
  }

  Future<void> _submit() async {
    final dateTime = _dateTime;
    if (dateTime == null) return;

    final note = _noteController.text.trim();
    await ref
        .read(createMealControllerProvider.notifier)
        .create(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.createMealPosted)));
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
      appBar: AppBar(title: Text(context.l10n.createMealTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                key: const Key('create_meal_restaurant_card'),
                color: colors.surfaceContainerHighest,
                elevation: WarmPlayfulElevation.card,
                shadowColor: context.wp.shadow,
                surfaceTintColor: Colors.transparent,
                borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
                child: Padding(
                  padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
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
                          color: context.wp.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              OutlinedButton(
                key: const Key('create_meal_datetime_button'),
                onPressed: isSubmitting ? null : _pickDateTime,
                child: Text(
                  _dateTime == null
                      ? context.l10n.createMealPickDateTime
                      : formatMealDateTime(
                          _dateTime!,
                          locale: Localizations.localeOf(context),
                        ),
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
                scrollPadding: const EdgeInsets.only(
                  bottom: WarmPlayfulSize.keyboardReveal,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createMealNoteLabel,
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
                      context.l10n.mealWomenOnly,
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
                  context.l10n.commonSomethingWentWrong,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ],
              AppButton(
                label: context.l10n.createMealSubmit,
                loadingLabel: context.l10n.createMealCreating,
                isLoading: isSubmitting,
                key: const Key('create_meal_submit_button'),
                onPressed: (_dateTime == null || isSubmitting) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
