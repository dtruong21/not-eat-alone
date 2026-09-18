# not-eat-alone — Plan 2: Auth & 18+ Onboarding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A user can sign in with phone, Apple, or Google, is gated to 18+ via a date-of-birth step, and lands on an authed home; their identity + age verdict persist in a `users/{uid}` Firestore doc (in the correct per-flavor database), and sign-out returns them to sign-in.

**Architecture:** `firebase_auth` wrapped in `auth_repository.dart` (never called from widgets directly); `google_sign_in` + `sign_in_with_apple` for the OAuth methods; phone via `verifyPhoneNumber` + SMS code. A freezed `AppUser` persisted through `users_repository.dart` using the flavor-aware `db` getter (so stage writes hit the `stage` database). `go_router`'s `redirect` drives the three routing states (signed-out → sign-in; signed-in but not age-verified → age gate; verified → home). Analytics events are declared in the typed registry before use.

**Tech Stack:** Flutter 3.47.4 (FVM), firebase_auth, cloud_firestore, google_sign_in, sign_in_with_apple, flutter_riverpod, go_router, freezed, mocktail.

**Base branch:** `plan-1-foundation` (this branch, `plan-2-auth`, is stacked on it — `main` does not yet contain the foundation).

## Global Constraints

- Flutter 3.47.4 via FVM — all commands use `fvm flutter` / `fvm dart`. (from Plan 1)
- Firestore access ONLY through `lib/core/firebase/*_repository.dart`; feature code never imports `cloud_firestore`. (CLAUDE.md)
- The flavor-aware `db` getter (`FirebaseFirestore.instanceFor(app:, databaseId: FlavorConfig.current.firestoreDatabaseId)`) is the single Firestore entrypoint; prod → `(default)`, stage → `stage`.
- Single Firebase project (`not-eat-alone`), two app registrations; prod bundle `com.daki.noteatalone`, stage `com.daki.noteatalone.stage`.
- **18+ only** — under-18 is hard-blocked (message + forced sign-out), never allowed into the app.
- Every analytics event is declared in `lib/core/analytics/events.dart` + mirrored in `docs/TRACKING-PLAN.md` BEFORE it is fired; no PII in props (reference `user_id` only). (CLAUDE.md analytics-first)
- Every `AsyncValue` consumer renders `loading` / `error` / `data`. (CLAUDE.md UX rule)
- freezed + json_serializable at the Firestore boundary; server-set fields (`createdAt`) are nullable. (CLAUDE.md)
- Riverpod: `ref.watch` only in `build()`; `ref.read` inside notifier methods.
- Commit messages end with a blank line then `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: Provider console setup + native auth config (USER-GATED)

**Files:**
- Create: `ios/Runner/Runner.entitlements` (Sign in with Apple), per-flavor URL schemes in `ios/Runner/Info.plist`
- Modify: `android/app/build.gradle.kts` (Play Integrity dep if needed), Firebase console (out-of-repo)

**Interfaces:**
- Produces: Auth providers enabled in the `not-eat-alone` project; `REVERSED_CLIENT_ID` URL scheme wired for Google on iOS; Sign in with Apple entitlement present.

- [ ] **Step 1: (USER) Enable providers in Firebase console**

In the `not-eat-alone` project → Authentication → Sign-in method, enable: **Phone**, **Apple**, **Google**. For Apple, configure the Services ID + key per Firebase's Apple setup. Confirm from CLI:
```bash
firebase auth:export /tmp/na_check.json --project not-eat-alone >/dev/null 2>&1 && echo "auth reachable"
```
(Provider enablement isn't fully CLI-inspectable; the real verification is a successful sign-in in Task 10.)

- [ ] **Step 2: (USER) iOS APNs + Android SHA/Play Integrity**

- iOS: upload an **APNs auth key** (Apple Developer account) to the Firebase iOS app (required for phone-auth silent push). 
- Android: add the **debug + release SHA-256** fingerprints to BOTH Android app registrations (prod + stage) in the console, then re-download each `google-services.json` and replace `android/app/src/{prod,stage}/google-services.json`. Get debug SHA:
```bash
cd android && ./gradlew signingReport --console=plain 2>/dev/null | grep -A1 "Variant: debug" | grep SHA-256; cd ..
```
- Enable **Play Integrity** for phone auth in the console.

- [ ] **Step 3: Sign in with Apple capability**

Create `ios/Runner/Runner.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```
Reference it from all Runner build configs (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`) — extend `ios/scripts/setup_flavors.rb` or add a small ruby script using the `xcodeproj` gem, then run it and commit the script.

- [ ] **Step 4: Google URL scheme (iOS)**

For EACH flavor plist (`ios/config/prod/GoogleService-Info.plist`, `ios/config/stage/GoogleService-Info.plist`), read its `REVERSED_CLIENT_ID` and add a matching `CFBundleURLTypes` entry in `ios/Runner/Info.plist`. Since the two flavors have different reversed client ids, register BOTH URL schemes in Info.plist (iOS accepts extra schemes harmlessly), or add them via the flavor-specific config. Document which scheme belongs to which flavor in the report.

- [ ] **Step 5: Verify build still green**

```bash
fvm flutter build apk --debug --flavor prod -t lib/main_prod.dart 2>&1 | tail -3
```
Expected: build succeeds (native config changes don't break compilation).

- [ ] **Step 6: Commit**

```bash
git add ios/ android/ .fvm/ 2>/dev/null; git add ios android
git commit -m "chore(auth): enable providers, wire Apple entitlement + Google URL schemes"
```

---

### Task 2: Auth + sign-in packages

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `google_sign_in`, `sign_in_with_apple` available; `firebase_auth` already present.

- [ ] **Step 1: Add packages**

```bash
fvm flutter pub add google_sign_in sign_in_with_apple
fvm flutter pub get
```

- [ ] **Step 2: Analyze**

```bash
fvm flutter analyze --no-fatal-infos
```
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(auth): add google_sign_in and sign_in_with_apple"
```

---

### Task 3: `AppUser` model + age helper

**Files:**
- Create: `lib/features/auth/domain/app_user.dart`, `lib/core/util/age.dart`
- Test: `test/features/auth/domain/app_user_test.dart`, `test/core/util/age_test.dart`

**Interfaces:**
- Produces: `AppUser` freezed class `{ String uid; DateTime dob; bool ageVerified; DateTime? createdAt; }` with `fromJson`/`toJson`; `bool isAdult(DateTime dob, {DateTime? now})` (true iff ≥18 years old).

- [ ] **Step 1: Failing test for age helper** — `test/core/util/age_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/age.dart';

void main() {
  final now = DateTime(2026, 9, 18);
  test('exactly 18 today is adult', () {
    expect(isAdult(DateTime(2008, 9, 18), now: now), true);
  });
  test('one day short of 18 is not adult', () {
    expect(isAdult(DateTime(2008, 9, 19), now: now), false);
  });
  test('well over 18 is adult', () {
    expect(isAdult(DateTime(1990, 1, 1), now: now), true);
  });
}
```

- [ ] **Step 2: Run, verify fail** — `fvm flutter test test/core/util/age_test.dart` → FAIL (no `age.dart`).

- [ ] **Step 3: Implement** `lib/core/util/age.dart`:
```dart
/// True iff someone born on [dob] is at least 18 years old at [now]
/// (defaults to DateTime.now()).
bool isAdult(DateTime dob, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dob.year;
  final hadBirthday = (today.month > dob.month) ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age >= 18;
}
```

- [ ] **Step 4: Run, verify pass** — `fvm flutter test test/core/util/age_test.dart` → PASS.

- [ ] **Step 5: Implement `AppUser`** `lib/features/auth/domain/app_user.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required DateTime dob,
    @Default(false) bool ageVerified,
    DateTime? createdAt, // server-set; nullable on optimistic snapshots
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, Object?> json) => _$AppUserFromJson(json);
}
```

- [ ] **Step 6: Codegen + model test** — run `fvm dart run build_runner build --delete-conflicting-outputs`. Add `test/features/auth/domain/app_user_test.dart` round-tripping `AppUser.fromJson(user.toJson())` and asserting field equality (use a fixed `dob`, `createdAt: null`).

- [ ] **Step 7: Run tests + commit**
```bash
fvm flutter test test/core/util/age_test.dart test/features/auth/domain/app_user_test.dart
git add lib/core/util/age.dart lib/features/auth/domain/app_user.dart test/core/util/age_test.dart test/features/auth/domain/app_user_test.dart lib/features/auth/domain/app_user.*.dart
git commit -m "feat(auth): add AppUser model and isAdult age helper"
```

---

### Task 4: Firestore rules for `users/{uid}` + both databases

**Files:**
- Modify: `firebase.json` (array form, per-database), `firebase/firestore.rules`
- Create: `firebase/firestore.indexes.json` entries if needed (none for this task)

**Interfaces:**
- Produces: `users/{uid}` readable/writable only by its owner; rules deployed to `(default)` and `stage`.

- [ ] **Step 1: Convert `firebase.json` firestore to per-database array**
```json
"firestore": [
  { "database": "(default)", "rules": "firebase/firestore.rules", "indexes": "firebase/firestore.indexes.json" },
  { "database": "stage",     "rules": "firebase/firestore.rules", "indexes": "firebase/firestore.indexes.json" }
]
```

- [ ] **Step 2: Write `users` rules** in `firebase/firestore.rules` (inside `service cloud.firestore { match /databases/{database}/documents { ... } }`):
```
match /users/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow create: if request.auth != null && request.auth.uid == uid
                && request.resource.data.uid == uid
                && request.resource.data.dob is timestamp
                && request.resource.data.ageVerified is bool;
  allow update: if request.auth != null && request.auth.uid == uid;
  allow delete: if false; // account deletion handled via Cloud Function later
}
```

- [ ] **Step 3: Deploy to both databases**
```bash
firebase deploy --only firestore --project not-eat-alone
```
Expected: deploy reports rules compiled + released to `(default)` and `stage`. (If the CLI needs the databases targeted individually, run `firebase deploy --only "firestore:(default)"` and `firebase deploy --only "firestore:stage"`.)

- [ ] **Step 4: Commit**
```bash
git add firebase.json firebase/firestore.rules
git commit -m "feat(firestore): users rules deployed to default + stage databases"
```

---

### Task 5: `users_repository.dart`

**Files:**
- Create: `lib/core/firebase/users_repository.dart`
- Test: `test/core/firebase/users_repository_test.dart`

**Interfaces:**
- Consumes: `db` (flavor-aware) from `firebase_client.dart`; `AppUser` (Task 3).
- Produces: `class UsersRepository { Stream<AppUser?> watch(String uid); Future<void> upsertAgeVerified({required String uid, required DateTime dob}); }` — `upsertAgeVerified` writes `{uid, dob, ageVerified: true, createdAt: serverTimestamp}` with merge.

- [ ] **Step 1: Implement** `lib/core/firebase/users_repository.dart` using a typed `.withConverter` collection reference over `db.collection('users')`, mapping via `AppUser.fromJson` / `toJson`, with `createdAt` written as `FieldValue.serverTimestamp()`. (Feature code must not import cloud_firestore — this repo is the boundary.)

- [ ] **Step 2: Test** `test/core/firebase/users_repository_test.dart` — add `fake_cloud_firestore` as a dev dep (`fvm flutter pub add --dev fake_cloud_firestore`) and inject a fake instance (add an optional `FirebaseFirestore` constructor arg defaulting to `db` so tests pass a fake). Test: `upsertAgeVerified` then `watch(uid)` emits an `AppUser` with `ageVerified == true` and the right `dob`.

- [ ] **Step 3: Run + commit**
```bash
fvm flutter test test/core/firebase/users_repository_test.dart
git add lib/core/firebase/users_repository.dart test/core/firebase/users_repository_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(auth): users repository with age-verified upsert"
```

---

### Task 6: `auth_repository.dart`

**Files:**
- Create: `lib/core/firebase/auth_repository.dart`
- Test: `test/core/firebase/auth_repository_test.dart`

**Interfaces:**
- Produces: `class AuthRepository` with:
  - `Stream<User?> authStateChanges()`
  - `User? get currentUser`
  - `Future<UserCredential> signInWithGoogle()`
  - `Future<UserCredential> signInWithApple()`
  - `Future<void> verifyPhone({required String phoneE164, required void Function(String verificationId) codeSent, required void Function(FirebaseAuthException) onError, void Function(PhoneAuthCredential)? onAutoVerified})`
  - `Future<UserCredential> confirmSmsCode({required String verificationId, required String smsCode})`
  - `Future<void> signOut()`
- Constructor takes `FirebaseAuth`, `GoogleSignIn` (injectable for tests).

- [ ] **Step 1: Implement** the repository wrapping `FirebaseAuth`, `google_sign_in`, `sign_in_with_apple` (use `SignInWithApple.getAppleIDCredential` → `OAuthProvider('apple.com').credential(...)`). `signOut` signs out of FirebaseAuth AND GoogleSignIn.

- [ ] **Step 2: Test** `test/core/firebase/auth_repository_test.dart` with mocktail — mock `FirebaseAuth` + `GoogleSignIn`; verify `signOut()` calls both `firebaseAuth.signOut()` and `googleSignIn.signOut()`, and `authStateChanges()` forwards the FirebaseAuth stream. (OAuth round-trips are covered by manual/integration testing in Task 10; unit-test the wiring you can.)

- [ ] **Step 3: Run + commit**
```bash
fvm flutter test test/core/firebase/auth_repository_test.dart
git add lib/core/firebase/auth_repository.dart test/core/firebase/auth_repository_test.dart
git commit -m "feat(auth): auth repository (phone, Apple, Google, sign-out)"
```

---

### Task 7: Riverpod providers + analytics events

**Files:**
- Create: `lib/features/auth/application/auth_providers.dart`
- Modify: `lib/core/analytics/events.dart`, `docs/TRACKING-PLAN.md`
- Test: `test/features/auth/application/auth_providers_test.dart`

**Interfaces:**
- Produces: `authRepositoryProvider`, `usersRepositoryProvider`, `authStateProvider` (`StreamProvider<User?>`), `currentUserDocProvider` (`StreamProvider<AppUser?>` watching `users/{uid}` for the signed-in uid, or `Stream.value(null)` when signed out).
- Produces (analytics): add `phone` to `SigninMethod` + `SignupMethod`; new events `SigninStarted({SigninMethod method})` (`signin_started`), `AgeGatePassed()` (`age_gate_passed`), `AgeGateFailed()` (`age_gate_failed`).

- [ ] **Step 1: Extend analytics registry** — add `phone` to the `SigninMethod`/`SignupMethod` enums and the three new `AppEvent` subclasses in `lib/core/analytics/events.dart`; mirror them in `docs/TRACKING-PLAN.md` (name, when-fired, props). No PII.

- [ ] **Step 2: Providers** — implement the four providers in `auth_providers.dart`. `currentUserDocProvider` watches `authStateProvider`; when a user is present, returns `ref.watch(usersRepositoryProvider).watch(user.uid)`, else `Stream.value(null)`.

- [ ] **Step 3: Test** — `test/features/auth/application/auth_providers_test.dart`: with a `ProviderContainer` overriding `authRepositoryProvider`/`usersRepositoryProvider` with fakes, assert `currentUserDocProvider` emits `null` when signed out and the `AppUser` when signed in.

- [ ] **Step 4: Run + commit**
```bash
fvm flutter test test/features/auth/application/auth_providers_test.dart
git add lib/features/auth/application/auth_providers.dart lib/core/analytics/events.dart docs/TRACKING-PLAN.md test/features/auth/application/auth_providers_test.dart
git commit -m "feat(auth): auth/session providers and analytics events"
```

---

### Task 8: Routing redirect (three states)

**Files:**
- Modify: `lib/core/routing/router.dart`
- Test: `test/core/routing/redirect_test.dart`

**Interfaces:**
- Consumes: `authStateProvider`, `currentUserDocProvider`.
- Produces: a pure `String? authRedirect({required bool signedIn, required bool ageVerified, required String location})` that the router's `redirect` delegates to, plus routes `/auth/signin`, `/onboarding/age`, `/`.

- [ ] **Step 1: Failing test** `test/core/routing/redirect_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/routing/router.dart';

void main() {
  test('signed out anywhere -> signin', () {
    expect(authRedirect(signedIn: false, ageVerified: false, location: '/'), '/auth/signin');
  });
  test('signed in, not verified -> age gate', () {
    expect(authRedirect(signedIn: true, ageVerified: false, location: '/'), '/onboarding/age');
  });
  test('signed in + verified on signin -> home', () {
    expect(authRedirect(signedIn: true, ageVerified: true, location: '/auth/signin'), '/');
  });
  test('signed in + verified on home -> stay', () {
    expect(authRedirect(signedIn: true, ageVerified: true, location: '/'), null);
  });
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** `authRedirect` (pure, exported from router.dart) and wire the `routerProvider`'s `redirect:` to compute `signedIn`/`ageVerified` from `ref.watch(authStateProvider)` + `ref.watch(currentUserDocProvider)` and delegate. Add the three routes (screens land in Tasks 9-10; use temporary `Scaffold` placeholders that the next tasks replace, OR order Task 9/10 before wiring builders). Keep the redirect resilient while `currentUserDocProvider` is loading (treat loading as "not verified yet" but don't bounce off the age screen).

- [ ] **Step 4: Run test + analyze + commit.**

---

### Task 9: Age-gate screen (`/onboarding/age`)

**Files:**
- Create: `lib/features/auth/presentation/age_gate_screen.dart`
- Test: `test/features/auth/presentation/age_gate_screen_test.dart`

**Interfaces:**
- Consumes: `isAdult` (Task 3), `usersRepositoryProvider`, analytics.
- Behavior: date picker for DOB → on submit, if `isAdult(dob)`: call `usersRepository.upsertAgeVerified(uid, dob)` (fires `age_gate_passed`), router redirects to `/`. If not adult: show a blocking message, fire `age_gate_failed`, and `authRepository.signOut()`.

- [ ] **Step 1: Widget test** — pump the screen with overridden providers; enter a DOB < 18 → expect the block message + `signOut` called; enter a DOB ≥ 18 → expect `upsertAgeVerified` called with that dob. Assert loading + error states render.

- [ ] **Step 2: Implement** the screen (tokens for all styling; `AsyncValue` states rendered). Under-18 copy: clear, non-judgmental ("You must be 18 or older to use not-eat-alone.").

- [ ] **Step 3: Run test + commit.**

---

### Task 10: Sign-in screen (`/auth/signin`) + sign-out

**Files:**
- Create: `lib/features/auth/presentation/signin_screen.dart`, `lib/features/auth/presentation/phone_verify_screen.dart`
- Modify: `lib/features/home/placeholder_home.dart` (add a temporary Sign out button to exercise the loop)
- Test: `test/features/auth/presentation/signin_screen_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`, analytics.
- Behavior: Google button → `signInWithGoogle`; Apple button → `signInWithApple`; phone → enter number (France `+33` default) → `verifyPhone` → OTP screen → `confirmSmsCode`. Each fires `signin_started` then (on success, via auth-state change) the router advances. All buttons render loading/disabled during the call and surface errors.

- [ ] **Step 1: Widget test** — tap Google → `authRepository.signInWithGoogle` called + `signin_started(method: google)` fired; error from the repo renders an error message (not a crash). (Phone OTP flow: test that entering a number calls `verifyPhone`.)

- [ ] **Step 2: Implement** both screens with tokens + full `AsyncValue`/error states. Add a temporary "Sign out" action to `PlaceholderHome` calling `authRepository.signOut()` so the whole loop is manually testable.

- [ ] **Step 3: Run test + analyze + commit.**

---

### Task 11: Integration verification + finalize

**Files:**
- Create: `integration_test/auth_flow_test.dart` (best-effort), 
- Modify: `docs/TEST-PLAN.md` (auth cases)

- [ ] **Step 1: Full suite** — `fvm flutter test` (all unit + widget pass) and `fvm flutter analyze --no-fatal-infos` (exit 0).

- [ ] **Step 2: Build both flavors** — `fvm flutter build apk --debug --flavor prod -t lib/main_prod.dart` and `--flavor stage -t lib/main_stage.dart`; both succeed.

- [ ] **Step 3: Manual auth smoke (coordinator/user, on a device/simulator)** — sign in with **Google** end-to-end (signed-out → sign-in → age gate → home → sign out). Phone requires the APNs/SHA setup from Task 1 + a real SMS; Apple requires a device — record which methods were exercised. Document results in `docs/TEST-PLAN.md`.

- [ ] **Step 4: Commit + push + PR**
```bash
git push -u origin plan-2-auth
gh pr create --base plan-1-foundation --head plan-2-auth --title "Plan 2: auth & 18+ onboarding" --body "<summary>"
```
(Base the PR on `plan-1-foundation` since Plan 2 is stacked; retarget to `main` after Plan 1 merges. End the PR body with a blank line then `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.)

---

## Self-review notes

- **Spec coverage:** auth methods (spec §5: phone/Apple/Google + SiA on iOS → Tasks 1,2,6,10); 18+ gate (§5 → Tasks 3,9); `users` doc (§7 → Tasks 3,5); Firestore rules incl. stage DB (§6 follow-up → Task 4); analytics-first (Task 7); auth routing (Task 8). Safety features beyond age (block/report, women-only) belong to later plans, not here.
- **Order dependency:** Task 8 wires routes whose screens are built in Tasks 9-10 — the implementer uses placeholder builders in Task 8 and swaps real screens in 9-10 (noted in Task 8 Step 3).
- **User-gated:** Task 1 (console provider enablement, APNs key, Android SHA, Play Integrity) needs the user's Apple Developer + Firebase console access — execution pauses there.
- **Deferred:** account deletion (rules `allow delete: if false` for now; Cloud Function in a later plan); profile fields beyond dob (Plan 3); phone-auth production hardening (reCAPTCHA/App Check tuning) revisited in Plan 11.
