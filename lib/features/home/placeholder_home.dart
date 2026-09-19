import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';

/// Temporary placeholder home screen (`/`).
///
/// Carries a "Sign out" action so the sign-in -> age-gate -> home loop is
/// manually testable end to end (Plan 2, Task 10) before a real home screen
/// exists. Calling `AuthRepository.signOut()` clears the session;
/// `authStateProvider` picks that up and the router's redirect sends the
/// user back to `/auth/signin`.
class PlaceholderHome extends ConsumerWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlavorConfig.current.appTitle),
        actions: [
          IconButton(
            key: const Key('placeholder_home_sign_out_button'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: const Center(child: Text('not-eat-alone — foundation OK')),
    );
  }
}
