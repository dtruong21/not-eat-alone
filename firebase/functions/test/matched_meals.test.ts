import {
  SCHEDULER_FLAGS,
  planGuestLeft,
  shouldNotifyGuestOfHostLeaving,
} from '../src/lib/matched_meals';
import { buildMatchLeft, buildMealCancelled } from '../src/lib/payloads';

const NOW = Date.UTC(2026, 9, 12, 12);
const HOUR = 3_600_000;

describe('planGuestLeft', () => {
  test('a future meal reopens, clears the guest and the scheduler flags', () => {
    const plan = planGuestLeft(NOW + 5 * HOUR, NOW);
    expect(plan.set).toEqual({ status: 'open', guestId: null });
    expect(plan.reopened).toBe(true);
    expect(plan.deleteFields).toEqual([...SCHEDULER_FLAGS]);
    expect(plan.deleteFields).toContain('reminder24hSent');
    expect(plan.deleteFields).toContain('reminder2hSent');
    expect(plan.deleteFields).toContain('postMealNotified');
  });

  test('a meal whose time has passed is cancelled (nobody left to rate)', () => {
    const plan = planGuestLeft(NOW - HOUR, NOW);
    expect(plan.set).toEqual({ status: 'cancelled', guestId: null });
    expect(plan.reopened).toBe(false);
    expect(plan.deleteFields).toEqual([]);
  });

  test('the exact start time counts as passed', () => {
    expect(planGuestLeft(NOW, NOW).reopened).toBe(false);
  });
});

describe('host leaving', () => {
  test('only future meals notify the matched guest', () => {
    expect(shouldNotifyGuestOfHostLeaving(NOW + HOUR, NOW)).toBe(true);
    expect(shouldNotifyGuestOfHostLeaving(NOW - HOUR, NOW)).toBe(false);
  });
});

describe('payloads', () => {
  test('match_left says whether the meal reopened', () => {
    const open = buildMatchLeft(true, 'm1');
    expect(open.data).toEqual({ type: 'match_left', mealId: 'm1', reopened: 'true' });
    expect(open.notification.body).toMatch(/open again/);
    const cancelled = buildMatchLeft(false, 'm1');
    expect(cancelled.data.reopened).toBe('false');
    expect(cancelled.notification.body).toMatch(/cancelled/);
  });

  test('meal_cancelled carries the meal id', () => {
    const p = buildMealCancelled('m2');
    expect(p.data).toEqual({ type: 'meal_cancelled', mealId: 'm2' });
  });
});
