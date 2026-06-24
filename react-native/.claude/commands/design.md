---
description: Design a screen using the project's design language (ux-designer)
argument-hint: <screen name> [— optional notes]
---

Use the `ux-designer` agent to design the screen: $ARGUMENTS

Steps:
1. Read the PRD entry for this screen in `docs/PRD.md` first. If missing, stop and ask for a `/spec` run.
2. Produce the spec in the agent's standard format (Purpose / Route / Layout / Components / States / Interactions).
3. Reuse components from `components/` before proposing new ones.
4. Append the spec to `docs/DESIGN.md` under "Screen specs".
5. Only render an SVG mockup via Artifact if the layout is non-obvious (skip for list/form screens).

Output: the appended spec only. No design rationale unless asked.
