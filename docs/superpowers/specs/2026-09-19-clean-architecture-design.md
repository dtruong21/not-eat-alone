# not-eat-alone — Clean Architecture Design

**Date:** 2026-09-19
**Status:** Approved (design), pending implementation plan
**Scope:** Refactor existing code (auth + user) into Pragmatic Clean Architecture and codify the pattern for all future features. No behavior change; all tests stay green.

---

## 1. Goal & flavor

Adopt **Pragmatic Clean Architecture**: real layer boundaries and dependency inversion via abstract repository interfaces, without a per-operation use-case class explosion. Riverpod notifiers are the application layer. This fits the project's MVP-first / Riverpod stack while giving testable, framework-independent domain code.

## 2. The dependency rule (non-negotiable)

Dependencies point **inward**:

```
presentation → application → domain ← data
```

- **`domain`** has **zero** Flutter/Firebase/IO imports — pure Dart entities + abstract repository interfaces only.
- **`data`** is the ONLY layer allowed to import `cloud_firestore`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`. It implements the domain interfaces.
- **`application`** (Riverpod) depends on domain interfaces (and binds concrete impls via providers). It never imports `data` types except at the single provider wiring point.
- **`presentation`** depends on application + domain. Never imports Firestore/Auth SDKs.

This **replaces** the old CLAUDE.md rule ("Firestore only via `lib/core/firebase/<collection>_repository.dart`"). Repositories move out of `core/firebase/` into each feature's `data/` layer.

## 3. Per-feature folder shape

```
lib/features/<feature>/
  domain/
    entities/          pure freezed entities, NO json
    repositories/      abstract interfaces (e.g. abstract class UserRepository)
  data/
    dtos/              freezed + json + Firestore/Timestamp mapping
    mappers/           extension methods: AppUserDto.toEntity(), AppUser.toDto()
    repositories/      <name>_repository_impl.dart (implements domain interface)
    datasources/       (optional; only when a remote/local source is worth isolating)
  application/         Riverpod notifiers + providers (state + impl→interface binding)
  presentation/        screens + widgets
```

`test/` mirrors `lib/` — a unit's tests move with the unit.

## 4. Core (infrastructure) — what stays in `lib/core/`

Only cross-cutting infra with no feature ownership:
- `core/firebase/firebase_client.dart` (the flavor-aware `db` / `auth` handles), `core/firebase/repository_exception.dart` (typed exceptions reused by all data-layer repos), `core/firebase/options/*`.
- `core/design/`, `core/analytics/`, `core/config/`, `core/util/` (pure helpers like `age.dart`), `core/routing/` (the **composition root** — the router wires feature application providers; it may depend on features).

`core/firebase/auth_repository.dart` and `core/firebase/users_repository.dart` are **removed** from core (moved into feature data layers).

## 5. Feature: `auth`

- **domain/entities/auth_user.dart** — `AuthUser({ String uid })` (pure). Keeps `firebase_auth.User` from leaking past data.
- **domain/repositories/auth_repository.dart** — abstract:
  - `Stream<AuthUser?> authStateChanges()`
  - `AuthUser? get currentUser`
  - `Future<void> signInWithGoogle()` / `signInWithApple()` (return void — the stream is the source of truth)
  - `Future<void> verifyPhone({ required String phoneE164, required void Function(String verificationId) codeSent, required void Function(String message) onError })` (errors surfaced as domain strings, not `FirebaseAuthException`; auto-verify handled internally in the impl)
  - `Future<void> confirmSmsCode({ required String verificationId, required String smsCode })`
  - `Future<void> signOut()`
- **data/repositories/auth_repository_impl.dart** — implements the above with FirebaseAuth + google_sign_in v7 + sign_in_with_apple (nonce), mapping `firebase_auth.User` → `AuthUser`.
- **application/auth_providers.dart** — `authRepositoryProvider` (binds impl), `authStateProvider` (`StreamProvider<AuthUser?>`).
- **presentation/** — `signin_screen.dart`, `phone_verify_screen.dart` (unchanged behavior; now depend on `AuthUser`/interface, not firebase types).

## 6. Feature: `user`

- **domain/entities/app_user.dart** — `AppUser({ String uid, DateTime dob, bool ageVerified, DateTime? createdAt })` (pure freezed, no json).
- **domain/repositories/user_repository.dart** — abstract: `Stream<AppUser?> watch(String uid)`, `Future<void> upsertAgeVerified({ required String uid, required DateTime dob })`.
- **data/dtos/app_user_dto.dart** — freezed + json; carries the `Timestamp`↔`DateTime` (UTC-normalized) handling currently in `users_repository`.
- **data/mappers/app_user_mapper.dart** — `extension` methods `AppUserDto.toEntity()` / `AppUser.toDto()`.
- **data/repositories/user_repository_impl.dart** — `withConverter` over `db.collection('users')` using the DTO; typed `RepositoryParseException` / `RepositoryWriteException`; flavor-aware `db`.
- **application/user_providers.dart** — `userRepositoryProvider` (binds impl), `currentUserDocProvider` (`StreamProvider<AppUser?>` watching the signed-in uid via `authStateProvider`).

## 7. Feature: `onboarding`

- **application/age_gate_controller.dart** — a Riverpod notifier owning the orchestration currently inside the widget: `submit(DateTime dob)` → normalize to UTC-midnight → `isAdult(dob)` ? (`userRepository.upsertAgeVerified` + fire `age_gate_passed`) : (fire `age_gate_failed` + `authRepository.signOut`). Exposes an `AsyncValue`-style state for the screen. Depends on `user` + `auth` domain via their providers.
- **presentation/age_gate_screen.dart** — moved here; renders the picker + loading/error/blocked states, delegates to the controller. `isAdult` stays in `core/util/age.dart` (pure helper).

## 8. Routing (composition root)

`core/routing/router.dart` keeps the pure `authRedirect` + wires the `redirect` from `authStateProvider` (now `AuthUser?`) and `currentUserDocProvider`. Routes point at the relocated screens. This is the app's composition root, so it legitimately depends on feature application providers.

## 9. Cleanup

- Delete `lib/features/feedback/feedback_provider.dart` (unused template leftover) and its stray import references. If any doc references it, update.

## 10. Codify the convention

- **`CLAUDE.md`** — replace the "Firestore only via `lib/core/firebase/<collection>_repository.dart`" rule + the `features/<name>/ data / domain / application / presentation` line with the §2 dependency rule and §3 folder shape; add "domain has zero framework imports" and "cloud_firestore/firebase_auth only in `data/`".
- **`docs/MASTER-SPEC.md`** — document the layer boundaries, the entity/DTO/mapper pattern, and the dependency rule as the canonical structure.
- **Slash commands** — update `/firestore` (`.claude/commands/firestore.md`) to scaffold a domain interface + DTO + mapper + data impl + provider (not a `core/firebase` wrapper); update `/provider` (`.claude/commands/provider.md`) to scaffold an application-layer notifier over a domain interface. So future scaffolding produces Clean-layered code and features don't drift back.

## 11. Testing & verification

- Behavior is unchanged. Every existing test moves to mirror its unit's new path and keeps passing (30/30).
- New seams get light coverage where they add logic: the `age_gate_controller` notifier (adult → upsert + passed; under-18 → signOut + failed), and the DTO↔entity mapper round-trip.
- Gate per task: `fvm flutter analyze --no-fatal-infos` = 0, `fvm flutter test --concurrency=1` all pass, both flavors still build.

## 12. Non-goals

- No new product features; no use-case/interactor classes (notifiers are the application layer); no change to Firestore data shape, rules, or the single-project/split-Firestore setup; no dependency changes.

## 13. Delivery

Own plan on branch `refactor-clean-arch` (stacked on `plan-2-auth`), executed subagent-driven. Migration ordered to keep the tree compiling+green between tasks: introduce `core` unchanged → build `user` layers → build `auth` layers → build `onboarding` → rewire router + entrypoints → delete old `core/firebase` repos + feedback leftover → update docs/commands.
