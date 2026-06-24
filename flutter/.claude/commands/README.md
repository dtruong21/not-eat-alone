# Slash command library

Type these in Claude Code to skip the long prompts. Each one delegates to the right agent with pre-filled context.

## Workflow (one per phase)

| Command | What it does | Agent |
|---|---|---|
| `/spec <name> — <idea>` | Write PRD entry, reject if not pillar-fit | product-strategist |
| `/design <screen>` | Design screen spec, append to DESIGN.md | ux-designer |
| `/build <feature>` | Implement: repository → provider → widget → route | mobile-engineer |
| `/test <feature>` | Tests + edge-case sweep, file bugs | qa-engineer |
| `/release <staging\|production>` | Run checklist, print build commands | release-engineer |

## Quick micro-tasks

| Command | What it does |
|---|---|
| `/bug <title> — <repro>` | File bug in standard format |
| `/scope-check <idea>` | 3-line IN-MVP / POST-MVP / CUT verdict |
| `/next` | One-line "what to build next" recommendation |
| `/qa-sweep` | Re-run edge-case checklist on current code |
| `/weekly-review` | 15-min Monday forcing function (state + top 3 next moves) |

## Scaffolds

| Command | What it does |
|---|---|
| `/firestore <collection> [field:type ...]` | Typed Firestore repository (Dart + freezed) |
| `/provider <name> <collection>` | Riverpod AsyncNotifier over a repository |
| `/track <event> — <when> — [props]` | Add an event to tracking plan + typed registry |

## Marketing

| Command | What it does | Agent |
|---|---|---|
| `/aso [focus]` | ASO research + draft updates to STORE_METADATA.md | marketer |
| `/launch <channel>` | Produce launch asset (product-hunt / tweet / email / community / press) | marketer |

## Pure efficiency (forced terse output)

| Command | What it does |
|---|---|
| `/why <file:line>` | Explain code in ≤100 words, lead with WHY |
| `/diff` | Working tree summary in ≤50 words |

## How they save tokens

Every command:
1. **Delegates to a sub-agent** — keeps the agent's specific context out of the main loop.
2. **Pre-fills the prompt** — you don't re-type "follow the format in the PRD, reject if not pillar-fit…"
3. **Constrains output** — explicit "no preamble", "≤N words", "file path only" lines.

You're paying for the agent's context once (when defined) instead of every turn.

## Adding a new command

Drop a file at `.claude/commands/<name>.md`:

```markdown
---
description: <one line, shown in /help>
argument-hint: <expected args>
---

<the prompt body. use $ARGUMENTS for the full arg string, or $1 $2 for positional.>
```

Keep the body under ~20 lines. If it grows longer, that's probably an agent, not a command.
