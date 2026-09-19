/// Age-gate screen (`/onboarding/age`).
///
/// Shown to signed-in users who haven't verified their date of birth yet
/// (see `authRedirect` in `lib/core/routing/router.dart`). The user picks a
/// DOB; submitting either:
///   - marks them age-verified (`UsersRepository.upsertAgeVerified`) when
///     [isAdult] returns true, firing `age_gate_passed` — the router then
///     redirects to `/` once `currentUserDocProvider` reflects the write, or
///   - signs them out with a blocking, non-judgmental message when they're
///     under 18, firing `age_gate_failed` — the router sends them back to
///     sign-in once the auth state clears.
///
/// DOB is always normalized to a UTC-midnight calendar date
/// (`DateTime.utc(y, m, d)`) before it reaches [isAdult] or the repository —
/// see `UsersRepository`'s Firestore converter, which normalizes reads to
/// UTC. Passing a local-time `DateTime` here would risk a day of drift
/// around the timezone boundary.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/util/age.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';

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

/// Formats [date] as e.g. "January 5, 2000" without pulling in `intl`
/// (not a direct dependency of this package).
String _formatDate(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => AgeGateScreenState();
}

/// Public (not `_`-prefixed) so widget tests can reach [debugSetSelectedDate]
/// via a `GlobalKey<AgeGateScreenState>` — driving `showDatePicker` in a
/// widget test is awkward/unreliable, so tests inject the chosen date
/// directly and exercise the same submit path production code uses.
class AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  bool _blocked = false;
  Object? _error;

  static final DateTime _firstDate = DateTime(1900);
  static DateTime get _lastDate => DateTime.now();

  /// Test-only hook: sets the chosen DOB without going through the native
  /// date picker. Production code should only ever set this via [_pickDate].
  @visibleForTesting
  void debugSetSelectedDate(DateTime date) {
    setState(() => _selectedDate = date);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial =
        _selectedDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(_lastDate) ? _lastDate : initial,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final picked = _selectedDate;
    if (picked == null || _isSubmitting) return;

    // CRITICAL: normalize to a UTC-midnight calendar date before it reaches
    // isAdult()/the repository — see file header.
    final dobUtc = DateTime.utc(picked.year, picked.month, picked.day);

    if (!isAdult(dobUtc)) {
      await analytics.track(const AgeGateFailed());
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      setState(() {
        _blocked = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final uid = ref.read(authStateProvider).value!.uid;
      await ref
          .read(usersRepositoryProvider)
          .upsertAgeVerified(uid: uid, dob: dobUtc);
      await analytics.track(const AgeGatePassed());
      // No navigation here — the router's redirect reacts to
      // currentUserDocProvider once the write lands and moves us to `/`.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // `ref.watch` only in build() per project convention. Watching here
    // (rather than only `ref.read` in `_submit`) keeps the auth-state
    // subscription warm for the lifetime of this screen — the router
    // already guarantees we're signed in by the time this screen shows,
    // but this avoids relying on that ordering implicitly.
    ref.watch(authStateProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_blocked) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: WarmPlayfulSpacing.s7,
                    color: colors.error,
                  ),
                  const SizedBox(height: WarmPlayfulSpacing.s4),
                  Text(
                    'You must be 18 or older to use not-eat-alone.',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: WarmPlayfulType.h2Weight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final selected = _selectedDate;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Confirm your date of birth',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: WarmPlayfulType.h1Weight,
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s2),
              Text(
                'You must be 18 or older to use not-eat-alone.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s6),
              OutlinedButton(
                onPressed: _isSubmitting ? null : _pickDate,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: Text(
                  selected == null
                      ? 'Select date of birth'
                      : _formatDate(selected),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              if (_error != null) ...[
                Text(
                  'Something went wrong — please try again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
                const SizedBox(height: WarmPlayfulSpacing.s4),
              ],
              FilledButton(
                onPressed: (selected == null || _isSubmitting) ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: WarmPlayfulSpacing.s4,
                        width: WarmPlayfulSpacing.s4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
