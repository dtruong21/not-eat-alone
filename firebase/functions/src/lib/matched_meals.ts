/**
 * What to do with MATCHED meals when one of their two people deletes their account.
 * Pure (no Firestore) so the rules are unit-testable; `delete_account.ts` applies them.
 */

/** Meal fields written by the reminder schedulers; cleared when a meal is reopened. */
export const SCHEDULER_FLAGS = ['reminder24hSent', 'reminder2hSent', 'postMealNotified'] as const;

export interface GuestLeftPlan {
  /** Fields to set on the meal. */
  set: { status: 'open' | 'cancelled'; guestId: null };
  /** Fields to delete from the meal (scheduler flags: the reopened meal gets fresh reminders). */
  deleteFields: readonly string[];
  /** Whether the meal is joinable again (still in the future). */
  reopened: boolean;
}

/**
 * The matched guest deleted their account. A meal that has not happened yet goes back to
 * `open` (another person can join; Discover lists it again); one whose time has passed is
 * `cancelled`, so nobody is prompted to rate a person who no longer exists.
 */
export function planGuestLeft(mealDateTimeMs: number, nowMs: number): GuestLeftPlan {
  const reopened = mealDateTimeMs > nowMs;
  return {
    set: { status: reopened ? 'open' : 'cancelled', guestId: null },
    deleteFields: reopened ? SCHEDULER_FLAGS : [],
    reopened,
  };
}

/**
 * The host deleted their account: their meals are deleted, so a matched guest whose meal has
 * not happened yet should be told (their chat disappears). Past meals need no message.
 */
export function shouldNotifyGuestOfHostLeaving(mealDateTimeMs: number, nowMs: number): boolean {
  return mealDateTimeMs > nowMs;
}
