/// Discovery feed screen (`/discover`) — the app's home screen, the
/// Discover tab of the bottom-navigation shell (`app_shell.dart`).
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
/// Carries the "Create a meal" entry point into meal creation (`/meals/new`)
/// as both the FAB and the empty state's action. Sign-out lives in Settings.
/// Pull-to-refresh invalidates [locationProvider] — [discoveryControllerProvider]
/// watches it, so a fresh location re-runs the geohash-scoped query.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/avatar_image.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/application/paris_notice_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/presentation/widgets/paris_notice.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  Future<void> _onRefresh() async {
    ref
      ..invalidate(locationProvider)
      ..invalidate(discoveryControllerProvider);
    // Await the refreshed location so the pull-to-refresh spinner stays up
    // for the duration of the underlying fetch, rather than dismissing
    // immediately after firing the invalidations above.
    await ref.read(locationProvider.future);
  }

  Future<void> _onTapMeal(DiscoverableMeal item) async {
    await analytics.track(MealOpened(womenOnly: item.meal.womenOnly));
    if (!mounted) return;
    await context.push('/meals/detail', extra: item.meal);
  }

  void _createMeal() => unawaited(context.push('/meals/new'));

  Widget _notice() => ParisNotice(
    onDismiss: () =>
        unawaited(ref.read(parisNoticeControllerProvider.notifier).dismiss()),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(discoveryControllerProvider);
    final noticeDismissed = ref.watch(parisNoticeControllerProvider);
    final viewerGender = ref.watch(currentUserDocProvider).value?.gender;

    // Loading / empty / error: the shared state widget under the notice.
    Widget stateBody(Widget child) => Column(
      children: [
        if (!noticeDismissed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WarmPlayfulSpacing.s4,
              WarmPlayfulSpacing.s4,
              WarmPlayfulSpacing.s4,
              0,
            ),
            child: _notice(),
          ),
        Expanded(child: child),
      ],
    );

    final body = state.when(
      loading: () => stateBody(const SkeletonList()),
      error: (error, stackTrace) => stateBody(
        ErrorState(
          // Same path as pull-to-refresh: also re-reads the location, so a
          // cached upstream error cannot make Try again a dead button.
          onRetry: () => unawaited(_onRefresh()),
        ),
      ),
      data: (meals) {
        if (meals.isEmpty) {
          return stateBody(
            EmptyState(
              icon: Icons.restaurant_rounded,
              title: l10n.discoverEmptyTitle,
              message: l10n.discoverEmptyMessage,
              action: AppButton(
                key: const Key('discovery_empty_create_button'),
                label: l10n.discoverCreateMeal,
                onPressed: _createMeal,
              ),
            ),
          );
        }
        final lead = noticeDismissed ? 0 : 1;
        final count = meals.length + lead;
        return ListView.builder(
          // Clears the extended FAB so the last card is never hidden by it.
          padding: const EdgeInsets.fromLTRB(
            WarmPlayfulSpacing.s4,
            WarmPlayfulSpacing.s4,
            WarmPlayfulSpacing.s4,
            WarmPlayfulSize.actionHeight + WarmPlayfulSpacing.s8,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, index) {
            final Widget child;
            if (index < lead) {
              child = _notice();
            } else {
              final item = meals[index - lead];
              child = _MealCard(
                key: Key('discovery_meal_card_${item.meal.id}'),
                item: item,
                showWomenOnlyBadge:
                    item.meal.womenOnly && viewerGender == Gender.woman,
                onTap: () => unawaited(_onTapMeal(item)),
              );
            }
            return index == count - 1
                ? child
                : Padding(
                    padding: const EdgeInsets.only(
                      bottom: WarmPlayfulSpacing.s3,
                    ),
                    child: child,
                  );
          },
        );
      },
    );

    final isEmpty = state.when(
      data: (meals) => meals.isEmpty,
      loading: () => false,
      error: (error, stackTrace) => false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(FlavorConfig.current.appTitle)),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _onRefresh, child: body),
      ),
      // The empty state has its own Create a meal button: no second one.
      floatingActionButton: isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('discovery_create_meal_button'),
              onPressed: _createMeal,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.discoverCreateMeal),
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
    final locale = Localizations.localeOf(context);

    return Material(
      color: colors.surface,
      elevation: WarmPlayfulElevation.card,
      shadowColor: context.wp.shadow,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wrap, not Row: at large text scales the badge drops under
              // the name instead of overflowing.
              Wrap(
                spacing: WarmPlayfulSpacing.s2,
                runSpacing: WarmPlayfulSpacing.s1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    meal.restaurant.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: WarmPlayfulType.h2Weight,
                    ),
                  ),
                  if (showWomenOnlyBadge) const _WomenOnlyBadge(),
                ],
              ),
              const SizedBox(height: WarmPlayfulSpacing.s1),
              Text(
                '${formatMealDateTime(meal.dateTime, locale: locale)} · '
                '${context.l10n.discoverDistanceKm(item.distanceMeters / 1000)}',
                // Two lines: at large text the distance wraps instead of
                // being cut off.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: context.wp.muted),
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
    final textTheme = theme.textTheme;

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
        context.l10n.mealWomenOnly,
        style: textTheme.bodySmall?.copyWith(
          color: context.wp.onAccent,
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
        final photoUrl = (host != null && host.photoUrls.isNotEmpty)
            ? host.photoUrls.first
            : null;

        return Row(
          children: [
            CircleAvatar(
              radius: WarmPlayfulSpacing.s4,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: photoUrl != null
                  ? avatarImage(
                      context,
                      photoUrl,
                      radius: WarmPlayfulSpacing.s4,
                    )
                  : null,
              onBackgroundImageError: photoUrl != null
                  ? ignoreAvatarImageError
                  : null,
              child: photoUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      size: WarmPlayfulSpacing.s4,
                      color: context.wp.muted,
                    )
                  : null,
            ),
            const SizedBox(width: WarmPlayfulSpacing.s2),
            Flexible(
              child: Text(
                host?.displayName ?? context.l10n.mealHostFallbackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
              ),
            ),
          ],
        );
      },
    );
  }
}
