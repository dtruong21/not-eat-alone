---
description: Write a PRD entry for a new feature (product-strategist)
argument-hint: <feature name> — <one-line idea>
---

Use the `product-strategist` agent to write a PRD entry for: $ARGUMENTS

Requirements:
- Follow the exact format from the agent definition (Feature / Pillar / Status / User story / Acceptance criteria / Out of scope).
- Reject the feature if it serves none of the MVP pillars in `docs/PRD.md`. Say so plainly and stop.
- Append to `docs/PRD.md` under the matching pillar section. Do not duplicate.
- Output: the appended block only. No preamble, no summary.
