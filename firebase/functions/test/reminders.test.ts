import {
  REMINDER_FLAG,
  formatMealTime,
  mealDayLabel,
  reminderWindow,
} from '../src/lib/reminders';
import { buildMealReminder } from '../src/lib/payloads';

const HOUR = 3_600_000;

describe('reminderWindow', () => {
  test('24h window is 22h–24h ahead, 2h window is 1h–2h ahead', () => {
    expect(reminderWindow('24h', 0)).toEqual({ fromMs: 22 * HOUR, toMs: 24 * HOUR });
    expect(reminderWindow('2h', 1000)).toEqual({ fromMs: 1000 + HOUR, toMs: 1000 + 2 * HOUR });
  });
  test('each kind has its own idempotency flag', () => {
    expect(REMINDER_FLAG['24h']).not.toBe(REMINDER_FLAG['2h']);
  });
});

describe('formatMealTime (Paris)', () => {
  test('summer time is UTC+2', () => {
    expect(formatMealTime(new Date('2026-07-01T17:30:00Z'))).toBe('19:30');
  });
  test('winter time is UTC+1', () => {
    expect(formatMealTime(new Date('2027-01-05T18:30:00Z'))).toBe('19:30');
  });
  test('around the autumn DST change (2026-10-25 03:00 -> 02:00 local)', () => {
    expect(formatMealTime(new Date('2026-10-25T18:00:00Z'))).toBe('19:00');
  });
});

describe('mealDayLabel', () => {
  test('same Paris day is today, next day is tomorrow', () => {
    expect(mealDayLabel(new Date('2026-10-10T17:00:00Z'), new Date('2026-10-10T08:00:00Z'))).toBe('today');
    expect(mealDayLabel(new Date('2026-10-11T17:00:00Z'), new Date('2026-10-10T17:30:00Z'))).toBe('tomorrow');
  });
  test('uses the Paris calendar day, not UTC', () => {
    // 23:30Z on the 10th is already 01:30 on the 11th in Paris.
    expect(mealDayLabel(new Date('2026-10-10T23:30:00Z'), new Date('2026-10-10T10:00:00Z'))).toBe('tomorrow');
  });
});

describe('buildMealReminder', () => {
  const now = new Date('2026-10-10T17:30:00Z');
  const meal = new Date('2026-10-11T17:30:00Z');
  test('24h reminder', () => {
    const p = buildMealReminder('24h', 'Septime', meal, now, 'm1');
    expect(p.notification.title).toBe('Your meal is tomorrow');
    expect(p.notification.body).toBe('Septime at 19:30');
    expect(p.data).toEqual({ type: 'meal_reminder', reminder: '24h', mealId: 'm1' });
  });
  test('2h reminder', () => {
    const p = buildMealReminder('2h', 'Septime', meal, new Date('2026-10-11T15:45:00Z'), 'm1');
    expect(p.notification.title).toBe('Your meal is coming up');
    expect(p.data.reminder).toBe('2h');
  });
  test('long restaurant names are truncated', () => {
    const p = buildMealReminder('2h', 'x'.repeat(300), meal, now);
    expect(p.notification.body.length).toBeLessThan(100);
  });
});
