import { ReminderKind, formatMealTime, mealDayLabel } from './reminders';

export interface PushPayload {
  notification: { title: string; body: string };
  data: Record<string, string>;
}

const truncate = (s: string, n = 120): string =>
  s.length <= n ? s : `${s.slice(0, n - 1)}…`;

export function buildRequestCreated(): PushPayload {
  return {
    notification: { title: 'New request', body: 'Someone wants to join your meal.' },
    data: { type: 'request' },
  };
}

export function buildRequestUpdated(status: 'approved' | 'denied', mealId = ''): PushPayload {
  const approved = status === 'approved';
  return {
    notification: {
      title: approved ? "You're in!" : 'Request update',
      body: approved ? 'Your request was approved — say hi.' : 'Your request was declined.',
    },
    data: { type: 'request_update', status, mealId },
  };
}

export function buildMessageCreated(senderName: string, text: string, matchId = ''): PushPayload {
  return {
    notification: { title: senderName, body: truncate(text) },
    data: { type: 'message', matchId },
  };
}

export function buildPostMealPrompt(otherName: string): PushPayload {
  return {
    notification: { title: 'How was it?', body: `Rate your meal with ${otherName}.` },
    data: { type: 'rate', matchId: '' },
  };
}

export function buildMealReminder(
  kind: ReminderKind,
  restaurantName: string,
  mealAt: Date,
  now: Date,
  mealId = '',
): PushPayload {
  const title =
    kind === '24h' ? `Your meal is ${mealDayLabel(mealAt, now)}` : 'Your meal is coming up';
  return {
    notification: {
      title,
      body: `${truncate(restaurantName, 80)} at ${formatMealTime(mealAt)}`,
    },
    data: { type: 'meal_reminder', reminder: kind, mealId },
  };
}

/** To the HOST when their matched guest deleted their account. */
export function buildMatchLeft(reopened: boolean, mealId = ''): PushPayload {
  return {
    notification: {
      title: 'Your match left Convyve',
      body: reopened
        ? 'Your meal is open again so someone else can join.'
        : 'Your meal was cancelled.',
    },
    data: { type: 'match_left', mealId, reopened: String(reopened) },
  };
}

/** To the matched GUEST when the host deleted their account (the meal is gone). */
export function buildMealCancelled(mealId = ''): PushPayload {
  return {
    notification: {
      title: 'Meal cancelled',
      body: 'The host left Convyve, so this meal is cancelled.',
    },
    data: { type: 'meal_cancelled', mealId },
  };
}
