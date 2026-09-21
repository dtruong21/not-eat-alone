/// Discovery feed screen (`/`) — the app's home screen.
///
/// Renders whatever `AsyncValue<List<DiscoverableMeal>>`
/// [discoveryControllerProvider] reports (loading / error / empty / data),
/// one card per nearby meal, nearest first. Each card shows the restaurant
/// name, formatted date/time, distance from the viewer, the host's name +
/// thumbnail, and a "Women only" badge — shown only when both the meal is
/// women-only AND the viewer is a woman (the controller already filters out
/// women-only meals for non-women viewers, so this is a defensive
/// double-check, not new logic).
///
/// Carries the sign-out action (moved from the old `PlaceholderHome`) and
/// the "Create a meal" entry point into meal creation (`/meals/new`).
/// Pull-to-refresh invalidates [locationProvider] — [discoveryControllerProvider]
/// watches it, so a fresh location re-runs the geohash-scoped query.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

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
/// `create_meal_screen.dart`'s formatter, duplicated (not shared) since both
/// are small, presentation-only, private helpers.
String _formatDateTime(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '${_monthNames[dateTime.month - 1]} ${dateTime.day}, '
      '${dateTime.year} at $hour12:$minute $period';
}

String _formatDistance(double distanceMeters) =>
    '${(distanceMeters / 1000).toStringAsFixed(1)} km';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref
      ..invalidate(locationProvider)
      ..invalidate(discoveryControllerProvider);
    // Await the refreshed location so the pull-to-refresh spinner stays up
    // for the duration of the underlying fetch, rather than dismissing
    // immediately after firing the invalidations above.
    await ref.read(locationProvider.future);
  }

  Future<void> _onTapMeal(
    BuildContext context,
    DiscoverableMeal item,
  ) async {
    await analytics.track(MealOpened(womenOnly: item.meal.womenOnly));
    if (!context.mounted) return;
    await context.push('/meals/detail', extra: item.meal);
  }

  Widget _scrollableMessage(String message, {required Color color}) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(WarmPlayfulSpacing.s5),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryControllerProvider);
    final viewerGender = ref.watch(currentUserDocProvider).value?.gender;
    final pendingRequestCount = ref.watch(pendingRequestCountProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final body = state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _scrollableMessage(
        'Something went wrong — please try again.',
        color: colors.error,
      ),
      data: (meals) => meals.isEmpty
          ? _scrollableMessage(
              'No meals near you yet',
              color: colors.outline,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: meals.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: WarmPlayfulSpacing.s3),
              itemBuilder: (context, index) {
                final item = meals[index];
                return _MealCard(
                  key: Key('discovery_meal_card_${item.meal.id}'),
                  item: item,
                  showWomenOnlyBadge:
                      item.meal.womenOnly && viewerGender == Gender.woman,
                  onTap: () => _onTapMeal(context, item),
                );
              },
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(FlavorConfig.current.appTitle),
        actions: [
          IconButton(
            key: const Key('discovery_inbox_button'),
            tooltip: 'Requests',
            icon: Badge(
              key: const Key('discovery_inbox_badge'),
              isLabelVisible: pendingRequestCount > 0,
              label: Text('$pendingRequestCount'),
              child: const Icon(Icons.inbox_rounded),
            ),
            onPressed: () => context.push('/requests'),
          ),
          IconButton(
            key: const Key('discovery_sign_out_button'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _onRefresh(ref),
          child: body,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('discovery_create_meal_button'),
        onPressed: () => context.push('/meals/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create a meal'),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.item,
    required this.showWomenOnlyBadge,
    required this.onTap,
    super.key,
  });

  final DiscoverableMeal item;
  final bool showWomenOnlyBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final meal = item.meal;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.restaurant.name,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: WarmPlayfulType.h2Weight,
                      ),
                    ),
                  ),
                  if (showWomenOnlyBadge) ...[
                    const SizedBox(width: WarmPlayfulSpacing.s2),
                    const _WomenOnlyBadge(),
                  ],
                ],
              ),
              const SizedBox(height: WarmPlayfulSpacing.s1),
              Text(
                _formatDateTime(meal.dateTime),
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s1),
              Text(
                _formatDistance(item.distanceMeters),
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s3),
              _HostInfo(hostId: meal.hostId),
            ],
          ),
        ),
      ),
    );
  }
}

class _WomenOnlyBadge extends StatelessWidget {
  const _WomenOnlyBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

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

/// Small host row — thumbnail + display name — driven directly off
/// `UserRepository.watch(hostId)` via a [StreamBuilder]. Kept as a plain
/// stream (not a new Riverpod provider) since this is presentation-layer
/// scope; `ref.watch(userRepositoryProvider)` still goes through the typed
/// repository provider so tests can override it with a fake/mock.
class _HostInfo extends ConsumerWidget {
  const _HostInfo({required this.hostId});

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
        final host = snapshot.data;
        final photoUrl =
            (host != null && host.photoUrls.isNotEmpty)
                ? host.photoUrls.first
                : null;

        return Row(
          children: [
            CircleAvatar(
              radius: WarmPlayfulSpacing.s4,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      size: WarmPlayfulSpacing.s4,
                      color: colors.outline,
                    )
                  : null,
            ),
            const SizedBox(width: WarmPlayfulSpacing.s2),
            Text(
              host?.displayName ?? 'Host',
              style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            ),
          ],
        );
      },
    );
  }
}
