# Workflows

How work moves from idea to shipped. Six agents, five workflows.

## Agent handoff map

```
                  ┌─────────────────────┐
                  │  product-strategist │   defines what + why
                  └──────────┬──────────┘
                             │ PRD entry
                             ▼
                  ┌─────────────────────┐
                  │     ux-designer     │   defines how it looks
                  └──────────┬──────────┘
                             │ Design spec
                             ▼
                  ┌─────────────────────┐
                  │   mobile-engineer   │   implements + instruments
                  └──────────┬──────────┘
                             │ Working code + tracked events
                             ▼
                  ┌─────────────────────┐
                  │     qa-engineer     │   verifies (code + analytics)
                  └──────────┬──────────┘
                             │ Sign-off
                             ▼
                  ┌─────────────────────┐
                  │  release-engineer   │   ships build
                  └──────────┬──────────┘
                             │ Build live on TestFlight / Play
                             ▼
                  ┌─────────────────────┐
                  │      marketer       │   launches it to the world
                  └─────────────────────┘
```

Each agent's output is the next agent's input. Don't skip steps.

The `marketer` also runs in parallel with engineering during the T-4w → T-0 ramp (see `docs/LAUNCH.md`) — store listings, landing-page copy, ASO research happen alongside the build, not after.

---

## Workflow 1 — Feature development

**Trigger:** new feature idea, user request, or backlog item.

1. **Strategize** — `/spec <name> — <idea>` (product-strategist). PRD entry: user story, acceptance criteria, edge cases, out of scope. Appended to `docs/PRD.md`.
2. **Design** — `/design <screen>` (ux-designer). Screen spec, components list, states. Appended to `docs/DESIGN.md`. Mockup via Artifact if layout is non-obvious.
3. **Implement** — `/build <feature>` (mobile-engineer). Data layer (`lib/firebase/...`) → hook → component → route. In that order. Types everything. Tests happy path on iOS + Android simulator.
4. **QA** — `/test <feature>` (qa-engineer). RTL tests for the hook + component, edge-case sweep, bugs filed as `docs/bugs/<date>-<slug>.md`. Test plan updated.
5. **Loop** until P0/P1 bugs are clear. Then mark PRD entry `shipped` and move on.

**Hard rules:**
- Don't start step N before step N-1 is done.
- If `mobile-engineer` discovers the spec is wrong, kick back to `product-strategist` — don't fix it on the fly.
- If `ux-designer` realizes the design needs scope change, kick back to `product-strategist`.

---

## Workflow 2 — Bug fix

**Trigger:** bug reported (from QA, beta tester, production crash).

1. **Triage** — `qa-engineer` confirms repro, assigns severity (P0–P3), files the report.
2. **Diagnose** — `mobile-engineer` finds the root cause. If it's a spec gap (the bug exists because the requirement was ambiguous), kick to `product-strategist` for a PRD clarification.
3. **Fix** — `mobile-engineer` writes the minimal fix + a regression test that would have caught it. **The regression test is the price of admission** — no fix ships without one.
4. **Verify** — `qa-engineer` confirms the original repro is dead and runs related edge cases.
5. **Close** — bug file moves to `docs/bugs/closed/`. If P0/P1, append entry to next release's CHANGELOG.

**Severity → urgency:**
- P0: drop everything, ship a hotfix this day.
- P1: must clear before next release.
- P2: targeted for next release if cheap, otherwise next-next.
- P3: backlog.

---

## Workflow 3 — Release

**Trigger:** milestone hit (e.g. all pillar-1 features shipping), or scheduled cadence (every 1–2 weeks).

1. **QA sign-off** — `qa-engineer` runs the full pre-release checklist (`docs/TEST-PLAN.md` + agent's pre-release section). No P0/P1 outstanding.
2. **Strategize the cut** — `product-strategist` confirms what's in. Anything half-built gets feature-flagged off.
3. **Bump + tag** — `release-engineer` bumps `version`, `iosBuildNumber`, `androidVersionCode`. Updates `CHANGELOG.md`. Tags the commit.
4. **Build** — `eas build --profile staging --platform all` (or `production`).
5. **Deploy Firebase** — security rules + Cloud Functions deployed to target environment.
6. **Submit** — `eas submit` to TestFlight + Play internal.
7. **Smoke test the build** — `qa-engineer` installs the actual artifact on real device, runs the golden path. Not the simulator build — the store build.
8. **Promote** — if `staging` validates over 2–3 days, promote to `production`.

**Rollback path:** if `production` ships a P0, hotfix off the last good tag. See `release-engineer` agent for full procedure.

---

## Workflow 4 — Launch

**Trigger:** the release is live on TestFlight / Play Internal and ready for public discovery. Follows `docs/LAUNCH.md` start to finish.

1. **T-4w to T-2w (parallel with engineering)** — `marketer` builds the landing page, drafts initial store listing, opens the waitlist.
2. **T-2w** — `marketer` runs `/aso` against the latest PRD — updates `docs/STORE_METADATA.md`.
3. **T-1w** — `marketer` runs `/launch product-hunt`, `/launch tweet`, `/launch email` to draft assets. Drafts get a review pass.
4. **T-0 (launch day)** — `marketer` executes the launch-day checklist in `docs/LAUNCH.md`. Replies to every comment/DM within 1h.
5. **T+7d** — `product-strategist` writes the launch retro at `docs/postmortems/<date>-launch.md` (channels, NSM movement, v1.1 priorities).

**Hard rule:** don't launch with a cold list. T-4w marketing groundwork is non-negotiable.

---

## Workflow 5 — Design iteration

**Trigger:** a screen exists but feels wrong, or a new design token is needed.

1. `ux-designer` proposes the change in `docs/DESIGN.md` (token diff + rationale).
2. If a token changes, `mobile-engineer` updates `lib/design/tokens.ts` and the components consuming it.
3. `qa-engineer` does a visual regression sweep — every screen consuming the token, on light + dark.

---

## Cross-cutting practices

### Per session

- **Use slash commands.** Each `/command` delegates to the right agent with pre-filled context. That's the project's primary token-saving lever.
- **Open with `/diff` and `/next`** when you're unsure where to pick up — three lines tell you the state.

### Daily

- Update `docs/PRD.md` when scope shifts. Stale PRD is worse than no PRD.
- Move closed bugs to `docs/bugs/closed/`. Don't let the active dir grow.

### Weekly

- **Monday morning:** run `/weekly-review` — 15-min forcing function that surfaces stalled work, open P1s, roadmap drift, burnout risk. Output lands in `docs/weekly-reviews/<date>.md`.
- `product-strategist` reviews `docs/ROADMAP.md` against actual progress. Re-prioritize.
- `qa-engineer` re-runs the edge-case checklist (`/qa-sweep`) on `main`.
- Scan feedback (`features/feedback/` Firestore collection) — reply within 24h to anything substantive.

### Per release

- `release-engineer` writes a CHANGELOG entry that a non-technical user could understand.
- Bump version in `app.json`. Tag the commit.
- Smoke-test the store build on a real device.
