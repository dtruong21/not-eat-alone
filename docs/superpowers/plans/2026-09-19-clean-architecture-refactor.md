# Clean Architecture Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the existing `auth` + `user` code into Pragmatic Clean Architecture (domain / data / application / presentation per feature, dependency inversion via abstract repository interfaces) with no behavior change, and codify the pattern in the constitution + scaffolding commands.

**Architecture:** Build the new feature layers additively first (they compile alongside the old code), then rewire the router + entrypoints + screens to the new providers, then delete the old `core/firebase` repositories + duplicate code, then update docs and slash commands. Each task ends green (`analyze` 0, tests pass).

**Tech Stack:** Flutter 3.47.4 (FVM), Riverpod, freezed 4, cloud_firestore, firebase_auth, google_sign_in v7, sign_in_with_apple, mocktail, fake_cloud_firestore.

**Base branch:** `plan-2-auth` (this branch, `refactor-clean-arch`, is stacked on it).

## Global Constraints

- Flutter 3.47.4 via FVM — all commands use `fvm flutter`/`fvm dart` (PATH += `$HOME/.pub-cache/bin`). (from Plan 1)
- **Dependency rule:** `presentation → application → domain ← data`. `domain/` has ZERO Flutter/Firebase imports. `cloud_firestore`/`firebase_auth`/`google_sign_in`/`sign_in_with_apple` imports allowed ONLY in a feature's `data/` layer. (spec §2)
- Per-feature folders: `domain/{entities,repositories}`, `data/{dtos,mappers,repositories}`, `application/`, `presentation/`. (spec §3)
- Entities = pure freezed (NO json). DTOs = freezed + json in `data/dtos/`. Mapping = extension methods in `data/mappers/`. (spec §3, §6)
- Codegen (`.g.dart`/`.freezed.dart`) is gitignored; run `fvm dart run build_runner build --delete-conflicting-outputs` after touching freezed/json. Tests + CI regenerate it.
- Typed exceptions `RepositoryParseException`/`RepositoryWriteException` (from `lib/core/firebase/repository_exception.dart`) used in data-layer repo impls.
- Flavor-aware `db` getter (`lib/core/firebase/firebase_client.dart`) is the Firestore entrypoint; prod → `(default)`, stage → `stage`.
- No behavior change; no product features; no Firestore data-shape/rules/deps changes.
- Verify each task: `fvm flutter analyze --no-fatal-infos` = 0, `fvm flutter test --concurrency=1` all pass. (`--concurrency=1` because the parallel reporter garbles logs in this sandbox.)
- Commit messages end with a blank line then `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

**Current → target file moves (reference):**
| Current | Target |
|---|---|
| `core/firebase/users_repository.dart` (concrete) | `features/user/domain/repositories/user_repository.dart` (abstract) + `features/user/data/repositories/user_repository_impl.dart` + `features/user/data/dtos/app_user_dto.dart` + `features/user/data/mappers/app_user_mapper.dart` |
| `features/auth/domain/app_user.dart` (entity+json) | `features/user/domain/entities/app_user.dart` (pure entity) + the DTO above |
| `core/firebase/auth_repository.dart` (concrete) | `features/auth/domain/repositories/auth_repository.dart` (abstract) + `features/auth/domain/entities/auth_user.dart` + `features/auth/data/repositories/auth_repository_impl.dart` |
| `features/auth/application/auth_providers.dart` | split → `features/auth/application/auth_providers.dart` (auth) + `features/user/application/user_providers.dart` (user + currentUserDoc) |
| `features/auth/presentation/age_gate_screen.dart` | `features/onboarding/presentation/age_gate_screen.dart` + `features/onboarding/application/age_gate_controller.dart` |
| `features/feedback/feedback_provider.dart` | deleted |

---

### Task 1: `user` feature (domain + data + application)

**Files:**
- Create: `lib/features/user/domain/entities/app_user.dart`, `lib/features/user/domain/repositories/user_repository.dart`, `lib/features/user/data/dtos/app_user_dto.dart`, `lib/features/user/data/mappers/app_user_mapper.dart`, `lib/features/user/data/repositories/user_repository_impl.dart`, `lib/features/user/application/user_providers.dart`
- Test: `test/features/user/domain/app_user_test.dart`, `test/features/user/data/app_user_mapper_test.dart`, `test/features/user/data/user_repository_impl_test.dart`

**Interfaces:**
- Produces:
  - `AppUser({ required String uid, required DateTime dob, bool ageVerified = false, DateTime? createdAt })` — pure freezed entity, no json.
  - `abstract class UserRepository { Stream<AppUser?> watch(String uid); Future<void> upsertAgeVerified({ required String uid, required DateTime dob }); }`
  - `AppUserDto` (freezed + json) with `toEntity()` / `AppUser.toDto()` extensions.
  - `UserRepositoryImpl implements UserRepository` (constructor `{ FirebaseFirestore? firestore }` defaulting to `db`).
  - `userRepositoryProvider = Provider<UserRepository>((ref) => UserRepositoryImpl())`.
- This task is ADDITIVE — it does not touch the old `core/firebase/users_repository.dart` or `features/auth/domain/app_user.dart` yet (both still compile). `currentUserDocProvider` is added in Task 4 (needs the new auth `authStateProvider`).

- [ ] **Step 1: Pure entity** — `lib/features/user/domain/entities/app_user.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required DateTime dob,
    @Default(false) bool ageVerified,
    DateTime? createdAt,
  }) = _AppUser;
}
```
(No `fromJson` — this is the domain entity, framework-free.)

- [ ] **Step 2: Abstract repository** — `lib/features/user/domain/repositories/user_repository.dart`:
```dart
import '../entities/app_user.dart';

abstract class UserRepository {
  Stream<AppUser?> watch(String uid);
  Future<void> upsertAgeVerified({required String uid, required DateTime dob});
}
```

- [ ] **Step 3: DTO** — `lib/features/user/data/dtos/app_user_dto.dart`: a freezed class with `uid` (String), `dob` (DateTime), `ageVerified` (bool), `createdAt` (DateTime?), plus `fromJson`/`toJson`. Move the JSON shape from the old `features/auth/domain/app_user.dart`. Run `fvm dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Mapper (failing test first)** — `test/features/user/data/app_user_mapper_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';
import 'package:not_eat_alone/features/user/data/mappers/app_user_mapper.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

void main() {
  test('dto <-> entity round-trip preserves fields', () {
    final entity = AppUserDto(uid: 'u1', dob: DateTime.utc(2000, 1, 1), ageVerified: true).toEntity();
    expect(entity.uid, 'u1');
    expect(entity.ageVerified, true);
    expect(entity.dob, DateTime.utc(2000, 1, 1));
    final back = entity.toDto();
    expect(back.uid, 'u1');
    expect(back.dob, DateTime.utc(2000, 1, 1));
  });
}
```
Run → FAIL (no mapper).

- [ ] **Step 5: Mapper impl** — `lib/features/user/data/mappers/app_user_mapper.dart`:
```dart
import '../../domain/entities/app_user.dart';
import '../dtos/app_user_dto.dart';

extension AppUserDtoX on AppUserDto {
  AppUser toEntity() => AppUser(
        uid: uid,
        dob: dob,
        ageVerified: ageVerified,
        createdAt: createdAt,
      );
}

extension AppUserX on AppUser {
  AppUserDto toDto() => AppUserDto(
        uid: uid,
        dob: dob,
        ageVerified: ageVerified,
        createdAt: createdAt,
      );
}
```
Run mapper test → PASS.

- [ ] **Step 6: Repository impl** — `lib/features/user/data/repositories/user_repository_impl.dart`: move the body of the old `core/firebase/users_repository.dart` here, renamed `UserRepositoryImpl implements UserRepository`. Keep: `withConverter` using `AppUserDto` (fromFirestore → `Timestamp.toDate().toUtc()` mapping, wrapped in `RepositoryParseException`); `watch` maps DTO → `dto.toEntity()`; `upsertAgeVerified` writes `{uid, dob: Timestamp, ageVerified: true, createdAt: serverTimestamp}` merge, wrapped in `RepositoryWriteException`. Constructor `{ FirebaseFirestore? firestore }` defaulting to `db`.

- [ ] **Step 7: Repo impl test** — `test/features/user/data/user_repository_impl_test.dart`: port the old `test/core/firebase/users_repository_test.dart` (inject `FakeFirebaseFirestore`; upsert then watch emits an `AppUser` entity with `ageVerified == true`, dob correct; missing uid → null; malformed doc → `RepositoryParseException`). Run → PASS.

- [ ] **Step 8: Provider** — `lib/features/user/application/user_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository_impl.dart';
import '../domain/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepositoryImpl());
```

- [ ] **Step 9: Entity test** — `test/features/user/domain/app_user_test.dart`: construct `AppUser`, assert fields + `copyWith`. (No json — that's the DTO's test via the mapper.)

- [ ] **Step 10: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos   # 0
fvm flutter test --concurrency=1       # all pass (old tests still green)
git add lib/features/user test/features/user
git commit -m "refactor(user): clean-architecture user feature (entity/dto/mapper/repo/provider)"
```

---

### Task 2: `auth` feature (domain + data + application)

**Files:**
- Create: `lib/features/auth/domain/entities/auth_user.dart`, `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/data/repositories/auth_repository_impl.dart`
- Modify: `lib/features/auth/application/auth_providers.dart` (replace with the new auth-only providers)
- Test: `test/features/auth/data/auth_repository_impl_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces:
  - `AuthUser({ required String uid })` — pure freezed entity.
  - `abstract class AuthRepository { Stream<AuthUser?> authStateChanges(); AuthUser? get currentUser; Future<void> signInWithGoogle(); Future<void> signInWithApple(); Future<void> verifyPhone({ required String phoneE164, required void Function(String verificationId) codeSent, required void Function(String message) onError }); Future<void> confirmSmsCode({ required String verificationId, required String smsCode }); Future<void> signOut(); }`
  - `AuthRepositoryImpl implements AuthRepository` (constructor injects `FirebaseAuth` + `GoogleSignIn` for tests; maps `firebase_auth.User` → `AuthUser`; sign-in methods return `void`, the stream is the source of truth; `verifyPhone` surfaces errors as `String` messages; auto-verify handled internally).
  - `authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl())`, `authStateProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges())`.
- ADDITIVE except it REPLACES the body of `auth_providers.dart`. The old `core/firebase/auth_repository.dart` still exists (deleted in Task 5). The old `auth_providers.dart` currently also holds `usersRepositoryProvider`/`currentUserDocProvider` — those move out (user's are in Task 1/4); so consumers of the OLD `currentUserDocProvider` (router, age_gate) will be rewired in Task 4. To keep green until then, temporarily KEEP re-exported shims is NOT needed because Task 2→4 run before any delete; but the router still imports the old symbols. **Ordering guard:** Task 2 changes `auth_providers.dart` to the new shape, which breaks the old router import of `currentUserDocProvider`/`User` — so Task 2 and Task 4 must land together to stay green, OR Task 2 keeps the old providers alongside the new ones. **Chosen approach:** in Task 2, ADD the new `AuthRepository`/`AuthUser`/new providers in NEW files and leave `auth_providers.dart` UNCHANGED; rename the new provider set to live in the new files. The router swap happens in Task 4. (So `auth_providers.dart` is only rewritten in Task 4.)

- [ ] **Step 1: Entity** — `lib/features/auth/domain/entities/auth_user.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({required String uid}) = _AuthUser;
}
```

- [ ] **Step 2: Abstract repository** — `lib/features/auth/domain/repositories/auth_repository.dart` with the interface from the Interfaces block above (imports only `auth_user.dart`; NO firebase imports).

- [ ] **Step 3: Impl** — `lib/features/auth/data/repositories/auth_repository_impl.dart`: move the body of `core/firebase/auth_repository.dart` here as `AuthRepositoryImpl implements AuthRepository`. Changes vs the old concrete class:
  - `authStateChanges()` maps `firebase_auth.User?` → `AuthUser?` (`u == null ? null : AuthUser(uid: u.uid)`).
  - `currentUser` returns the mapped `AuthUser?`.
  - `signInWithGoogle`/`signInWithApple`/`confirmSmsCode` return `Future<void>` (drop the `UserCredential` return).
  - `verifyPhone`: the `onError` callback receives `e.message ?? e.code` (a `String`), not the `FirebaseAuthException`; the internal `verificationCompleted` (auto-verify) calls `_firebaseAuth.signInWithCredential` itself instead of exposing a `PhoneAuthCredential`.
  - Keep the google_sign_in v7 + Apple-nonce logic unchanged.

- [ ] **Step 4: Impl test** — `test/features/auth/data/auth_repository_impl_test.dart`: port `test/core/firebase/auth_repository_test.dart` (mocktail mocks for `FirebaseAuth` + `GoogleSignIn`). Assert: `signOut()` calls both; `authStateChanges()` maps a mock `User(uid:'x')` stream to `AuthUser(uid:'x')` and `null` to `null`; `currentUser` maps. Run → PASS.

- [ ] **Step 5: New auth providers file** — create `lib/features/auth/application/auth_providers_v2.dart` (temporary name to avoid clashing with the old file until Task 4) containing:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/entities/auth_user.dart';
import '../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl());
final authStateProvider =
    StreamProvider<AuthUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());
```
(Task 4 renames this to `auth_providers.dart` after deleting the old one.)

- [ ] **Step 6: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos   # 0
fvm flutter test --concurrency=1       # all pass
git add lib/features/auth/domain lib/features/auth/data lib/features/auth/application/auth_providers_v2.dart test/features/auth/data
git commit -m "refactor(auth): clean-architecture auth feature (AuthUser/interface/impl/providers)"
```

---

### Task 3: `onboarding` feature (controller + screen)

**Files:**
- Create: `lib/features/onboarding/application/age_gate_controller.dart`, `lib/features/onboarding/presentation/age_gate_screen.dart`
- Test: `test/features/onboarding/application/age_gate_controller_test.dart`, `test/features/onboarding/presentation/age_gate_screen_test.dart`

**Interfaces:**
- Consumes: `userRepositoryProvider` (Task 1), `authRepositoryProvider` (Task 2, from `auth_providers_v2.dart`), `isAdult` (`core/util/age.dart`), analytics.
- Produces: `AgeGateController` (a Riverpod `Notifier` or `AsyncNotifier`) with `Future<void> submit(DateTime dob)` and an exposed state (`AsyncValue<void>` + a `bool blocked`); `ageGateControllerProvider`. `AgeGateScreen` renders picker + states and calls the controller.
- ADDITIVE — the screen is not routed until Task 4.

- [ ] **Step 1: Controller test (failing)** — `test/features/onboarding/application/age_gate_controller_test.dart`: with overridden `userRepositoryProvider` + `authRepositoryProvider` (mocktail):
  - `submit(DateTime.utc(2000,1,1))` (adult) → calls `userRepository.upsertAgeVerified(uid, dobUtc)`; does NOT call `signOut`.
  - `submit(DateTime.utc(2015,1,1))` (under-18) → calls `authRepository.signOut()`; does NOT call `upsertAgeVerified`; state exposes `blocked == true`.
  (uid comes from `authRepository.currentUser!.uid` — mock it to return `AuthUser(uid:'u1')`.)
  Run → FAIL.

- [ ] **Step 2: Controller impl** — `lib/features/onboarding/application/age_gate_controller.dart`: normalize `dob` to `DateTime.utc(dob.year, dob.month, dob.day)`; if `isAdult(dobUtc)` → `upsertAgeVerified` + fire `AgeGatePassed()`; else fire `AgeGateFailed()` + `signOut()` + set `blocked`. Surface loading/error via the notifier state. Run test → PASS.

- [ ] **Step 3: Screen** — move `lib/features/auth/presentation/age_gate_screen.dart` → `lib/features/onboarding/presentation/age_gate_screen.dart`, refactored to a thin `ConsumerWidget`/`ConsumerStatefulWidget` that shows the date picker and delegates to `ageGateControllerProvider`; render loading/error/blocked (tokens, no magic numbers). The under-18 message copy: "You must be 18 or older to use not-eat-alone."

- [ ] **Step 4: Screen widget test** — port/adapt `test/features/auth/presentation/age_gate_screen_test.dart` to the new location, driving the controller via a testable DOB hook (keep the `@visibleForTesting` injection). Both branches covered. Run → PASS.

- [ ] **Step 5: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos   # 0
fvm flutter test --concurrency=1       # all pass
git add lib/features/onboarding test/features/onboarding
git commit -m "refactor(onboarding): age-gate feature (controller + screen)"
```

---

### Task 4: Rewire router, entrypoints, screens → new providers

**Files:**
- Modify: `lib/core/routing/router.dart`, `lib/main_common.dart`, `lib/features/auth/presentation/signin_screen.dart`, `lib/features/auth/presentation/phone_verify_screen.dart`
- Create: `lib/features/user/application/user_providers.dart` gains `currentUserDocProvider`
- Rename: `lib/features/auth/application/auth_providers_v2.dart` → `auth_providers.dart` (replacing the old one)
- Test: update `test/core/routing/redirect_test.dart` only if signatures changed (they don't — `authRedirect` stays pure)

**Interfaces:**
- Consumes: `authStateProvider` (`AuthUser?`), `authRepositoryProvider`, `userRepositoryProvider`.
- Produces: `currentUserDocProvider = StreamProvider<AppUser?>` in `user_providers.dart` (watches `authStateProvider`'s `AuthUser?`; signed-out → `Stream.value(null)`; else `userRepository.watch(uid)`).

- [ ] **Step 1: Delete the old auth_providers, promote the new** — `git rm lib/features/auth/application/auth_providers.dart` then `git mv lib/features/auth/application/auth_providers_v2.dart lib/features/auth/application/auth_providers.dart`.

- [ ] **Step 2: currentUserDocProvider** — add to `lib/features/user/application/user_providers.dart`:
```dart
import '../../auth/application/auth_providers.dart';
import '../domain/entities/app_user.dart';
// ...
final currentUserDocProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(user.uid);
});
```

- [ ] **Step 3: Router** — update `lib/core/routing/router.dart` imports to the new `auth_providers.dart` (`authStateProvider` now `AuthUser?`) + `user_providers.dart` (`currentUserDocProvider`); route `/onboarding/age` → the new `onboarding` `AgeGateScreen`; `/auth/signin` + `/auth/phone` unchanged targets. `authRedirect` (pure) unchanged. `signedIn = authStateProvider.value != null` still holds (now `AuthUser?`).

- [ ] **Step 4: Screens** — update `signin_screen.dart` + `phone_verify_screen.dart` imports/usages to the new `auth_providers.dart` (`authRepositoryProvider` now returns the `AuthRepository` interface; sign-in methods return `void` — drop any use of the old `UserCredential` return). Remove their import of the OLD age_gate (router owns routing).

- [ ] **Step 5: Entrypoint** — `main_common.dart`: no provider change needed (it watches `routerProvider`), but confirm the `GoogleSignIn.instance.initialize()` bootstrap import still resolves. Analyze.

- [ ] **Step 6: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos   # 0
fvm flutter test --concurrency=1       # all pass
git add -A
git commit -m "refactor: rewire router/entrypoints/screens to clean-architecture providers"
```

---

### Task 5: Delete the old code + verify builds

**Files:**
- Delete: `lib/core/firebase/auth_repository.dart`, `lib/core/firebase/users_repository.dart`, `lib/features/auth/domain/app_user.dart`, `lib/features/auth/presentation/age_gate_screen.dart`, `lib/features/feedback/feedback_provider.dart` (+ the `feedback/` dir if now empty), and the OLD tests `test/core/firebase/auth_repository_test.dart`, `test/core/firebase/users_repository_test.dart`, `test/features/auth/domain/app_user_test.dart`, `test/features/auth/presentation/age_gate_screen_test.dart`, and `test/features/auth/application/auth_providers_test.dart` (its providers moved).

**Interfaces:** none produced; this removes the superseded code.

- [ ] **Step 1: Grep for stragglers** — confirm nothing imports the doomed files:
```bash
grep -rn "core/firebase/auth_repository\|core/firebase/users_repository\|features/auth/domain/app_user\|features/feedback/feedback_provider\|features/auth/presentation/age_gate_screen" lib test
```
Expected: no matches (Task 4 rewired them). If any remain, fix the importer first.

- [ ] **Step 2: Delete** the files listed above with `git rm`.

- [ ] **Step 3: Verify domain purity** — confirm no framework import leaked into domain:
```bash
grep -rn "cloud_firestore\|firebase_auth\|google_sign_in\|sign_in_with_apple" lib/features/*/domain lib/features/*/application/*.dart
```
Expected: NO hits in any `domain/` file. (`application/` may reference `firebase_auth` only if a `User` type leaked — it should not; `authStateProvider` is `AuthUser?`.) Fix any leak.

- [ ] **Step 4: Full verify**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos   # 0
fvm flutter test --concurrency=1       # all pass (count should match pre-refactor minus none — tests moved, not dropped)
fvm flutter build apk --debug --flavor stage -t lib/main_stage.dart
fvm flutter build apk --debug --flavor prod  -t lib/main_prod.dart
```
Both APKs build.

- [ ] **Step 5: Commit**
```bash
git add -A
git commit -m "refactor: remove superseded core/firebase repos and duplicate code"
```

---

### Task 6: Codify the convention (docs + slash commands)

**Files:**
- Modify: `CLAUDE.md`, `docs/MASTER-SPEC.md`, `.claude/commands/firestore.md`, `.claude/commands/provider.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: `CLAUDE.md`** — in "## Layout" and "## Conventions", replace the old lines:
  - `features/<name>/ data / domain (freezed) / application (Riverpod) / presentation` → the spec §3 folder shape.
  - "Firestore only via `lib/core/firebase/<collection>_repository.dart`. Never import cloud_firestore from feature code." → "Firestore/Auth SDK imports ONLY in a feature's `data/` layer. `domain/` has zero framework imports. Repositories are abstract interfaces in `domain/repositories/`, implemented in `data/repositories/`."
  - Add the §2 dependency rule (`presentation → application → domain ← data`).

- [ ] **Step 2: `docs/MASTER-SPEC.md`** — add a "Clean Architecture" section documenting the layer boundaries, entity/DTO/mapper (extension) pattern, and dependency rule as canonical. Reference the design spec `docs/superpowers/specs/2026-09-19-clean-architecture-design.md`.

- [ ] **Step 3: `/firestore` command** — update `.claude/commands/firestore.md` so it scaffolds, for a collection `X`: `features/X/domain/entities/x.dart` (pure), `features/X/domain/repositories/x_repository.dart` (abstract), `features/X/data/dtos/x_dto.dart` (freezed+json), `features/X/data/mappers/x_mapper.dart` (extensions), `features/X/data/repositories/x_repository_impl.dart` (withConverter + typed exceptions), `features/X/application/x_providers.dart` (`xRepositoryProvider`) — NOT a `core/firebase` wrapper.

- [ ] **Step 4: `/provider` command** — update `.claude/commands/provider.md` so it scaffolds an application-layer Riverpod notifier over a domain repository interface (consuming `xRepositoryProvider`), per the new layering.

- [ ] **Step 5: Sanity + commit**
```bash
! grep -rn "core/firebase/<collection>_repository\|features/<name>/ data / domain" CLAUDE.md docs/MASTER-SPEC.md && echo "old-pattern references gone"
git add CLAUDE.md docs/MASTER-SPEC.md .claude/commands/firestore.md .claude/commands/provider.md
git commit -m "docs: codify clean architecture in constitution and scaffolding commands"
```

---

## Self-review notes

- **Spec coverage:** dependency rule (§2 → Global Constraints + Task 5 Step 3 verify); folder shape (§3 → Tasks 1-3); core infra kept (§4 → untouched); `auth` feature (§5 → Task 2); `user` feature (§6 → Task 1); `onboarding` (§7 → Task 3); routing composition root (§8 → Task 4); feedback cleanup (§9 → Task 5); codify (§10 → Task 6); testing/behavior-unchanged (§11 → per-task verify + Task 5 build); non-goals (§12 → respected, no feature/dep/rule changes). ✔
- **Ordering:** additive Tasks 1-3 (new files, old code still compiles) → Task 4 rewires consumers in one green step (the only moment old→new swap happens, incl. deleting/renaming `auth_providers.dart`) → Task 5 deletes the now-unreferenced old files → Task 6 docs. The `auth_providers_v2.dart` temp name avoids a symbol clash between Tasks 2 and 4.
- **Type consistency:** `AppUser` (pure entity, Task 1) vs `AppUserDto` (json, Task 1) — mapper bridges; `AuthUser{uid}` (Task 2) is what `authStateProvider`/router/`currentUserDocProvider` consume (Tasks 2/4); `UserRepository`/`AuthRepository` interfaces bound to `*Impl` in providers. `authRedirect` stays pure/unchanged.
- **Placeholder scan:** the mapper test (Task 1 Step 4) has an intentional pseudocode comment line showing the wrong-then-right form — the implementer uses the `DateTime.utc(2000,1,1)` version; flagged inline. No other placeholders.
