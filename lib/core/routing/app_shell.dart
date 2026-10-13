/// Bottom-navigation shell hosting the four primary destinations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/notifications/push_listener.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// Bottom-navigation shell hosting the four primary destinations. Each tab is
/// a branch of a StatefulShellRoute, so switching tabs preserves each stack.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRequestCountProvider);
    return Scaffold(
      body: PushListener(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: context.l10n.navDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: context.l10n.navChats,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.inbox),
            ),
            label: context.l10n.navRequests,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
