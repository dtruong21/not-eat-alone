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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/home/placeholder_home.dart';

const _signInPath = '/auth/signin';
const _ageGatePath = '/onboarding/age';
const _homePath = '/';

/// Pure redirect decision for the three auth states. Kept side-effect-free
/// and exported so it's directly unit-testable without spinning up a
/// `GoRouter` — see `test/core/routing/redirect_test.dart`.
///
/// Rules:
///   - not signed in -> `/auth/signin` (unless already there, else a
///     redirect loop: go_router re-runs `redirect` on the target location).
///   - signed in, not age-verified -> `/onboarding/age` (unless already
///     there, same loop guard).
///   - signed in + age-verified, but sitting on an auth/onboarding screen ->
///     `/` (nothing left to gate on those screens).
///   - otherwise -> `null` (stay put).
String? authRedirect({
  required bool signedIn,
  required bool ageVerified,
  required String location,
}) {
  if (!signedIn) {
    return location == _signInPath ? null : _signInPath;
  }
  if (!ageVerified) {
    return location == _ageGatePath ? null : _ageGatePath;
  }
  if (location == _signInPath || location == _ageGatePath) {
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
  final ageVerified =
      ref.watch(currentUserDocProvider).value?.ageVerified ?? false;

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) => authRedirect(
      signedIn: signedIn,
      ageVerified: ageVerified,
      location: state.matchedLocation,
    ),
    routes: [
      // TODO: replace with `$homeRoute` from `routes.g.dart` once typed routes
      // are scaffolded. Inline route kept here so the template compiles before
      // codegen runs.
      GoRoute(
        path: _homePath,
        builder: (context, state) => const PlaceholderHome(),
      ),
      // TODO: replace with real screen (plan2 task 9).
      GoRoute(
        path: _signInPath,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('signin'))),
      ),
      // TODO: replace with real screen (plan2 task 10).
      GoRoute(
        path: _ageGatePath,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('age gate'))),
      ),
    ],
  );
});
