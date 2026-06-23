/**
 * Event registry — the typed source of truth in code.
 *
 * Every event the app can fire is declared here as a discriminated union.
 * If an event isn't in the union, TypeScript rejects the send. This is
 * intentional — it keeps the analytics surface bounded.
 *
 * Mirror in human-readable form: docs/TRACKING-PLAN.md
 * Add new events via `/track <event_name>` — it updates both files.
 *
 * Discipline:
 * - Names: `noun_verb` past-tense, snake_case.
 * - Properties: scalars only. No nested objects.
 * - No PII as property values — reference by user_id only.
 */

// ─── Universal events ──────────────────────────────────────────────────────

export type AppOpened = {
  name: 'app_opened';
  props: {
    is_cold_start: boolean;
  };
};

export type SignupCompleted = {
  name: 'signup_completed';
  props: {
    method: 'email' | 'google' | 'apple' | 'anonymous';
  };
};

export type SigninCompleted = {
  name: 'signin_completed';
  props: {
    method: 'email' | 'google' | 'apple';
  };
};

export type SignoutCompleted = {
  name: 'signout_completed';
  props: Record<string, never>; // no properties
};

export type FeedbackSubmitted = {
  name: 'feedback_submitted';
  props: {
    category: 'bug' | 'idea' | 'praise' | 'other';
    length_chars: number;
  };
};

// ─── Project-specific events (extend below — keep this section growing) ────

// Example: uncomment and adapt
// export type HabitCreated = {
//   name: 'habit_created';
//   props: { schedule: 'daily' | 'weekdays' | 'custom'; has_reminder: boolean };
// };

// ─── Union of all events ───────────────────────────────────────────────────

export type AppEvent =
  | AppOpened
  | SignupCompleted
  | SigninCompleted
  | SignoutCompleted
  | FeedbackSubmitted;
  // | HabitCreated  // add new events here as you declare them above

// ─── User properties registry ──────────────────────────────────────────────

/**
 * Sparse by design. Add a property only when it drives segmentation or is
 * needed for cross-event analysis. Set via identify() in client.ts.
 */
export type UserProperties = {
  signup_date?: string;     // ISO date
  signup_method?: 'email' | 'google' | 'apple' | 'anonymous';
  app_version?: string;     // semver
  platform?: 'ios' | 'android' | 'web';
};

// ─── Helper: extract event name + props types ──────────────────────────────

export type EventName = AppEvent['name'];
export type EventProps<N extends EventName> = Extract<AppEvent, { name: N }>['props'];
