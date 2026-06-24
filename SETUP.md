# Setup — at the repo root

This README covers the **repo-level setup**. For starting a real project, each stack has its own SETUP.md inside its subdir — that's where the heavy lifting lives.

## Starting a new project (most common)

```bash
./scripts/new-project.sh <stack> <target-dir>
```

For example:

```bash
./scripts/new-project.sh react-native ~/Documents/habit-tracker
./scripts/new-project.sh flutter ~/Documents/journal-app
```

The script:

1. Copies `<stack>/` into `<target-dir>` (excluding `.git` so the template's history doesn't bleed in)
2. Initializes a fresh `git` repo on `main`
3. Tells you what to read next

Then `cd <target-dir>` and follow that project's `SETUP.md` from Step 2 onward (Step 1 is "clone the template," which the helper has already done for you).

## Improving the templates (rarer)

You're here because you want to refine an agent, add a slash command, polish a design system, or update a standing rule. Pick a stack:

```bash
cd react-native/   # or: cd flutter/
```

Inside the subdir, Claude Code picks up that stack's `CLAUDE.md` and `.claude/` tooling. Make the change, commit, push.

**Cross-stack edits** (a shared standing rule, a shared TEST-PLAN edge case, etc.) need to be mirrored across both subdirs. Drift between stacks is the cost of duplication; mirroring is the discipline that pays for it.

## Adding a new stack

1. Create `<stack>/` with the same shape as `react-native/` or `flutter/`: `CLAUDE.md`, `SETUP.md`, `.claude/`, `docs/`, `design-systems/`, and any code scaffolding the stack needs.
2. Add a row to the stacks table in both `CLAUDE.md` and `README.md` at the repo root.
3. Add the stack name to the `VALID` array in `scripts/new-project.sh`.

Each stack is fully isolated — no central refactor when adding a new one.
