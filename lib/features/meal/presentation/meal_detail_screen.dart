/// Meal-detail screen (`/meals/detail`, `Meal` passed via `extra`).
///
/// Read-only detail view of a single [Meal]: restaurant card, host block
/// (photo/name/derived age/bio via `UserRepository.watch(hostId)`),
/// date/time, note (if any), and a "Women only" badge when applicable.
///
/// Carries a "Request to join" button that is present but disabled
/// (`onPressed: null`) with a "Coming soon" caption — the join flow itself
/// is Plan 6 scope; this screen only stakes out where the control will live.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/design/tokens.dart';
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
              FilledButton(
                key: const Key('meal_detail_request_to_join_button'),
                onPressed: null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: WarmPlayfulSpacing.s4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
                child: const Text('Request to join'),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s1),
              Text(
                'Coming soon',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: colors.outline),
              ),
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
