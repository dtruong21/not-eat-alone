/**
 * Pure rules for the "Can't make it" callable (cancel as host / withdraw as guest from a
 * matched, future meal). `callable/cancel_matched_meal.ts` applies the result.
 */
import { SCHEDULER_FLAGS } from './matched_meals';

export type CancelRole = 'host' | 'guest';

export interface MealForCancel {
  status?: unknown;
  hostId?: unknown;
  guestId?: unknown;
  dateTimeMs: number;
}

export type CancelDecision =
  | { ok: false; code: 'not-found' | 'permission-denied' | 'failed-precondition'; message: string }
  | {
      ok: true;
      role: CancelRole;
      /** Fields to set on the meal. */
      set: { status: 'cancelled' | 'open'; guestId: string | null };
      /** Scheduler flags to delete from the meal (a reopened meal gets fresh reminders). */
      deleteFields: readonly string[];
      /** Who to notify, and how. */
      notifyUid: string;
      /** Whether to remove the guest's request doc (guest withdraw only). */
      removeGuestRequest: boolean;
    };

export function decideCancel(
  meal: MealForCancel | null,
  callerUid: string,
  nowMs: number,
): CancelDecision {
  if (!meal) return { ok: false, code: 'not-found', message: 'Meal not found.' };
  const hostId = meal.hostId as string | undefined;
  const guestId = meal.guestId as string | undefined;
  const isHost = callerUid === hostId;
  const isGuest = callerUid === guestId;
  if (!isHost && !isGuest) {
    return { ok: false, code: 'permission-denied', message: 'Not a participant of this meal.' };
  }
  if (meal.status !== 'matched' || !guestId || !hostId) {
    return { ok: false, code: 'failed-precondition', message: 'This meal is not matched.' };
  }
  if (meal.dateTimeMs <= nowMs) {
    return { ok: false, code: 'failed-precondition', message: 'This meal has already started.' };
  }
  if (isHost) {
    return {
      ok: true,
      role: 'host',
      set: { status: 'cancelled', guestId },
      deleteFields: [],
      notifyUid: guestId,
      removeGuestRequest: false,
    };
  }
  return {
    ok: true,
    role: 'guest',
    set: { status: 'open', guestId: null },
    deleteFields: SCHEDULER_FLAGS,
    notifyUid: hostId,
    removeGuestRequest: true,
  };
}
