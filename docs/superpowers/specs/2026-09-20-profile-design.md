# Convyve — Profile Design (Plan 3)

**Date:** 2026-09-20
**Status:** Approved (design), pending implementation plan
**Feature:** User profile — setup (forced onboarding step) + edit — built on the clean `user` feature.

---

## 1. Goal

After the 18+ age gate, a user must complete a profile (display name, at least one photo, gender) before reaching home/discovery. Profiles are editable later. Photos live in Firebase Storage; profile fields live on the `users/{uid}` Firestore doc.

## 2. Fields (v1)

| Field | Required | Notes |
|---|---|---|
| `displayName` | ✅ | not captured before; free text, trimmed, 1–40 chars |
| `photoUrls` | ✅ ≥1 | 1 required, up to **6 total** (1 + 5); Firebase Storage URLs |
| `gender` | ✅ | `Gender` enum: `woman` / `man` / `nonBinary` (needed for women-only meals) |
| `bio` | optional | ≤ 300 chars |
| age (from `dob`) | — | `dob` already stored at the age gate; profile shows **derived age**, DOB is **read-only** (no editing — prevents gaming the 18+ gate) |

`profileComplete` is a **derived** getter on the entity — `displayName` non-empty && `photoUrls` non-empty && `gender != null`. No stored `profileComplete` bool (avoids drift).

## 3. Data model (extend the clean `user` feature)

- `user/domain/entities/gender.dart` — `enum Gender { woman, man, nonBinary }`.
- `user/domain/entities/app_user.dart` — add `displayName` (String?), `photoUrls` (List<String> default []), `bio` (String?), `gender` (Gender?); add `bool get profileComplete`. Pure entity, no json.
- `user/data/dtos/app_user_dto.dart` — add the four fields with json; `gender` serialized as its `.name` string. Extension mappers updated both directions.
- `user/domain/repositories/user_repository.dart` — add `Future<void> updateProfile({ required String uid, String? displayName, List<String>? photoUrls, String? bio, Gender? gender })` (partial update, merge). Keep existing `watch` / `upsertAgeVerified`.
- `user/data/repositories/user_repository_impl.dart` — implement `updateProfile` (merge write via the DTO's `toFirestore`, typed `RepositoryWriteException`).

## 4. Photos → Firebase Storage (shared bucket — env-prefixed)

Storage is a **single bucket shared by stage and prod** (only Firestore is split). So paths are env-prefixed to avoid collisions:

- New `FlavorConfig.storagePathPrefix` → `'stage'` for stage, `'prod'` for prod (mirrors `firestoreDatabaseId`).
- Photo object path: `{storagePathPrefix}/users/{uid}/photo_{index}_{timestamp}.jpg`.
- `user/data/datasources/photo_storage_datasource.dart` — wraps `firebase_storage`: `Future<String> upload(uid, index, File)` (returns download URL), `Future<void> delete(url)`. Client-side compress/resize before upload (target ~1080px, JPEG) via `flutter_image_compress` (or `image`).
- Pick images with `image_picker` (gallery + camera) in the presentation layer; the datasource only handles Storage I/O.
- `user/data/repositories/user_repository_impl.dart` (or a dedicated `PhotoRepository`) coordinates: upload via datasource → store returned URL on the `users` doc via `updateProfile`.

**`firebase/storage.rules`** (new file):
- write: only the owner, only under `{prefix}/users/{request.auth.uid}/**`, image content-type + size cap (e.g. ≤ 8 MB).
- read: any signed-in user (discovery in Plan 5 needs to show others' photos).
- Deploy: `firebase deploy --only storage` (single shared bucket; add `"storage": { "rules": "firebase/storage.rules" }` to `firebase.json`).

## 5. Routing — 4th onboarding state

`authRedirect` (pure) gains a profile-complete check:
- signed-out → `/auth/signin`
- signed-in, not age-verified → `/onboarding/age`
- signed-in, age-verified, **profile incomplete** → `/onboarding/profile`  ← new
- signed-in, age-verified, profile complete → `/` (home)
- guards prevent redirect loops (already on the target → null). **No skip** — the forced profile step cannot be bypassed.

The router reads `currentUserDocProvider` for both `ageVerified` and `profileComplete`.

## 6. Screens & controllers (clean layers)

- `user/application/profile_controller.dart` — an `AsyncNotifier` exposing: `updateFields({displayName, bio, gender})`, `addPhoto(File)` (upload + append URL), `removePhoto(url)`, and load state. Depends on `userRepositoryProvider` + the photo datasource/repo. Fires analytics.
- `user/presentation/widgets/profile_form.dart` — shared form (name, gender selector, bio, photo grid with add/remove + upload progress). Tokens; all states.
- `onboarding/presentation/profile_setup_screen.dart` — the forced setup step (route `/onboarding/profile`); uses the shared form; on complete, router advances to home. No skip/back-out.
- `user/presentation/profile_edit_screen.dart` — settings-side edit (same form, "save" returns). Reachable later from settings; built now.

## 7. Analytics

Declared in `lib/core/analytics/events.dart` + mirrored in `docs/TRACKING-PLAN.md`, no PII:
- `profile_completed` (fired when a profile first becomes complete)
- `profile_photo_added` (props: `count`)
- `profile_edited`

## 8. Rules & config

- `users/{uid}`: existing owner-only create/update rules already permit profile field writes; keep. (Read stays owner-only for now; Plan 5 opens read to signed-in for discovery.)
- Add `firebase/storage.rules` + `firebase.json` storage entry; deploy.
- `FlavorConfig.storagePathPrefix` added + unit-tested.

## 9. Testing

- Entity: `profileComplete` true/false across field combinations; `Gender` serialization.
- DTO round-trip with the new fields (incl. null gender/bio).
- Repo `updateProfile` merge (fake_cloud_firestore) — partial update doesn't clobber other fields.
- Photo datasource: mock `firebase_storage` — upload returns URL, path is env-prefixed; delete called.
- `profile_controller`: addPhoto appends URL + fires `profile_photo_added`; updateFields writes; completion fires `profile_completed`.
- Redirect: the 4th state (age-verified + incomplete → `/onboarding/profile`; complete → `/`), loop-safe.
- Form widget: required-field validation (name + ≥1 photo + gender), states.

## 10. Non-goals (deferred)

- Image moderation (Plan 9), profile/photo verification.
- Opening `users` read to all signed-in users for discovery (Plan 5).
- Editing DOB / re-running the age gate.
- Extra fields (cuisines, city, languages) — post-v1.

## 11. Delivery

Own plan on branch `plan-3-profile` (stacked on `rename-convyve`), executed subagent-driven. Ordered so the tree stays green: deps + FlavorConfig prefix → entity/DTO/gender + rules → photo datasource + storage.rules → repo updateProfile + providers → controller → form + screens → routing 4th state → verify/build/PR.
