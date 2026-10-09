/// App router — single `GoRouter` instance, exposed as a Riverpod provider
/// and built once per provider lifetime (see [routerProvider]).
///
/// Adding routes:
///   1. Declare a typed route in `routes.dart` using `@TypedGoRoute<T>` on a
///      class that extends `GoRouteData` with a `const` constructor.
///      (Both are required — see master spec gotcha #5.)
///   2. Run `dart run build_runner watch -d` so `routes.g.dart` is regenerated.
///   3. Add the generated `$fooRoute` to the `routes:` list below.
///   4. Navigate with `const FooRoute(id: x).go(context)` — never raw paths.
///
/// Wiring in `app.dart`:
///
///   class App extends ConsumerWidget {
///     const App({super.key});
///
///     @override
///     Widget build(BuildContext context, WidgetRef ref) {
///       final router = ref.watch(routerProvider);
///       return MaterialApp.router(
///         routerConfig: router,
///         theme: buildTheme(Brightness.light),
///         darkTheme: buildTheme(Brightness.dark),
///       );
///     }
///   }
///
/// Auth redirects: the `redirect:` callback below reads auth state at call
/// time; a refresh notifier re-runs it when a redirect input changes. The
/// router itself is never rebuilt on auth or profile changes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/routing/app_shell.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_screen.dart';
import 'package:not_eat_alone/features/auth/presentation/signin_screen.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_list_screen.dart';
import 'package:not_eat_alone/features/chat/presentation/chat_screen.dart';
import 'package:not_eat_alone/features/matching/presentation/request_inbox_screen.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/create_meal_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/restaurant_search_screen.dart';
import 'package:not_eat_alone/features/onboarding/presentation/age_gate_screen.dart';
import 'package:not_eat_alone/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/presentation/profile_edit_screen.dart';

const _signInPath = '/auth/signin';
const _phoneVerifyPath = '/auth/phone';
const _ageGatePath = '/onboarding/age';
const _profileSetupPath = '/onboarding/profile';
const _homePath = '/discover';

/// Pure redirect decision for the four auth states. Kept side-effect-free
/// and exported so it's directly unit-testable without spinning up a
/// `GoRouter` — see `test/core/routing/redirect_test.dart`.
///
/// Rules:
///   - not signed in -> `/auth/signin` (unless already there, or on
///     `/auth/phone` — the phone-OTP screen is reached mid sign-in, before
///     `signedIn` flips true, so it must not bounce back to signin; else a
///     redirect loop: go_router re-runs `redirect` on the target location).
///   - signed in, not age-verified -> `/onboarding/age` (unless already
///     there, same loop guard).
///   - signed in + age-verified, but profile incomplete ->
///     `/onboarding/profile` (unless already there, same loop guard).
///   - signed in + age-verified + profile complete, but sitting on an
///     auth/onboarding screen -> `/discover` (nothing left to gate on those
///     screens — this includes `/auth/phone`, so completing phone
///     verification advances home instead of stranding the user on the OTP
///     screen).
///   - otherwise -> `null` (stay put).
String? authRedirect({
  required bool signedIn,
  required bool ageVerified,
  required bool profileComplete,
  required String location,
}) {
  if (!signedIn) {
    if (location == _signInPath || location == _phoneVerifyPath) return null;
    return _signInPath;
  }
  if (!ageVerified) {
    return location == _ageGatePath ? null : _ageGatePath;
  }
  if (!profileComplete) {
    return location == _profileSetupPath ? null : _profileSetupPath;
  }
  if (location == _signInPath ||
      location == _phoneVerifyPath ||
      location == _ageGatePath ||
      location == _profileSetupPath) {
    return _homePath;
  }
  return null;
}

/// The app's top-level router. Watch via `ref.watch(routerProvider)` in
/// `app.dart`. Wrap with `@riverpod` codegen once you have more than one
/// dependency, but keep the manual `Provider` here so the template runs
/// before `build_runner` is invoked.
///
/// Built ONCE per provider lifetime: rebuilding it on every `users/{uid}`
/// write reset navigation to the initial location (audit X-09). Instead the
/// three redirect inputs — `signedIn`, `ageVerified`, `profileComplete` — are
/// listened to as SELECTED bools; only a flip of one of them bumps
/// `refreshListenable`, which makes go_router re-run `redirect` against the
/// current location. Other user-doc fields (photos, name, bio, ratings) never
/// touch the router. `redirect` reads the current values with `ref.read` at
/// call time (so the first redirect sees the startup state, which
/// `ref.listen` — change-only — would miss) and hands them to the pure
/// `authRedirect` above. While `currentUserDocProvider` is still loading for a
/// signed-in user `ageVerified` is `false`; the `location == _ageGatePath`
/// guard in `authRedirect` stops that from bouncing a user who is already
/// sitting on the age gate mid-load.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump(Object? previous, Object? next) => refresh.value++;
  ref
    ..listen(authStateProvider.select((a) => a.value != null), bump)
    ..listen(
      currentUserDocProvider.select((u) => u.value?.ageVerified ?? false),
      bump,
    )
    ..listen(
      currentUserDocProvider.select((u) => u.value?.profileComplete ?? false),
      bump,
    );

  final router = GoRouter(
    initialLocation: _homePath,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final userDoc = ref.read(currentUserDocProvider).value;
      return authRedirect(
        signedIn: ref.read(authStateProvider).value != null,
        ageVerified: userDoc?.ageVerified ?? false,
        profileComplete: userDoc?.profileComplete ?? false,
        location: state.matchedLocation,
      );
    },
    routes: [
      // TODO: replace with typed routes from `routes.g.dart` once scaffolded.
      // Inline routes kept here so the template compiles before codegen runs.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: _homePath,
                builder: (context, state) => const DiscoveryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/requests',
                builder: (context, state) => const RequestInboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileEditScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: _signInPath,
        builder: (context, state) => const SigninScreen(),
      ),
      GoRoute(
        path: _phoneVerifyPath,
        builder: (context, state) => PhoneVerifyScreen(
          verificationId: state.extra! as String,
        ),
      ),
      GoRoute(
        path: _ageGatePath,
        builder: (context, state) => const AgeGateScreen(),
      ),
      GoRoute(
        path: _profileSetupPath,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/meals/new',
        builder: (context, state) => const RestaurantSearchScreen(),
      ),
      GoRoute(
        path: '/meals/new/details',
        builder: (context, state) {
          final restaurant = state.extra;
          if (restaurant is! Restaurant) {
            // Deep link / app restart on this path with no restaurant in
            // memory (`extra` doesn't survive process death) — fall back to
            // search instead of crashing on a bad cast.
            return const RestaurantSearchScreen();
          }
          return CreateMealScreen(restaurant: restaurant);
        },
      ),
      GoRoute(
        path: '/meals/detail',
        builder: (context, state) {
          final meal = state.extra;
          if (meal is! Meal) {
            // Deep link / app restart on this path with no meal in memory
            // (`extra` doesn't survive process death) — fall back to
            // discovery instead of crashing on a bad cast.
            return const DiscoveryScreen();
          }
          return MealDetailScreen(meal: meal);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/chats/:matchId',
        builder: (context, state) {
          final matchId = state.pathParameters['matchId'];
          if (matchId == null || matchId.isEmpty) {
            // Guard a missing/blank path param instead of crashing on a
            // non-null assertion — falls back to the chat list.
            return const ChatListScreen();
          }
          return ChatScreen(matchId: matchId);
        },
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
