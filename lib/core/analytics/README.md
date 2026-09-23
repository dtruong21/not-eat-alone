# `lib/core/analytics`

The analytics layer. Widgets and providers never call the analytics SDK directly — they call `track()` from this layer.

## Layout

```
lib/core/analytics/
  client.dart       the track() / identify() / reset() entry points
  events.dart       typed event registry (source of truth in code)
  README.md         this file
```

## The contract

1. **One source of truth in code.** All events the product can fire are declared in `events.dart` as a Dart `sealed class` hierarchy. Anything not in the hierarchy fails to compile.
2. **One source of truth in docs.** Mirror in [`docs/TRACKING-PLAN.md`](../../../docs/TRACKING-PLAN.md). They stay in sync via the `/track` command which writes both.
3. **Widgets consume `track()`, not the SDK.** The SDK is encapsulated in `client.dart` behind an injectable sink. Swapping providers means editing one file.
4. **Privacy is in the types.** Each event's properties are explicit fields on its class. There's no `Map<String, Object?>` escape hatch at the call site — `props` is computed inside the class. If a property isn't declared, it can't be sent.
5. **`track()`/`identify()`/`reset()` never throw.** Every send is wrapped in try/catch inside `client.dart` — a failed analytics call logs via `debugPrint` and returns normally. This is what makes it safe to call `track()` from inside `AsyncValue.guard` in a mutation controller: a dropped analytics event never fails the mutation.

## Adding an event

Use `/track <event_name>` — it appends a row to `TRACKING-PLAN.md` AND adds the typed entry here. Don't add events manually; the command keeps the two in sync.

## Provider: Firebase Analytics

We standardize on **Firebase Analytics** (`firebase_analytics`) — zero new third-party keys to secure, and we're already on Firebase for Auth/Firestore/Functions. Crash reporting is **Firebase Crashlytics** (`firebase_crashlytics`), wired separately in `main_common.dart`; it is not part of this layer.

- `track(event)` → `FirebaseAnalytics.instance.logEvent(name: event.name, parameters: event.props)` (nulls dropped — Firebase Analytics params must be `String`/`num`).
- `identify(uid, props)` → `setUserId(id: uid)` + `setUserProperty` per non-null field.
- `reset()` → `setUserId(id: null)`.
- Firebase Analytics event names must be ≤40 chars, snake_case — the typed registry already complies (`noun_verb`, past tense).

## Wiring the provider

`client.dart` routes every call through a small injectable sink (`LogEvent` typedef) so the file is unit-testable without the plugin. The public `track()`/`identify()`/`reset()` signatures are the contract — they don't change when the sink implementation changes. Test-only seams (`debugSetLogSink`, `debugSetForceSend`, `debugResetAnalytics`) let tests override the sink and bypass the debug-drop guard.

## Why a sealed class (not a Map)

A sealed class buys two things a plain `Map<String, Object?>` doesn't:

- **Exhaustiveness on the consumer side.** If you ever want to route certain events to a side channel (Slack, Discord), `switch (event)` is exhaustive — the compiler tells you when you forget the new event.
- **Per-event property types.** `SignupCompleted.method` is a typed `String`, not `Object?` you have to cast. The compiler catches misspellings and wrong types at the call site.
