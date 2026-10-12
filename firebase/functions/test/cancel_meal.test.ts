import { decideCancel } from '../src/lib/cancel_meal';
import { SCHEDULER_FLAGS } from '../src/lib/matched_meals';
import { buildMatchLeft, buildMealCancelled } from '../src/lib/payloads';

const NOW = Date.UTC(2026, 9, 12, 12);
const HOUR = 3_600_000;
const meal = (over = {}) => ({
  status: 'matched',
  hostId: 'H',
  guestId: 'G',
  dateTimeMs: NOW + 5 * HOUR,
  ...over,
});

describe('decideCancel', () => {
  test('host cancels: meal cancelled, guest notified, request untouched', () => {
    const d = decideCancel(meal(), 'H', NOW);
    expect(d).toMatchObject({
      ok: true,
      role: 'host',
      set: { status: 'cancelled', guestId: 'G' },
      notifyUid: 'G',
      removeGuestRequest: false,
    });
  });

  test('guest withdraws: meal reopens with fresh flags, host notified, request removed', () => {
    const d = decideCancel(meal(), 'G', NOW);
    expect(d).toMatchObject({
      ok: true,
      role: 'guest',
      set: { status: 'open', guestId: null },
      notifyUid: 'H',
      removeGuestRequest: true,
    });
    if (d.ok) expect(d.deleteFields).toEqual([...SCHEDULER_FLAGS]);
  });

  test('strangers cannot cancel', () => {
    expect(decideCancel(meal(), 'X', NOW)).toMatchObject({ ok: false, code: 'permission-denied' });
  });

  test('missing meal', () => {
    expect(decideCancel(null, 'H', NOW)).toMatchObject({ ok: false, code: 'not-found' });
  });

  test.each(['open', 'cancelled', 'completed'])('a %s meal cannot be cancelled', (status) => {
    expect(decideCancel(meal({ status }), 'H', NOW)).toMatchObject({
      ok: false,
      code: 'failed-precondition',
    });
  });

  test('a meal that has started cannot be cancelled', () => {
    expect(decideCancel(meal({ dateTimeMs: NOW }), 'G', NOW)).toMatchObject({
      ok: false,
      code: 'failed-precondition',
    });
    expect(decideCancel(meal({ dateTimeMs: NOW - HOUR }), 'H', NOW)).toMatchObject({ ok: false });
  });

  test('a second call after the meal was already cancelled is rejected', () => {
    expect(decideCancel(meal({ status: 'cancelled' }), 'G', NOW)).toMatchObject({ ok: false });
  });
});

describe('cancel push wording', () => {
  test('host cancellation vs host deleted account', () => {
    expect(buildMealCancelled('m', true).notification.body).toMatch(/host cancelled/);
    expect(buildMealCancelled('m').notification.body).toMatch(/left Convyve/);
  });
  test('guest withdrawal vs deleted account', () => {
    expect(buildMatchLeft(true, 'm', true).notification.title).toBe('Your match withdrew');
    expect(buildMatchLeft(true, 'm').notification.title).toBe('Your match left Convyve');
    expect(buildMatchLeft(true, 'm', true).data.type).toBe('match_left');
  });
});
