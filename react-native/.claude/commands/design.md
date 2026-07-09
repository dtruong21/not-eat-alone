---
description: Design a screen spec (designer hat, main loop)
argument-hint: <screen name>
---

Wear the **designer hat** (`docs/PRINCIPLES.md § Role hats`). Produce a screen spec for: $ARGUMENTS

Pre-flight: the PRD entry must exist in `docs/PRD.md`. If missing, stop and ask for a `/spec` run first.

- Apply the active design system in `docs/DESIGN.md`. Tokens only — a new value means a new token in `lib/design/tokens.ts` first.
- Reuse existing primitives in `components/` before proposing new ones.
- Design ALL states: empty, loading, error, offline, filled. States are first-class, not "polish later."
- Accessibility in v1: dark-mode parity, screen-reader labels, dynamic type.
- Produce an SVG mockup via Artifact only when the layout is non-obvious (frame 390×844).
- Format: **Screen / Purpose / Route / Layout (top→bottom) / Components (new|reused) / States / Interactions**.
- Append to `docs/DESIGN.md § Screen specs`. Output the appended block only.
