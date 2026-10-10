/** Pure helpers for the scheduled pre-meal reminders (windows + Paris-time formatting). */

export type ReminderKind = '24h' | '2h';
export const REMINDER_KINDS: readonly ReminderKind[] = ['24h', '2h'];

/** Meal doc field set once a reminder of that kind has been attempted. */
export const REMINDER_FLAG: Record<ReminderKind, string> = {
  '24h': 'reminder24hSent',
  '2h': 'reminder2hSent',
};

const HOUR_MS = 3_600_000;

/**
 * A reminder is due while the meal starts inside `(fromMs, toMs]` from now. The
 * lower bound keeps a late match from getting a stale "tomorrow" reminder and
 * bounds how far a missed scheduler run can lag; the flag makes it fire once.
 */
const WINDOW_HOURS: Record<ReminderKind, { from: number; to: number }> = {
  '24h': { from: 22, to: 24 },
  '2h': { from: 1, to: 2 },
};

export function reminderWindow(
  kind: ReminderKind,
  nowMs: number,
): { fromMs: number; toMs: number } {
  const w = WINDOW_HOURS[kind];
  return { fromMs: nowMs + w.from * HOUR_MS, toMs: nowMs + w.to * HOUR_MS };
}

/** v1 is Paris-only, so meal times are shown in Paris local time. */
export const MEAL_TIME_ZONE = 'Europe/Paris';

export function formatMealTime(d: Date): string {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: MEAL_TIME_ZONE,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(d);
}

const parisDay = (d: Date): string =>
  new Intl.DateTimeFormat('en-CA', { timeZone: MEAL_TIME_ZONE }).format(d);

/** `today` when the meal is on the same Paris calendar day as `now`, else `tomorrow`. */
export function mealDayLabel(mealAt: Date, now: Date): 'today' | 'tomorrow' {
  return parisDay(mealAt) === parisDay(now) ? 'today' : 'tomorrow';
}
