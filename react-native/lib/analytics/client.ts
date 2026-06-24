/**
 * Analytics client — the only place the analytics SDK is touched.
 *
 * Components and hooks call `track()` / `identify()` / `reset()` from here.
 * Swapping providers (PostHog → Mixpanel → Firebase Analytics → etc.) means
 * changing the body of these three functions, never the call sites.
 *
 * Provider currently: NONE (skeleton). Wire one in — see lib/analytics/README.md.
 */

import type { AppEvent, EventName, EventProps, UserProperties } from './events';

// ─── Provider wiring (pick one, delete the rest) ───────────────────────────

// Example — PostHog (uncomment + install posthog-react-native + set env var):
//
// import PostHog from 'posthog-react-native';
// const posthog = new PostHog(process.env.EXPO_PUBLIC_POSTHOG_KEY!, {
//   host: 'https://us.i.posthog.com',
// });

// ─── Public API ────────────────────────────────────────────────────────────

/**
 * Fire a typed event. The name + props pair must be declared in events.ts.
 * Unknown events fail to typecheck.
 */
export function track<N extends EventName>(name: N, props: EventProps<N>): void {
  // Drop in dev unless you explicitly want to debug — keeps the prod stream clean.
  if (__DEV__ && !process.env.EXPO_PUBLIC_ANALYTICS_IN_DEV) {
    console.log('[analytics:dev]', name, props);
    return;
  }

  // Provider call goes here. Example:
  // posthog.capture(name, props);
  void name;
  void props;
}

/**
 * Associate subsequent events with a user. Call on sign-up + sign-in.
 * `uid` is the Firebase Auth uid; never an email or name.
 */
export function identify(uid: string, properties?: UserProperties): void {
  if (__DEV__ && !process.env.EXPO_PUBLIC_ANALYTICS_IN_DEV) {
    console.log('[analytics:dev] identify', uid, properties);
    return;
  }

  // posthog.identify(uid, properties);
  void uid;
  void properties;
}

/**
 * Disassociate the current device from a user. Call on sign-out.
 * Without this, subsequent anonymous events incorrectly attribute to the prior user.
 */
export function reset(): void {
  if (__DEV__ && !process.env.EXPO_PUBLIC_ANALYTICS_IN_DEV) {
    console.log('[analytics:dev] reset');
    return;
  }

  // posthog.reset();
}

// Re-export the union so feature code can import event types from one place.
export type { AppEvent } from './events';
