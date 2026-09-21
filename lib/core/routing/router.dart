/// App router — single `GoRouter` instance, exposed as a Riverpod provider so
/// it can react to auth state via `ref.watch`.
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
/// Auth redirects: read auth state inside the `redirect:` callback below. The
/// provider re-watches it, so the router rebuilds on sign-in / sign-out.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_screen.dart';
import 'package:not_eat_alone/features/auth/presentation/signin_screen.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/create_meal_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/meal_detail_screen.dart';
import 'package:not_eat_alone/features/meal/presentation/restaurant_search_screen.dart';
import 'package:not_eat_alone/features/onboarding/presentation/age_gate_screen.dart';
import 'package:not_eat_alone/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';

const _signInPath = '/auth/signin';
const _phoneVerifyPath = '/auth/phone';
const _ageGatePath = '/onboarding/age';
const _profileSetupPath = '/onboarding/profile';
const _homePath = '/';

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
///     auth/onboarding screen -> `/` (nothing left to gate on those screens
///     — this includes `/auth/phone`, so completing phone verification
///     advances home instead of stranding the user on the OTP screen).
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
/// Auth redirects: `signedIn`/`ageVerified` are computed here from
/// `authStateProvider` / `currentUserDocProvider` (both `ref.watch`, so a
/// new `GoRouter` — and therefore a fresh redirect decision — is built
/// whenever auth state changes) and handed to the pure `authRedirect`
/// above. While `currentUserDocProvider` is still loading for a signed-in
/// user we treat `ageVerified` as `false`; the `location == _ageGatePath`
/// guard in `authRedirect` stops that from bouncing a user who is already
/// sitting on the age gate mid-load.
final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ref.watch(authStateProvider).value != null;
  final userDoc = ref.watch(currentUserDocProvider).value;
  final ageVerified = userDoc?.ageVerified ?? false;
  final profileComplete = userDoc?.profileComplete ?? false;

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) => authRedirect(
      signedIn: signedIn,
      ageVerified: ageVerified,
      profileComplete: profileComplete,
      location: state.matchedLocation,
    ),
    routes: [
      // TODO: replace with `$homeRoute` from `routes.g.dart` once typed routes
      // are scaffolded. Inline route kept here so the template compiles before
      // codegen runs.
      GoRoute(
        path: _homePath,
        builder: (context, state) => const DiscoveryScreen(),
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
    ],
  );
});
