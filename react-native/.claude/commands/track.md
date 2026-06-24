---
description: Add a new event to the tracking plan (updates docs + typed registry)
argument-hint: <event_name> — <when it fires> — [prop1:type prop2:type ...]
---

Add an event to the tracking plan: $ARGUMENTS

Steps (run in order):

1. **Validate the name.** Must be `noun_verb` past-tense snake_case (e.g. `habit_created`, `friend_request_sent`). Reject `addedHabit`, `clickHabit`, `userDidX`.
2. **Append a row** to the event registry table in `docs/TRACKING-PLAN.md`:
   ```
   | `<event_name>` | <when> | `<prop>: <type>, ...` | <metric this feeds — ask if unclear> |
   ```
3. **Append a typed entry** to `lib/analytics/events.ts`:
   ```ts
   export type <PascalName> = {
     name: '<event_name>';
     props: { /* props with literal-narrowed types */ };
   };
   ```
   Then add `<PascalName>` to the `AppEvent` union.
4. **Confirm the metric link.** Every event must serve a metric in TRACKING-PLAN.md § NSM or § Supporting metrics. If it serves none, reject the event and tell the user to add a metric or drop the event.

Output:
- Path to the row added
- Path to the type added
- Metric it serves
- One-line example call: `track('<name>', { ... })`

No commentary. The diff IS the artifact.
