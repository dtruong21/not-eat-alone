# not-eat-alone — Plan 1: Foundation & Environments

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this templates repo into the `not-eat-alone` Flutter app, with `stage` and `prod` flavors each wired to their own Firebase project, building and running on iOS + Android to a placeholder home.

**Architecture:** Promote the `flutter/` template to the repo root and delete the other stack. Generate the native Flutter shell with the CLI, pin deps from `docs/MASTER-SPEC.md`. Two build flavors (`stage`, `prod`) select the Firebase project at compile time via separate `firebase_options_*.dart` files and separate application IDs; a `FlavorConfig` object read at startup drives Firebase init.

**Tech Stack:** Flutter 3.44.x (FVM), Dart, Firebase (Core/Auth/Firestore/Functions/Messaging), Riverpod, go_router, FlutterFire CLI, Codemagic CI.

## Global Constraints

- Flutter SDK pinned to **3.44.x** via `.fvmrc`; Dart from Flutter. (from MASTER-SPEC)
- Packages caret-pinned in `pubspec.yaml` to the versions in `docs/MASTER-SPEC.md`.
- Lint preset: `very_good_analysis` + `custom_lint` in `analysis_options.yaml`.
- Base application id: **`com.daki.noteatalone`** (prod); stage suffix **`.stage`** → `com.daki.noteatalone.stage`.
- Firebase projects: prod = **`not-eat-alone`** (#966331142604, org `daki-tle-26-org`); stage = **`not-eat-alone-stage`** (created in Task 6).
- All Firestore access must go through `lib/core/firebase/*_repository.dart` (no direct calls in widgets). (from MASTER-SPEC)
- `firebase_options_*.dart` are committed (public keys, not secrets); `.env` is git-ignored.
- Age policy 18+ and Paris-only launch are downstream (Plans 2/5/11), not this plan.

---

### Task 1: Repo restructure & template cleanup

**Files:**
- Remove: `react-native/`, `scripts/new-project.sh` (root), root `CLAUDE.md`, `DUAL-PC-WORKFLOW.md`, `ONBOARDING.md`, `SETUP.md`, root `.gitignore`, `flutter/README.md`, `flutter/SETUP.md`
- Move: everything else under `flutter/` up to repo root
- Keep: root `LICENSE`, root `README.md`, `docs/superpowers/**`

**Interfaces:**
- Produces: repo root now contains `lib/`, `firebase/`, `design-systems/`, `scripts/pick-design-system.sh`, `.claude/`, `CLAUDE.md` (Flutter template's), `analysis_options.yaml`, `codemagic.yaml`, `firebase.json`, `.env.example`, `CHANGELOG.md`, and merged `docs/` (template docs + `superpowers/`).

- [ ] **Step 1: Confirm clean tree and branch**

```bash
git status --porcelain    # expect empty
git checkout -b plan-1-foundation
```

- [ ] **Step 2: Delete the other stack + root-only template scaffolding**

```bash
git rm -r react-native scripts
git rm CLAUDE.md DUAL-PC-WORKFLOW.md ONBOARDING.md SETUP.md .gitignore
```

(Root `LICENSE`, `README.md`, and `docs/superpowers/` intentionally remain.)

- [ ] **Step 3: Merge template docs into the app `docs/`**

`docs/` currently holds only `superpowers/`, so there are no collisions.

```bash
git mv flutter/docs/* docs/
git rm flutter/README.md flutter/SETUP.md
```

- [ ] **Step 4: Promote the rest of `flutter/` to root**

```bash
git mv flutter/.claude .claude
git mv flutter/.gitignore .gitignore
git mv flutter/.env.example .env.example
git mv flutter/CLAUDE.md CLAUDE.md
git mv flutter/analysis_options.yaml flutter/codemagic.yaml flutter/firebase.json flutter/CHANGELOG.md .
git mv flutter/firebase flutter/lib flutter/design-systems flutter/scripts .
rmdir flutter
```

- [ ] **Step 5: Verify structure**

```bash
test ! -d flutter && test ! -d react-native && echo "stacks removed OK"
ls lib firebase design-systems .claude CLAUDE.md analysis_options.yaml codemagic.yaml   # all present
ls docs/superpowers/specs docs/MASTER-SPEC.md                                            # both present
```
Expected: prints paths with no "No such file" errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: promote flutter template to root, drop other stack"
```

---

### Task 2: Generate Flutter shell, deps, SDK pin, lints

**Files:**
- Create: `pubspec.yaml`, `android/`, `ios/`, `.fvmrc`, default `lib/main.dart` (temporary, replaced in Task 7)
- Modify: `analysis_options.yaml` (already template-provided; confirm content)

**Interfaces:**
- Produces: a compiling Flutter project with all MASTER-SPEC runtime + dev deps resolved.

- [ ] **Step 1: Pin the Flutter SDK**

```bash
echo '{ "flutter": "3.44.0" }' > .fvmrc
fvm install && fvm use 3.44.0 --force
```
(If `fvm` is not installed: `dart pub global activate fvm`. All subsequent `flutter`/`dart` commands may be prefixed `fvm`.)

- [ ] **Step 2: Generate native shell over the existing tree**

`flutter create` is safe over an existing dir; it adds `pubspec.yaml`, `android/`, `ios/` and a demo `lib/main.dart` without deleting `lib/core/`.

```bash
fvm flutter create . --org com.daki.noteatalone --project-name not_eat_alone --platforms=ios,android
```

- [ ] **Step 3: Add runtime deps (versions per `docs/MASTER-SPEC.md`)**

```bash
fvm flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_analytics firebase_messaging
fvm flutter pub add flutter_riverpod riverpod_annotation
fvm flutter pub add freezed_annotation json_annotation
fvm flutter pub add go_router
fvm flutter pub add google_fonts lucide_icons flutter_animate
fvm flutter pub add sentry_flutter posthog_flutter
fvm flutter pub add flutter_dotenv
```

- [ ] **Step 4: Add dev deps**

```bash
fvm flutter pub add --dev build_runner freezed json_serializable \
  riverpod_generator riverpod_lint custom_lint go_router_builder \
  mocktail very_good_analysis flutter_launcher_icons flutter_native_splash
```

- [ ] **Step 5: Pin versions + confirm lint config**

Open `pubspec.yaml`; change every `^`-added dep to the exact caret version listed in `docs/MASTER-SPEC.md`. Confirm `analysis_options.yaml` reads:

```yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

- [ ] **Step 6: Resolve + analyze**

```bash
fvm flutter pub get
fvm flutter analyze
```
Expected: `pub get` succeeds; `analyze` reports no errors (demo `main.dart` may warn — fine, replaced in Task 7).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: generate flutter shell and pin dependencies"
```

---

### Task 3: Design system + placeholder fill + doc trim

**Files:**
- Create: `lib/core/design/tokens.dart`, `lib/core/design/theme.dart`, `docs/DESIGN.md` (via picker)
- Remove: `design-systems/` (picker removes it)
- Modify: template docs/`CLAUDE.md` placeholders (`{{PROJECT_NAME}}` etc.)

**Interfaces:**
- Produces: `buildTheme(Brightness)` in `lib/core/design/theme.dart` (consumed by Task 7).

- [ ] **Step 1: Pick the design system**

Consumer, warm concept → `warm-playful`.

```bash
./scripts/pick-design-system.sh warm-playful
```

- [ ] **Step 2: Fill template placeholders**

```bash
PROJECT_NAME="not-eat-alone" grep -rl "{{PROJECT_NAME}}" . --exclude-dir=.dart_tool --exclude-dir=build --exclude-dir=.git \
  | xargs sed -i "" "s/{{PROJECT_NAME}}/not-eat-alone/g"
```

Then hand-edit remaining markers (`{{ONE_LINE_PITCH}}`, `{{WHY}}`, `{{DIFFERENTIATOR}}`, `{{DATE}}`, `{{N}}`) in `CLAUDE.md`, `docs/PRD.md`, `docs/ROADMAP.md`, `docs/SECURITY.md`, `docs/RELEASE.md`, `docs/STORE_METADATA.md`, `docs/legal/privacy.md`, `docs/legal/terms.md`, using the spec:
- pitch = "Post a meal at a restaurant, match 1:1 with someone nearby, and don't eat alone."
- differentiator = "Meal-first, not people-first — organized around trying a restaurant, not swiping."
- date = 2026-09-18; N = leave as the team's estimate or set to a placeholder number.

- [ ] **Step 3: Verify no stray placeholders**

```bash
! grep -rn "{{" --include=*.md --include=*.dart . --exclude-dir=.git && echo "no placeholders"
```
Expected: prints `no placeholders`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: pick warm-playful design system and fill project placeholders"
```

---

### Task 4: Android build flavors

**Files:**
- Modify: `android/app/build.gradle` (or `build.gradle.kts`)

**Interfaces:**
- Produces: Gradle product flavors `stage` and `prod` with application ids `com.daki.noteatalone.stage` and `com.daki.noteatalone`.

- [ ] **Step 1: Add a `flavor` dimension**

In `android/app/build.gradle`, inside `android { ... }`:

```gradle
flavorDimensions "env"
productFlavors {
    stage {
        dimension "env"
        applicationId "com.daki.noteatalone.stage"
        resValue "string", "app_name", "not-eat-alone (stage)"
    }
    prod {
        dimension "env"
        applicationId "com.daki.noteatalone"
        resValue "string", "app_name", "not-eat-alone"
    }
}
```

- [ ] **Step 2: Use `app_name` for the launcher label**

In `android/app/src/main/AndroidManifest.xml`, set `android:label="@string/app_name"` on `<application>`.

- [ ] **Step 3: Verify each flavor assembles**

```bash
fvm flutter build apk --flavor stage --debug -t lib/main_stage.dart 2>&1 | tail -5 || true
```
(This will fail until Task 7 creates `lib/main_stage.dart`; run the real verification in Task 7. For now just confirm Gradle parses:)
```bash
cd android && ./gradlew tasks --console=plain >/dev/null && echo "gradle OK"; cd ..
```
Expected: `gradle OK`.

- [ ] **Step 4: Commit**

```bash
git add android/
git commit -m "build(android): add stage and prod product flavors"
```

---

### Task 5: iOS build flavors (schemes + configs)

**Files:**
- Modify: `ios/Runner.xcodeproj` (schemes `stage`, `prod`), `ios/Flutter/*.xcconfig`

**Interfaces:**
- Produces: Xcode schemes `stage` and `prod` with bundle ids `com.daki.noteatalone.stage` and `com.daki.noteatalone`.

- [ ] **Step 1: Create per-flavor xcconfig files**

Create `ios/Flutter/Stage.xcconfig`:
```
#include "Generated.xcconfig"
FLUTTER_TARGET=lib/main_stage.dart
PRODUCT_BUNDLE_IDENTIFIER=com.daki.noteatalone.stage
DISPLAY_NAME=not-eat-alone (stage)
```
Create `ios/Flutter/Prod.xcconfig`:
```
#include "Generated.xcconfig"
FLUTTER_TARGET=lib/main_prod.dart
PRODUCT_BUNDLE_IDENTIFIER=com.daki.noteatalone
DISPLAY_NAME=not-eat-alone
```

- [ ] **Step 2: Add build configurations + schemes in Xcode**

Open `ios/Runner.xcworkspace` in Xcode → duplicate the `Debug`/`Release`/`Profile` configs into `Debug-stage`, `Release-stage`, `Profile-stage`, `Debug-prod`, `Release-prod`, `Profile-prod`, each pointing at the matching xcconfig. Create two schemes `stage` and `prod` mapped to those configs. Set `$(DISPLAY_NAME)` as `CFBundleDisplayName` and `$(PRODUCT_BUNDLE_IDENTIFIER)` in `ios/Runner/Info.plist`.

- [ ] **Step 3: Verify a flavor scheme resolves**

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme stage -showBuildSettings 2>/dev/null | grep PRODUCT_BUNDLE_IDENTIFIER | head -1
```
Expected: shows `com.daki.noteatalone.stage`.

- [ ] **Step 4: Commit**

```bash
git add ios/
git commit -m "build(ios): add stage and prod schemes and configs"
```

---

### Task 6: Firebase environments (stage + prod)

**Files:**
- Create: `lib/core/firebase/options/firebase_options_stage.dart`, `lib/core/firebase/options/firebase_options_prod.dart`, `.firebaserc`
- Modify: `firebase.json` (deploy targets), `android/app/` + `ios/Runner/` google-services / plist per flavor

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` in each options file (consumed by `FlavorConfig` in Task 7).

- [ ] **Step 1: Create the stage Firebase project**

In the Firebase console (org `daki-tle-26-org`), create project **`not-eat-alone-stage`**. Enable Authentication, Firestore, Storage, Cloud Messaging on both `not-eat-alone-stage` and `not-eat-alone`.

- [ ] **Step 2: Configure FlutterFire for prod**

```bash
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=not-eat-alone \
  --out=lib/core/firebase/options/firebase_options_prod.dart \
  --ios-bundle-id=com.daki.noteatalone \
  --android-package-name=com.daki.noteatalone \
  --platforms=ios,android
```

- [ ] **Step 3: Configure FlutterFire for stage**

```bash
flutterfire configure \
  --project=not-eat-alone-stage \
  --out=lib/core/firebase/options/firebase_options_stage.dart \
  --ios-bundle-id=com.daki.noteatalone.stage \
  --android-package-name=com.daki.noteatalone.stage \
  --platforms=ios,android
```

- [ ] **Step 4: Place per-flavor native config files**

Move each generated `google-services.json` under `android/app/src/stage/` and `android/app/src/prod/`. Place each `GoogleService-Info.plist` in a per-flavor group and reference it from the matching Xcode scheme (a build-phase script that copies the right plist per configuration is the standard approach).

- [ ] **Step 5: Wire `.firebaserc` deploy aliases**

```json
{
  "projects": { "stage": "not-eat-alone-stage", "prod": "not-eat-alone" }
}
```

- [ ] **Step 6: Verify options compile**

```bash
fvm flutter analyze lib/core/firebase/options/
```
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore(firebase): configure stage and prod projects and options"
```

---

### Task 7: Flavor-aware bootstrap + placeholder home

**Files:**
- Create: `lib/core/config/flavor.dart`, `lib/main_common.dart`, `lib/main_stage.dart`, `lib/main_prod.dart`, `lib/features/home/placeholder_home.dart`
- Create test: `test/core/config/flavor_test.dart`
- Modify: `lib/core/routing/router.dart` (route `/` → placeholder home)
- Remove: default `lib/main.dart` (replaced by flavor entrypoints)

**Interfaces:**
- Consumes: `buildTheme(Brightness)` (Task 3), `firebase_options_stage/prod.dart` (Task 6).
- Produces: `enum Flavor { stage, prod }`, `class FlavorConfig { final Flavor flavor; final FirebaseOptions firebaseOptions; ... }`, `FlavorConfig.current` (a global set in each entrypoint), and `Future<void> bootstrap(FlavorConfig)`.

- [ ] **Step 1: Write the failing test for flavor resolution**

`test/core/config/flavor_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/flavor.dart';

void main() {
  test('FlavorConfig exposes its flavor and a display suffix', () {
    final cfg = FlavorConfig(flavor: Flavor.stage);
    expect(cfg.flavor, Flavor.stage);
    expect(cfg.isStage, true);
    expect(cfg.appTitle, 'not-eat-alone (stage)');

    final prod = FlavorConfig(flavor: Flavor.prod);
    expect(prod.isStage, false);
    expect(prod.appTitle, 'not-eat-alone');
  });
}
```

- [ ] **Step 2: Run it, verify it fails**

```bash
fvm flutter test test/core/config/flavor_test.dart
```
Expected: FAIL — `flavor.dart` / `FlavorConfig` not found.

- [ ] **Step 3: Implement `lib/core/config/flavor.dart`**

```dart
enum Flavor { stage, prod }

class FlavorConfig {
  FlavorConfig({required this.flavor});

  final Flavor flavor;
  static late FlavorConfig current;

  bool get isStage => flavor == Flavor.stage;
  String get appTitle =>
      isStage ? 'not-eat-alone (stage)' : 'not-eat-alone';
}
```

- [ ] **Step 4: Run the test, verify it passes**

```bash
fvm flutter test test/core/config/flavor_test.dart
```
Expected: PASS.

- [ ] **Step 5: Add the placeholder home**

`lib/features/home/placeholder_home.dart`:
```dart
import 'package:flutter/material.dart';
import '../../core/config/flavor.dart';

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(FlavorConfig.current.appTitle)),
      body: const Center(child: Text('not-eat-alone — foundation OK')),
    );
  }
}
```
Point the `/` route in `lib/core/routing/router.dart` at `PlaceholderHome`.

- [ ] **Step 6: Write the shared bootstrap + entrypoints**

`lib/main_common.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/flavor.dart';
import 'core/design/theme.dart';
import 'core/routing/router.dart';

Future<void> bootstrap({
  required FlavorConfig config,
  required FirebaseOptions options,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.current = config;
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: options);
  runApp(ProviderScope(child: NotEatAloneApp()));
}

class NotEatAloneApp extends StatelessWidget {
  NotEatAloneApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: FlavorConfig.current.appTitle,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        routerConfig: appRouter,
      );
}
```
`lib/main_stage.dart`:
```dart
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/options/firebase_options_stage.dart';
import 'package:not_eat_alone/main_common.dart';

Future<void> main() => bootstrap(
      config: FlavorConfig(flavor: Flavor.stage),
      options: DefaultFirebaseOptions.currentPlatform,
    );
```
`lib/main_prod.dart`:
```dart
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/options/firebase_options_prod.dart';
import 'package:not_eat_alone/main_common.dart';

Future<void> main() => bootstrap(
      config: FlavorConfig(flavor: Flavor.prod),
      options: DefaultFirebaseOptions.currentPlatform,
    );
```
Delete the demo `lib/main.dart`. Ensure `appRouter` in `lib/core/routing/router.dart` is a `GoRouter` exposing `/` → `PlaceholderHome`.

- [ ] **Step 7: Create a `.env` from the example**

```bash
cp .env.example .env
```
(`.env` stays git-ignored; fill real POSTHOG/SENTRY keys later — empty is fine for boot.)

- [ ] **Step 8: Run both flavors on both platforms**

```bash
fvm flutter run -t lib/main_stage.dart --flavor stage   # verify title shows "(stage)"
fvm flutter run -t lib/main_prod.dart  --flavor prod    # verify title shows "not-eat-alone"
```
Do this once on an Android emulator and once on an iOS simulator. Expected: app launches to the placeholder home with the correct title, no Firebase init error (confirms the right `firebase_options_*` loaded).

- [ ] **Step 9: Full analyze + test**

```bash
fvm flutter analyze && fvm flutter test
```
Expected: no analyzer errors; all tests pass.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: flavor-aware bootstrap booting to placeholder home"
```

---

### Task 8: CI baseline (Codemagic) + finalize

**Files:**
- Modify: `codemagic.yaml` (analyze + test workflow), root `README.md`

**Interfaces:**
- Produces: a CI workflow that runs `flutter analyze` + `flutter test` on every push.

- [ ] **Step 1: Confirm/author a lint+test workflow**

Ensure `codemagic.yaml` has a workflow that installs the pinned Flutter, runs `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`. (Template ships a `codemagic.yaml`; adjust its Flutter version to 3.44.0 and confirm the analyze/test steps exist.)

- [ ] **Step 2: Run the same steps locally as a proxy for CI**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze
fvm flutter test
```
Expected: build_runner succeeds; analyze clean; tests pass.

- [ ] **Step 3: Update the app README**

Replace the placeholder body of root `README.md` with: one-line pitch, the two-flavor run commands (`flutter run -t lib/main_stage.dart --flavor stage` / prod), and a link to the spec + roadmap.

- [ ] **Step 4: Commit and open PR**

```bash
git add -A
git commit -m "ci: add analyze+test workflow and update README"
git push -u origin plan-1-foundation
```
Open a PR into `main` on `github.com/dtruong21/not-eat-alone`. (Requires the GitHub repo to exist and push access configured.)

---

## Self-review notes

- **Spec coverage (this plan's slice):** stack (§4), environments/flavors (§6), auth-provider *dependencies* only wired here — actual auth is Plan 2; template cleanup requested by user is Task 1. ✔
- **Deferred by design:** auth, profile, meals, discovery, chat, push, safety, ratings, store — each its own later plan per the roadmap.
- **Placeholder scan:** none — all steps carry concrete commands/code. The one unavoidable manual UI step (Xcode schemes, Task 5 Step 2) is spelled out because it has no reliable CLI.
- **Type consistency:** `FlavorConfig`, `Flavor`, `FlavorConfig.current`, `bootstrap(...)`, `buildTheme(Brightness)`, `appRouter`, `PlaceholderHome` used consistently across Tasks 3/6/7.
