---
description: Implement a feature (mobile-engineer)
argument-hint: <feature name from PRD>
---

Use the `mobile-engineer` agent to implement: $ARGUMENTS

Pre-flight (stop and ask if any fail):
- PRD entry exists in `docs/PRD.md` for this feature.
- Design spec exists in `docs/DESIGN.md` if a UI is involved.

Build order (strict):
1. Repository in `lib/core/firebase/<collection>_repository.dart` (freezed model + `.withConverter`)
2. Riverpod provider in `lib/features/<name>/application/<name>_provider.dart` (AsyncNotifier via `@riverpod`)
3. Widget(s) in `lib/features/<name>/presentation/`
4. Route in `lib/core/routing/router.dart` (typed via `@TypedGoRoute`)
5. Analytics events via `/track` for any user moment that maps to a metric in `docs/TRACKING-PLAN.md`

Constraints:
- No `dynamic`. No direct `cloud_firestore` imports in widgets or providers — only inside `lib/core/firebase/`.
- No magic values — pull colors/spacing/typography from `lib/core/design/tokens.dart` and `Theme.of(context)`.
- Use `const` constructors wherever possible. No relative imports across feature boundaries — `package:app_name/...` only.
- No direct analytics SDK calls — always `track(AppEvent.x(...))` from `lib/core/analytics/client.dart`.
- Run `dart run build_runner build --delete-conflicting-outputs` after touching anything annotated (`@freezed`, `@riverpod`, `@TypedGoRoute`).
- Test the happy path: `flutter test test/features/<name>/` plus a manual run on iOS + Android sim before declaring done.
- After done, hand off to `qa-engineer` via `/test <feature>`.
- Output: file diffs only. No restating the spec, no walkthrough of the code unless asked.
