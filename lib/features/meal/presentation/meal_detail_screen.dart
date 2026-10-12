/// Meal-detail screen (`/meals/detail`, `Meal` passed via `extra`).
///
/// Read-only detail view of a single [Meal]: restaurant card, host block
/// (photo/name/derived age/bio via `UserRepository.watch(hostId)`),
/// date/time, note (if any), and a "Women only" badge when applicable.
///
/// The request control lives in the pinned [MealActionBar] (bottom bar), not
/// in the scroll body.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/avatar_image.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/meal/application/maps_launcher_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/widgets/meal_action_bar.dart';
import 'package:not_eat_alone/features/rating/presentation/widgets/rating_badge.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_actions.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({required this.meal, super.key});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal details'),
        actions: [_MealSafetyActions(meal: meal)],
      ),
      bottomNavigationBar: MealActionBar(meal: meal),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                key: const Key('meal_detail_restaurant_card'),
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
                      _RestaurantHeader(meal: meal),
                      const SizedBox(height: WarmPlayfulSpacing.s1),
                      Text(
                        meal.restaurant.address,
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.wp.muted,
                        ),
                      ),
                      if (hasMapsLocation(meal.restaurant)) ...[
                        const SizedBox(height: WarmPlayfulSpacing.s3),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _OpenInMapsButton(restaurant: meal.restaurant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s5),
              Text(
                formatMealDateTime(meal.dateTime),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// The app bar's safety menu for meal detail — reporting the meal and
/// reporting/blocking the host; hidden when the viewer is the meal's host.
/// Reporting a user is otherwise only reachable from chat, post-match, so this
/// is the only pre-match safety entry point for a bad host seen in discovery.
class _MealSafetyActions extends ConsumerWidget {
  const _MealSafetyActions({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewerUid = ref.watch(authStateProvider).value?.uid;
    // Nothing to report or block on your own meal.
    if (viewerUid != null && viewerUid == meal.hostId) {
      return const SizedBox.shrink();
    }

    return SafetyActions(
      reportTargetType: 'meal',
      reportTargetId: meal.id,
      reportLabel: 'Report this meal',
      secondaryReportTargetType: 'user',
      secondaryReportTargetId: meal.hostId,
      secondaryReportLabel: 'Report host',
      blockUid: meal.hostId,
      blockLabel: 'Block host',
    );
  }
}

/// Text scale above which the "Women only" badge drops below the name so a
/// long name and the badge never fight for one row.
const _stackBadgeTextScale = 1.5;

/// Restaurant name with the optional "Women only" badge: side by side at
/// normal text sizes, stacked at large accessibility sizes (no overflow).
class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final name = Text(
      meal.restaurant.name,
      style: textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: WarmPlayfulType.h2Weight,
      ),
    );
    if (!meal.womenOnly) return name;

    final badge = _WomenOnlyBadge(textTheme: textTheme);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > _stackBadgeTextScale;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          name,
          const SizedBox(height: WarmPlayfulSpacing.s2),
          badge,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: name),
        const SizedBox(width: WarmPlayfulSpacing.s2),
        badge,
      ],
    );
  }
}

class _WomenOnlyBadge extends StatelessWidget {
  const _WomenOnlyBadge({required this.textTheme});

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
        color: context.wp.peach,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.pill),
      ),
      child: Text(
        'Women only',
        style: textTheme.bodySmall?.copyWith(
          color: context.wp.onAccent,
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
            style: textTheme.bodyMedium?.copyWith(color: context.wp.muted),
          );
        }

        final photoUrl = host.photoUrls.isNotEmpty
            ? host.photoUrls.first
            : null;
        final age = host.ageYears;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: WarmPlayfulSpacing.s5,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: photoUrl != null
                  ? avatarImage(context, photoUrl, radius: WarmPlayfulSpacing.s5)
                  : null,
              onBackgroundImageError:
                  photoUrl != null ? ignoreAvatarImageError : null,
              child: photoUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      size: WarmPlayfulSpacing.s5,
                      color: context.wp.muted,
                    )
                  : null,
            ),
            const SizedBox(width: WarmPlayfulSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    age == null
                        ? (host.displayName ?? 'Host')
                        : '${host.displayName ?? 'Host'}, $age',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: WarmPlayfulType.h2Weight,
                    ),
                  ),
                  const SizedBox(height: WarmPlayfulSpacing.s1),
                  RatingBadge(uid: hostId),
                  if (host.bio != null && host.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Text(
                      host.bio!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.wp.muted,
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

/// "Open in Maps" — secondary (outlined) action on the restaurant card.
///
/// Fires `directions_opened` on tap (intent), then hands off to the maps app.
/// A launch already in flight swallows further taps; a failed launch shows a
/// snackbar and leaves the button usable.
class _OpenInMapsButton extends ConsumerStatefulWidget {
  const _OpenInMapsButton({required this.restaurant});

  final Restaurant restaurant;

  @override
  ConsumerState<_OpenInMapsButton> createState() => _OpenInMapsButtonState();
}

class _OpenInMapsButtonState extends ConsumerState<_OpenInMapsButton> {
  bool _launching = false;

  Future<void> _open() async {
    if (_launching) return;
    _launching = true;
    try {
      // Read before the first await: `ref` is unusable once the screen is
      // popped while the analytics send is in flight.
      final launch = ref.read(mapsLauncherProvider);
      await analytics.track(const DirectionsOpened());
      final opened = await launch(widget.restaurant);
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Couldn't open Maps")));
      }
    } finally {
      _launching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The visible label is excluded; one merged announcement carries the
    // restaurant name and the tap action.
    return Semantics(
      button: true,
      label: 'Open ${widget.restaurant.name} in Maps',
      excludeSemantics: true,
      onTap: _open,
      child: OutlinedButton.icon(
        key: const Key('meal_detail_open_in_maps_button'),
        onPressed: _open,
        icon: const Icon(Icons.place_outlined),
        label: const Text('Open in Maps'),
      ),
    );
  }
}
