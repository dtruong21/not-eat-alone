# Project Template — Firebase Mobile (Expo + RN)

A starting point for solo-built mobile MVPs. Ships the Claude Code config, docs scaffolding, and a strict development workflow optimized for **token efficiency** and **QA quality**.

**Stack:** React Native (Expo) + Firebase (Auth, Firestore, Functions) + TanStack Query + Zustand + NativeWind + Jest.

---

## What this template gives you

| Layer | Content |
|---|---|
| **Claude config** | 6 specialized agents (product-strategist, ux-designer, mobile-engineer, qa-engineer, release-engineer, marketer) + 17 slash commands |
| **Workflow** | Strict spec → design → build → test → release pipeline with handoff rules |
| **Design system family** | 3 cross-platform pre-built systems: `notion-github`, `linear-minimal`, `warm-playful`. Pick one per project during setup. |
| **Analytics layer** | Tracking plan (`docs/TRACKING-PLAN.md`) + typed event registry + provider-agnostic client. `/track` keeps the doc and types in sync. |
| **Feedback loop** | In-app feedback hook + Firestore pattern + `feedback_submitted` event baked in. |
| **Launch playbook** | Marketer agent + `LAUNCH.md` runbook + `/aso` + `/launch <channel>` commands. |
| **Solo-dev forcing functions** | `/weekly-review` Monday checkpoint, energy check, burnout flagging. |
| **Docs scaffolding** | PRD, Workflows, Tracking plan, Test plan, Roadmap, Release runbook, Launch playbook, Security, Store metadata, Legal templates |
| **QA emphasis** | Severity rubric, universal edge-case checklist, bug templates, pre-release gate |
| **Token discipline** | Slash commands delegate to agents (keeps main-loop context lean) + constrained output formats |

---

## How to use it

Read [`SETUP.md`](SETUP.md) end-to-end. It walks you through copying the template, generating the Expo project on top, filling placeholders, and getting Firebase wired up.

Once instantiated, the development loop is:

```
/spec <feature>      → product-strategist writes the PRD entry
/design <screen>     → ux-designer writes the screen spec
/build <feature>     → mobile-engineer implements it
/test <feature>      → qa-engineer writes tests + edge-case sweep
/release <channel>   → release-engineer cuts the build
```

Plus micro-tasks (`/bug`, `/scope-check`, `/next`, `/qa-sweep`), scaffolds (`/firestore`, `/hook`), and efficiency commands (`/why`, `/diff`).

Full slash-command index at [`.claude/commands/README.md`](.claude/commands/README.md).

---

## Design philosophy

- **Solo developer first.** No CODEOWNERS, no PR templates, no team rituals. Add them when you have a team.
- **Token efficiency through delegation.** Each agent's specialist context lives in its `.md` file — loaded only when its slash command fires.
- **QA is the gate.** No release ships without a green run of the test plan.
- **Strict ordering.** Spec → Design → Build → Test. Skipping a step always costs more later.

---

## Sibling templates

This template lives in the [`react-native/`](.) subdir of a multi-stack templates repo. A Flutter sibling lives at [`../flutter/`](../flutter) in the same repo.

| Stack | Path | When to pick |
|---|---|---|
| **React Native** (this one) | `react-native/` | JavaScript ecosystem, EAS Build for cloud builds, Zustand + TanStack Query, NativeWind. Fastest iteration. |
| **Flutter** | `../flutter/` | Dart strict typing, native compiled UI, Material 3, Riverpod with codegen, Codemagic for cloud builds. Strongest correctness guarantees. |

Both share the same workflow (`/spec → /design → /build → /test → /release → /launch`), the same 6 agents + 17 slash commands shape, the same 3 swappable design systems (notion-github, linear-minimal, warm-playful), and the same standing rules (MVP-first, UX priority, QA gate, analytics-first, token discipline). Pick the stack; the process is the same.

## Why Firebase

The template is intentionally Firebase-only because:

- **Security model is well-understood.** Rules + Auth replace 90% of what a custom backend would do.
- **Free tier supports MVPs.** Most projects ship to TestFlight before paying anything.
- **Cloud Functions cover the gaps.** When the client can't (cascade-deletes, server-side validation), Functions do.
- **One vendor, one mental model.** Auth state, data persistence, and compute share an identity.

If you're considering a different backend (Supabase, custom Node, etc.), this template is not the right starting point — fork and adapt, or use a different template.

---

## File layout

```
.claude/
  agents/          6 specialized agents (incl. marketer)
  commands/        17 slash commands (workflow + micro-tasks + scaffolds + marketing + efficiency)
design-systems/    3 pre-built systems (pick one in SETUP.md Step 3.5)
  notion-github/   tokens.ts + DESIGN.md + tailwind preset + mood.svg
  linear-minimal/  ...
  warm-playful/    ...
  README.md        which-to-pick guide
docs/
  PRD.md           Product requirements (pillars + feature specs)
  WORKFLOWS.md     Agent handoff map + 4 workflows
  TRACKING-PLAN.md Analytics PRD (events, properties, metrics, privacy)
  TEST-PLAN.md     QA checklist (universal + per-feature)
  ROADMAP.md       Phase status
  RELEASE.md       10-step release runbook (cutting builds)
  LAUNCH.md        Launch playbook (T-4w → T+7d, Product Hunt + tweet + email + community)
  SECURITY.md      Threat model + secrets policy
  STORE_METADATA.md  App Store + Play Store copy
  weekly-reviews/  output dir for /weekly-review
  legal/           Privacy + Terms boilerplate
  bugs/            Active bug reports (auto-filled by /bug)
    closed/        Closed bugs archive
  (DESIGN.md is created from the chosen design-system at setup)
lib/
  analytics/       client.ts + events.ts (typed event registry) + README
features/
  feedback/        useFeedback hook + pattern README
scripts/
  pick-design-system.sh   one-shot picker (Step 3.5)
CLAUDE.md          Claude constitution — loaded every session
SETUP.md           Bootstrap guide (read first)
README.md          This file
```

---

## When to update the template itself

This template is meant to evolve. After you ship a project and notice a pattern that worked (or one that bit you), come back and:

- Add a new slash command if you typed the same prompt 3+ times
- Add a new edge case to `docs/TEST-PLAN.md` § Universal if a bug bit two different projects
- Refine an agent's prompt if the agent kept making the same wrong choice

The template is the accumulated lesson. Update it.
