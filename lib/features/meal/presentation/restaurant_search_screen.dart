/// Restaurant search screen (`/meals/new`).
///
/// First step of meal creation: the host searches for a restaurant and taps
/// a result to continue. Search is delegated entirely to
/// [restaurantSearchControllerProvider] ([RestaurantSearchController]) —
/// this screen only owns the text field's controller and renders whatever
/// `AsyncValue<List<Restaurant>>` state comes back (loading / error /
/// empty / results).
///
/// Tapping a row fires `restaurant_selected` and pushes
/// `/meals/new/details` with the tapped [Restaurant] as `extra` — that
/// route is wired in a later task (Task 7); this screen only issues the
/// navigation call.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/features/meal/application/restaurant_search_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

/// Route path this screen pushes to when a restaurant is selected. Kept in
/// sync with the route wired in Task 7.
const createMealDetailsRoutePath = '/meals/new/details';

class RestaurantSearchScreen extends ConsumerStatefulWidget {
  const RestaurantSearchScreen({super.key});

  @override
  ConsumerState<RestaurantSearchScreen> createState() =>
      _RestaurantSearchScreenState();
}

class _RestaurantSearchScreenState
    extends ConsumerState<RestaurantSearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    unawaited(
      ref.read(restaurantSearchControllerProvider.notifier).search(value),
    );
  }

  Future<void> _onSelect(Restaurant restaurant) async {
    await analytics.track(const RestaurantSelected());
    if (!mounted) return;
    await context.push(createMealDetailsRoutePath, extra: restaurant);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restaurantSearchControllerProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final isLoading = state.isLoading;
    final hasError = state.hasError;

    Widget resultsBody;
    if (isLoading) {
      resultsBody = const Center(child: CircularProgressIndicator());
    } else if (hasError) {
      resultsBody = Center(
        child: Text(
          'Something went wrong — please try again.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.error),
        ),
      );
    } else {
      final restaurants = state.value ?? const <Restaurant>[];
      resultsBody = restaurants.isEmpty
          ? Center(
              child: Text(
                'No matches',
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
            )
          : ListView.separated(
              itemCount: restaurants.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: WarmPlayfulSpacing.s2),
              itemBuilder: (context, index) {
                final restaurant = restaurants[index];
                return _RestaurantRow(
                  key: Key('restaurant_row_${restaurant.placeId}'),
                  restaurant: restaurant,
                  onTap: () => _onSelect(restaurant),
                );
              },
            );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Find a restaurant')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WarmPlayfulSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('restaurant_search_field'),
                controller: _queryController,
                onChanged: _onQueryChanged,
                onSubmitted: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search restaurants',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s4),
              Expanded(child: resultsBody),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({
    required this.restaurant,
    required this.onTap,
    super.key,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WarmPlayfulSpacing.s4,
            vertical: WarmPlayfulSpacing.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant.name,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: WarmPlayfulType.h2Weight,
                ),
              ),
              const SizedBox(height: WarmPlayfulSpacing.s1),
              Text(
                restaurant.address,
                style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
