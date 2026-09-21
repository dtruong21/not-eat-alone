/// Meal-detail screen (`/meals/detail`, `Meal` passed via `extra`).
///
/// Read-only detail view of a single [Meal]: restaurant card, host block
/// (photo/name/derived age/bio via `UserRepository.watch(hostId)`),
/// date/time, note (if any), and a "Women only" badge when applicable.
///
/// Carries the live "Request to join" control (`_RequestAction`), driven by
/// `mealRequestStateProvider(meal.id)`: enabled "Request to join" when the
/// viewer has no request yet, disabled "Requested" while pending, a
/// "Matched!" banner once approved, disabled "Not selected" once denied, and
/// nothing (a "Your meal" chip) when the viewer is the host — a host never
/// requests their own meal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/create_request_controller.dart';
import 'package:not_eat_alone/features/matching/application/meal_request_state_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

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

/// Formats [dateTime] as e.g. "January 5, 2027 at 7:30 PM" — same shape as
/// `discovery_screen.dart`'s formatter, duplicated (not shared) since both
/// are small, presentation-only, private helpers.
String _formatDateTime(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '${_monthNames[dateTime.month - 1]} ${dateTime.day}, '
      '${dateTime.year} at $hour12:$minute $period';
}

/// Age in whole years for someone born on [dob], as of [now] (defaults to
/// `DateTime.now()`). Same birthday-not-yet-happened-this-year logic as
/// `core/util/age.dart`'s `isAdult`, but returns the age itself rather than
/// an 18+ boolean.
int _ageFromDob(DateTime dob, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dob.year;
  final hadBirthday = (today.month > dob.month) ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age;
}

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({required this.meal, super.key});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meal details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const Key('meal_detail_restaurant_card'),
                padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meal.restaurant.name,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: WarmPlayfulType.h2Weight,
                            ),
                          ),
                        ),
                        if (meal.womenOnly) ...[
                          const SizedBox(width: WarmPlayfulSpacing.s2),
                          _WomenOnlyBadge(colors: colors, textTheme: textTheme),
                        ],
                      ],
                    ),
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Text(
                      meal.restaurant.address,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              Text(
                _formatDateTime(meal.dateTime),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: WarmPlayfulType.h2Weight,
                ),
              ),
              if (meal.note != null && meal.note!.trim().isNotEmpty) ...[
                const SizedBox(height: WarmPlayfulSpacing.s4),
                Text(
                  meal.note!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
              const SizedBox(height: WarmPlayfulSpacing.s5),
              Text(
                'Host',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: WarmPlayfulType.h2Weight,
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s3),
              _HostBlock(hostId: meal.hostId),
              const SizedBox(height: WarmPlayfulSpacing.s6),
              _RequestAction(meal: meal),
            ],
          ),
        ),
      ),
    );
  }
}

class _WomenOnlyBadge extends StatelessWidget {
  const _WomenOnlyBadge({required this.colors, required this.textTheme});

  final ColorScheme colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('women_only_badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: WarmPlayfulSpacing.s2,
        vertical: WarmPlayfulSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.pill),
      ),
      child: Text(
        'Women only',
        style: textTheme.bodySmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: WarmPlayfulType.captionWeight,
        ),
      ),
    );
  }
}

/// Host block — photo, display name, derived age, bio — driven directly off
/// `UserRepository.watch(hostId)` via a [StreamBuilder]. See
/// `discovery_screen.dart`'s `_HostInfo` for why this is a raw stream
/// rather than a new Riverpod provider.
class _HostBlock extends ConsumerWidget {
  const _HostBlock({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(userRepositoryProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return StreamBuilder<AppUser?>(
      stream: repository.watch(hostId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(
            'Something went wrong — please try again.',
            style: textTheme.bodyMedium?.copyWith(color: colors.error),
          );
        }

        final host = snapshot.data;
        if (host == null) {
          return Text(
            'Host unavailable',
            style: textTheme.bodyMedium?.copyWith(color: colors.outline),
          );
        }

        final photoUrl =
            host.photoUrls.isNotEmpty ? host.photoUrls.first : null;
        final age = _ageFromDob(host.dob);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${host.displayName ?? 'Host'}, $age',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: WarmPlayfulType.h2Weight,
                    ),
                  ),
                  if (host.bio != null && host.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Text(
                      host.bio!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The live "Request to join" control. Switches on whether the viewer is the
/// meal's host (read via [authStateProvider]) and, if not, on
/// [mealRequestStateProvider]'s `AsyncValue<JoinRequest?>` for this meal — a
/// host never requests their own meal, so that case short-circuits before
/// touching the request stream at all.
class _RequestAction extends ConsumerWidget {
  const _RequestAction({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewerUid = ref.watch(authStateProvider).value?.uid;
    if (viewerUid != null && viewerUid == meal.hostId) {
      return const _YourMealChip();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final requestState = ref.watch(mealRequestStateProvider(meal.id));

    return requestState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Column(
        children: [
          Text(
            'Something went wrong — please try again.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s2),
          TextButton(
            key: const Key('meal_detail_request_retry_button'),
            onPressed: () =>
                ref.invalidate(mealRequestStateProvider(meal.id)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (request) {
        if (request == null) {
          return _RequestToJoinButton(meal: meal);
        }
        return switch (request.status) {
          RequestStatus.pending =>
            _RequestedState(colors: colors, textTheme: textTheme),
          RequestStatus.approved =>
            _MatchedBanner(colors: colors, textTheme: textTheme),
          RequestStatus.denied =>
            _NotSelectedState(colors: colors, textTheme: textTheme),
        };
      },
    );
  }
}

/// Enabled "Request to join" button; disables itself and shows a spinner
/// while [createRequestControllerProvider] is submitting.
class _RequestToJoinButton extends ConsumerWidget {
  const _RequestToJoinButton({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isSubmitting = ref.watch(createRequestControllerProvider).isLoading;

    return FilledButton(
      key: const Key('meal_detail_request_to_join_button'),
      onPressed: isSubmitting
          ? null
          : () =>
              ref.read(createRequestControllerProvider.notifier).request(meal),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: WarmPlayfulSpacing.s4),
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
          : const Text('Request to join'),
    );
  }
}

/// Disabled "Requested" button + a "Waiting for the host" hint — rendered
/// while the viewer's request on this meal is [RequestStatus.pending].
class _RequestedState extends StatelessWidget {
  const _RequestedState({required this.colors, required this.textTheme});

  final ColorScheme colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          key: const Key('meal_detail_requested_button'),
          onPressed: null,
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(vertical: WarmPlayfulSpacing.s4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
            ),
          ),
          child: const Text('Requested'),
        ),
        const SizedBox(height: WarmPlayfulSpacing.s1),
        Text(
          'Waiting for the host',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}

/// "Matched!" banner — rendered once the viewer's request on this meal is
/// [RequestStatus.approved]. Real-time chat is a later plan; this screen
/// only confirms the match.
class _MatchedBanner extends StatelessWidget {
  const _MatchedBanner({required this.colors, required this.textTheme});

  final ColorScheme colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('meal_detail_matched_banner'),
      padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            'Matched!',
            style: textTheme.titleMedium?.copyWith(
              color: colors.onTertiaryContainer,
              fontWeight: WarmPlayfulType.h2Weight,
            ),
          ),
          const SizedBox(height: WarmPlayfulSpacing.s1),
          Text(
            "You're in — chat coming soon",
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Disabled "Not selected" button — rendered once the viewer's request on
/// this meal is [RequestStatus.denied].
class _NotSelectedState extends StatelessWidget {
  const _NotSelectedState({required this.colors, required this.textTheme});

  final ColorScheme colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('meal_detail_not_selected_button'),
      onPressed: null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: WarmPlayfulSpacing.s4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        ),
      ),
      child: const Text('Not selected'),
    );
  }
}

/// Subtle chip shown instead of a request button when the viewer is the
/// meal's host — a host never requests their own meal.
class _YourMealChip extends StatelessWidget {
  const _YourMealChip();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        key: const Key('meal_detail_your_meal_chip'),
        padding: const EdgeInsets.symmetric(
          horizontal: WarmPlayfulSpacing.s3,
          vertical: WarmPlayfulSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.pill),
        ),
        child: Text(
          'Your meal',
          style: textTheme.bodySmall?.copyWith(
            color: colors.outline,
            fontWeight: WarmPlayfulType.captionWeight,
          ),
        ),
      ),
    );
  }
}
