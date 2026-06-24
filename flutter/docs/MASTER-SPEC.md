# Master Spec

The single source of truth for the Flutter project template's stack picks, idioms, conventions, and the traps that bite. Every agent and slash command points back here when there's ambiguity. Update it when a pick changes; don't let it drift.

---

## 1. Pinned packages

Flutter SDK pinned to **3.44.x** via `.fvmrc`. Dart SDK comes from Flutter. All packages below are caret-pinned in `pubspec.yaml` — bump deliberately, not casually.

### Runtime

| Package | Why |
|---|---|
| `firebase_core` | Initializes FlutterFire. Required first import in `main()`. |
| `firebase_auth` | Anonymous + email + OAuth. Anonymous-to-real linking preserves the uid. |
| `cloud_firestore` | Primary datastore. Wrapped exclusively in `lib/core/firebase/*_repository.dart`. |
| `cloud_functions` | Server-side callables (cascade-deletes, server validation). |
| `firebase_analytics` | First-party funnels. Kept thin — PostHog carries product analytics. |
| `flutter_riverpod` + `riverpod_annotation` | State + code-gen providers (`@riverpod`). |
| `go_router` | Single source of truth for routing. Used with `go_router_builder` for typed routes. |
| `freezed_annotation` + `json_annotation` | Sealed-class models with `fromJson` / `toJson`. |
| `google_fonts` | Inter / Nunito / JetBrains Mono loaded at runtime. |
| `lucide_icons` | Line icons across all three design systems. |
| `flutter_animate` | Declarative one-shot animations; pairs with token motion specs. |
| `posthog_flutter` | Product analytics — events from `lib/core/analytics/events.dart`. |
| `sentry_flutter` | Crash + perf reporting. Independent of product analytics. |
| `flutter_dotenv` | Loads `.env` at runtime. Bundled in the app — values here are NOT secret. |

### Dev

| Package | Why |
|---|---|
| `build_runner` | Drives Riverpod, freezed, json_serializable, go_router_builder codegen. |
| `freezed`, `json_serializable` | Generators paired with the annotations above. |
| `riverpod_generator`, `riverpod_lint`, `custom_lint` | Codegen + lint rules for Riverpod. |
| `go_router_builder` | Generates typed route classes from `@TypedGoRoute` annotations. |
| `mocktail` | Mocking for `flutter_test`. Modern Dart-first API; preferred over `mockito`. |
| `very_good_analysis` | Lint preset. Strict by default — extends in `analysis_options.yaml`. |
| `flutter_launcher_icons`, `flutter_native_splash` | Icon + splash generation from source assets. |
| `integration_test` (SDK) | End-to-end tests against a running app. |

Codemagic is the CI/CD platform — see `codemagic.yaml`. No EAS analog, no managed expo-style OTA updates.

---

## 2. Folder layout

```
lib/
  main.dart                          entry — Firebase + PostHog + Sentry + ProviderScope + router
  core/
    firebase/                        Firestore boundary (one repo per collection)
      firebase_client.dart           db + auth getters
      repository_exception.dart      typed parse/write errors
      <name>_repository.dart         per-collection repository with .withConverter
    design/
      tokens.dart                    from the chosen design system
      theme.dart                     ThemeData light + dark factories
    analytics/
      client.dart                    track / identify / reset
      events.dart                    sealed class AppEvent — the typed registry
    routing/
      router.dart                    GoRouter instance
      routes.dart                    @TypedGoRoute classes (generated → routes.g.dart)
  features/
    <name>/
      data/                          DTOs, mappers (when repository output needs transforming)
      domain/                        freezed models for this feature (sometimes the model lives next to the repo instead — that's fine)
      application/                   Riverpod providers (@riverpod AsyncNotifier)
      presentation/                  widgets + screens
test/
integration_test/
android/, ios/, web/                 platform code — created by `flutter create`
firebase/
  firestore.rules
  firestore.indexes.json
docs/                                this folder
design-systems/                      3 swappable systems — deleted after picker runs
.claude/                             agents + commands
scripts/                             pick-design-system.sh
```

---

## 3. Canonical idioms

### 3.1 Riverpod — AsyncNotifier with code-gen

One provider per data dependency. Lives at `lib/features/<name>/application/<name>_provider.dart`.

```dart
@riverpod
class HabitList extends _$HabitList {
  @override
  Future<List<Habit>> build() async {
    return ref.read(habitRepositoryProvider).list();
  }

  Future<void> add(Habit habit) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(habitRepositoryProvider).create(habit);
      return ref.read(habitRepositoryProvider).list();
    });
  }
}
```

Rules:
- **`ref.watch` only inside `build()`.** After `build()` (in methods like `add`), use `ref.read`. Violating this is the #1 cause of "provider keeps recomputing" bugs.
- **Mutations call `AsyncValue.guard`** so errors land in `state.error` instead of crashing.
- **Run `dart run build_runner watch -d`** during dev so `*.g.dart` stays fresh.

### 3.2 Routing — go_router with typed routes

All routes declared in `lib/core/routing/routes.dart`:

```dart
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

@TypedGoRoute<HabitRoute>(path: '/habit/:id')
class HabitRoute extends GoRouteData {
  const HabitRoute({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, GoRouterState state) => HabitScreen(id: id);
}
```

Navigate by calling `const HabitRoute(id: '...').push(context)` — no raw path strings, no string interpolation.

### 3.3 Repository pattern — `.withConverter` always

Pattern fixed in `lib/core/firebase/README.md`. Highlights:
- One file per collection.
- Every `CollectionReference<Model>` built with `.withConverter`.
- `fromFirestore` wraps `Model.fromJson` in try/catch that throws `RepositoryParseException`.
- Repository methods never return `null` to signal failure — only to signal valid absence.

### 3.4 Theming — Material 3 + ThemeExtension

`tokens.dart` holds raw values. `theme.dart` wires them into `ThemeData`:

```dart
ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppTokens.light.accent,
    brightness: Brightness.light,
  ).copyWith(
    surface: AppTokens.light.surface,
    outline: AppTokens.light.border,
  ),
  textTheme: GoogleFonts.interTextTheme(),
  extensions: const [AppExtensions.light],
);
```

`AppExtensions` (a `ThemeExtension` subclass) carries anything Material 3 doesn't natively express — heatmap palette, category palette, motion timings.

---

## 4. Conventions

- **File names**: `snake_case.dart`. Classes/types `PascalCase`. Functions/fields `camelCase`. Constants `lowerCamelCase` (not `SCREAMING_SNAKE`).
- **Imports**: `always_use_package_imports` lint enforces `package:my_app/...` over `../../foo.dart`. No relative imports across feature boundaries.
- **Error handling**: throw at boundaries (repositories, parsers). Catch at UI (`AsyncValue.error`). Never `catch (_) { return null; }` — that's how silent bugs ship.
- **`const` everywhere it applies.** `prefer_const_constructors` lint catches misses.
- **Generated files**: `*.g.dart` and `*.freezed.dart` are gitignored. `firebase_options.dart` is committed.
- **Tests live next to what they test.** `lib/features/habits/habits_provider.dart` → `test/features/habits/habits_provider_test.dart`.

---

## 5. Gotchas — the five traps that bite

### Gotcha 1 — Riverpod `ref.watch` after `build()`

Calling `ref.watch` inside a method (not `build()`) causes the provider to be rebuilt every time the watched dependency changes — usually not what you want. Symptom: provider runs in an infinite loop on hot reload. **Always use `ref.read` after `build()`**.

### Gotcha 2 — go_router_builder requires `part` directive

Forgetting `part 'routes.g.dart';` in `routes.dart` results in cryptic "unresolved identifier" errors with no hint about codegen. Always add the `part` directive when annotating a file.

### Gotcha 3 — Server timestamps are null on optimistic snapshots

`FieldValue.serverTimestamp()` writes server-side, but the local snapshot Firestore emits before the server round-trip has `createdAt: null`. If your freezed model declares `createdAt` as `DateTime` (non-nullable), `fromJson` throws on every write. **Server-set fields MUST be `DateTime?` on the model.**

### Gotcha 4 — `Timestamp` is not JSON-serializable

`json_serializable` can't marshal `Timestamp` ↔ Dart `DateTime`. Without a `JsonConverter<DateTime, Timestamp>`, `toJson` produces an ISO string that Firestore stores as plain text — `where('createdAt', isGreaterThan: ...)` silently returns no rows. **Annotate every `DateTime` field with `@TimestampConverter()`** (define the converter once in `lib/core/firebase/`).

### Gotcha 5 — flutter_dotenv values are bundled into the app

`.env` ships inside the app bundle. Any value there can be extracted by any user with the IPA/APK. This is FINE for Firebase web config and OAuth client IDs (they're not secret — see `docs/SECURITY.md`). It is NOT fine for service-account JSONs, OAuth client secrets, or signing keys. Those live with Codemagic / Firebase / EAS-equivalent — never in `.env`.

---

## 6. When this doc changes

- New pinned package version → update §1 and the `flutter pub add` block in `SETUP.md` at the same time.
- New idiom (e.g. switch from `flutter_animate` to `flutter_motion`) → update §3 here AND the relevant agent prompt.
- New gotcha discovered → append to §5 with a one-line cause + symptom + fix.

The agents (`mobile-engineer`, `qa-engineer`) point here by name. Keep it accurate.
