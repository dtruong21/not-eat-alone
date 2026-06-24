# `lib/analytics`

The analytics layer. Components and hooks never call the analytics SDK directly — they call `track()` from this layer.

## Layout

```
lib/analytics/
  client.ts        the track() / identify() / reset() entry points
  events.ts        typed event registry (source of truth in code)
  README.md        this file
```

## The contract

1. **One source of truth in code.** All events the product can fire are declared in `events.ts` as a discriminated union. Anything not in the union fails to typecheck.
2. **One source of truth in docs.** Mirror in [`docs/TRACKING-PLAN.md`](../../docs/TRACKING-PLAN.md). They stay in sync via the `/track` command which writes both.
3. **Components consume `track()`, not the SDK.** The SDK choice (PostHog / Sentry / Mixpanel / etc.) is encapsulated in `client.ts`. Swapping providers means editing one file.
4. **Privacy is in the types.** Properties are explicitly typed. No `[key: string]: unknown` escape hatches. If a property isn't declared, it can't be sent.

## Adding an event

Use `/track <event_name>` — it appends a row to `TRACKING-PLAN.md` AND adds the typed entry here. Don't add events manually; the command keeps the two in sync.

## Picking a provider

The template's `client.ts` ships with a provider-agnostic skeleton. Wire one of these in:

| Provider | Use when |
|---|---|
| **PostHog** | You want product analytics + session replay + feature flags. Most flexible. Free tier generous. |
| **Sentry** | You're primarily after crash reporting + perf. Add analytics later. |
| **Firebase Analytics** | You're already on Firebase and want zero new dependencies. Best for funnels; weakest for ad-hoc analysis. |
| **Amplitude / Mixpanel** | Funnel analysis is your primary use case. Heavier setup. |

For solo mobile MVPs, **PostHog** is the default recommendation — it covers analytics, session replay, surveys, and feature flags in one place, and its free tier (~1M events/month) carries you well past MVP.

## Wiring the provider

`client.ts` is structured so the body of `track()`, `identify()`, and `reset()` is the only thing you change. The function signatures are the contract — they shouldn't change when you swap providers.
