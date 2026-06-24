# {{PROJECT_NAME}} — Claude Constitution

This file is loaded into every Claude session in this repo. Keep it tight — every line is paid for in tokens, every turn.

## What this project is

**One-line pitch:** {{ONE_LINE_PITCH}}

**Why it exists:** {{WHY}}

**Differentiator:** {{DIFFERENTIATOR}}

Full spec in `docs/PRD.md`. Design language in `docs/DESIGN.md`. Process in `docs/WORKFLOWS.md`. Analytics contract in `docs/TRACKING-PLAN.md`. Launch playbook in `docs/LAUNCH.md`.

A React Native sibling template (same workflow, different stack) lives at `../react-native/` in this same repo — useful for cross-referencing patterns when a rule applies to both stacks.

## Stack

- **App**: Flutter (SDK latest stable, pinned via `.fvmrc`), Dart with very_good_analysis, go_router
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **State**: Riverpod (AsyncNotifier via `@riverpod` codegen) for both local state and server cache
- **UI**: Material 3 ThemeData + design tokens from `lib/core/design/tokens.dart`
- **Builds**: Codemagic (CI), `flutter build` (local)
- **Tests**: flutter_test + integration_test + mocktail
- **Validation**: freezed + json_serializable at all Firestore boundaries

## Repo layout

```
lib/
  main.dart                       bootstrap: Firebase + ProviderScope
  app.dart                        MaterialApp.router + theme
  firebase_options.dart           generated, committed
  core/
    firebase/                     one repository per collection (typed wrappers)
    design/                       tokens.dart + theme.dart
    analytics/                    client.dart + events.dart (typed registry)
    routing/                      router.dart + routes.dart (typed go_router)
  features/<name>/
    data/                         repository impls, DTOs (rare)
    domain/                       freezed models, value objects
    application/                  Riverpod notifiers / providers
    presentation/                 screens + widgets
test/                             mirrors lib/; unit + widget
integration_test/                 E2E golden-path flows
firebase/
  firestore.rules                 security model — deployed
  functions/                      Cloud Functions (TypeScript)
docs/                             PRD, design, workflows, roadmap, test plan, release
```

## Conventions (non-negotiable)

- Dart strict mode via `very_good_analysis`. No `dynamic` leakage at boundaries — narrow with freezed + json_serializable.
- Firestore reads/writes go through `lib/core/firebase/<collection>_repository.dart` — never import `cloud_firestore` from feature code.
- Widgets are functions or `ConsumerWidget`. No inheritance-based UI logic.
- One screen = one widget in `features/<name>/presentation/`. Heavy logic lives in `application/` (Riverpod notifiers).
- Design tokens come from `lib/core/design/tokens.dart`. No magic numbers/colors in widgets.
- Tests live next to what they test under `test/`, mirroring the `lib/` tree.
- `ref.watch` is for `build()` only. Inside notifier methods, use `ref.read`.
- Server-set Firestore fields (`serverTimestamp`) are nullable in freezed models — `.withConverter` runs on optimistic snapshots.

## Workflow (strict order)

```
product-strategist → ux-designer → mobile-engineer → qa-engineer → release-engineer
```

Each agent's output is the next agent's input. Don't skip a step. If a later step uncovers a problem with an earlier one, kick back to that earlier agent — don't fix it on the fly. Full process in `docs/WORKFLOWS.md`.

## Agents available

| Agent | Use when |
|---|---|
| `product-strategist` | Defining scope, writing user stories, deciding what's in/out of MVP |
| `ux-designer` | Designing screens, picking components, applying the design language |
| `mobile-engineer` | Writing the Flutter + Firebase code |
| `qa-engineer` | Writing tests, finding bugs, verifying features on iOS + Android |
| `release-engineer` | Codemagic builds, version bumps, TestFlight/Play Console submissions |
| `marketer` | Store listings, landing copy, tweet threads, Product Hunt, ASO, launch playbook |

Definitions in `.claude/agents/`.

## Slash commands (token-saving lever)

| Phase | Command |
|---|---|
| Spec a feature | `/spec <name> — <idea>` |
| Design a screen | `/design <screen>` |
| Build a feature | `/build <feature>` |
| QA a feature | `/test <feature>` |
| Cut a release | `/release <staging\|production>` |

Micro-tasks: `/bug`, `/scope-check`, `/next`, `/qa-sweep`, `/weekly-review`.
Scaffolds: `/firestore`, `/provider`, `/track`.
Marketing: `/aso`, `/launch <channel>`.
Efficiency: `/why`, `/diff`.

Full index in `.claude/commands/README.md`. **Prefer these over re-typing prompts.**

## Token discipline (the rules I want you to follow this conversation)

1. **Delegate to agents via slash commands.** Don't re-explain agent context in the main loop.
2. **No preambles.** Skip "Sure, I'll do that." Just do it and report.
3. **No code dumps when a file path will do.** "Wrote `lib/core/firebase/foo_repository.dart`" beats pasting the file.
4. **No end-of-turn recaps.** The diff is the artifact.
5. **Ask before exploring widely.** Cheap-to-verify questions ("which feature?") save a round of guesswork.
6. **Use `Read` for known paths, `Grep`/`Glob` for symbol lookups. Don't read whole folders.**

## UX is the top priority

User experience wins every trade-off except MVP scope. The hierarchy:

```
MVP scope  >  UX quality  >  feature breadth  >  code elegance  >  dev convenience
```

If MVP and UX conflict, **cut the feature**. Don't ship a half-quality version of it. If UX conflicts with anything below it, UX wins.

**States are first-class.** Empty, loading, error, and offline ship with every feature — not "polish later." Every `AsyncValue` consumer renders `loading`, `error`, and `data`.
**Latency is UX.** Optimistic updates, no jank, taps respond in <100ms.
**Accessibility is UX.** Dark mode parity, screen reader paths, dynamic type — v1, not v1.1.

Route design decisions through `/design`. Push back on engineering choices that compromise UX without an explicit MVP-scope reason.

## v1 is an MVP — always

This is rule zero. **v1 ships the minimum viable subset that delivers the pillar outcomes — nothing more.** Polish, niceties, animations, "while we're at it" additions all wait for v1.1+.

When evaluating any feature proposal (yours or mine):
- Default verdict: **POST-MVP** or **CUT**. Make me argue features INTO v1, not out of it.
- If a feature *might* be MVP-fit, ask: "Is there a smaller version that still delivers the pillar outcome?" Ship the smaller one.
- States that ship in v1: empty, loading, error, golden path. Animations, micro-interactions, edge polish: v1.1.
- This applies even mid-build. If new scope appears, push back: "Is this v1 or v1.1?"

`/scope-check` and the `product-strategist` agent bias hard toward CUT. Trust them.

## Analytics is a first-class concern

The product without analytics is the product flying blind. The tracking plan at `docs/TRACKING-PLAN.md` is the analytics PRD — every event the product fires lives there BEFORE the code is written. Use `/track <event>` to add events (it updates both the doc and `lib/core/analytics/events.dart`).

Privacy: events carry no PII. The typed registry enforces this.

## Quality bar

The QA process is what keeps the product shippable. Read `.claude/agents/qa-engineer.md` and `docs/TEST-PLAN.md` before every release. **No release ships with open P0/P1 bugs.**

## Security model

`firebase_options.dart` is **committed and not secret**. Security comes from Firestore rules + Auth + App Check, not from hiding API keys. The actual secrets are: Firebase Admin service account, Codemagic signing keys, OAuth client secrets. See `docs/SECURITY.md`.

## When you're stuck

- Spec unclear → `/spec` to clarify with product-strategist.
- Design unclear → `/design` to ask ux-designer.
- Reused code unclear → use `Grep` for the symbol first.
- Don't invent. Ask.
