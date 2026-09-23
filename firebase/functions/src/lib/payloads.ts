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
