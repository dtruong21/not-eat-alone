import { ReminderKind, formatMealTime, mealDayLabel } from './reminders';
import { PushLang } from './push_lang';

export interface PushPayload {
  notification: { title: string; body: string };
  data: Record<string, string>;
}

const truncate = (s: string, n = 120): string =>
  s.length <= n ? s : `${s.slice(0, n - 1)}…`;

type Day = 'today' | 'tomorrow';

/**
 * All push copy, one table per language (review the French column in one place;
 * docs/l10n/PUSH-REVIEW.md mirrors it). `data` payloads are language-independent
 * and live in the builders below. French: informal tu, typographic apostrophe,
 * NBSP ( ) before ? ! : ;
 */
const COPY: Record<
  PushLang,
  {
    requestCreated: { title: string; body: string };
    requestApproved: { title: string; body: string };
    requestDenied: { title: string; body: string };
    postMealTitle: string;
    postMealBody: (otherName: string) => string;
    postMealFallbackName: string;
    reminderTitle24h: (day: Day) => string;
    reminderTitle2h: string;
    reminderBody: (restaurant: string, time: string) => string;
    matchLeftTitle: { left: string; withdrew: string };
    matchLeftBody: { reopened: string; cancelled: string };
    mealCancelledTitle: string;
    mealCancelledBody: { byHost: string; hostLeft: string };
  }
> = {
  en: {
    requestCreated: { title: 'New request', body: 'Someone wants to join your meal.' },
    requestApproved: { title: "You're in!", body: 'Your request was approved — say hi.' },
    requestDenied: { title: 'Request update', body: 'Your request was declined.' },
    postMealTitle: 'How was it?',
    postMealBody: (n) => `Rate your meal with ${n}.`,
    postMealFallbackName: 'your match',
    reminderTitle24h: (day) => `Your meal is ${day}`,
    reminderTitle2h: 'Your meal is coming up',
    reminderBody: (r, t) => `${r} at ${t}`,
    matchLeftTitle: { left: 'Your match left Convyve', withdrew: 'Your match withdrew' },
    matchLeftBody: {
      reopened: 'Your meal is open again so someone else can join.',
      cancelled: 'Your meal was cancelled.',
    },
    mealCancelledTitle: 'Meal cancelled',
    mealCancelledBody: {
      byHost: 'The host cancelled this meal.',
      hostLeft: 'The host left Convyve, so this meal is cancelled.',
    },
  },
  fr: {
    requestCreated: { title: 'Nouvelle demande', body: 'Quelqu’un veut se joindre à ton repas.' },
    requestApproved: {
      title: 'C’est bon !',
      body: 'Ta demande a été acceptée : dis bonjour.',
    },
    requestDenied: { title: 'Mise à jour de ta demande', body: 'Ta demande a été refusée.' },
    postMealTitle: 'Comment c’était ?',
    postMealBody: (n) => `Note ton repas avec ${n}.`,
    postMealFallbackName: 'l’autre personne',
    reminderTitle24h: (day) => `Ton repas, c’est ${day === 'today' ? 'aujourd’hui' : 'demain'}`,
    reminderTitle2h: 'Ton repas approche',
    reminderBody: (r, t) => `${r} à ${t}`,
    matchLeftTitle: {
      left: 'L’autre personne a quitté Convyve',
      withdrew: 'L’autre personne s’est retirée',
    },
    matchLeftBody: {
      reopened: 'Ton repas est de nouveau ouvert aux autres.',
      cancelled: 'Ton repas a été annulé.',
    },
    mealCancelledTitle: 'Repas annulé',
    mealCancelledBody: {
      byHost: 'L’hôte a annulé ce repas.',
      hostLeft: 'L’hôte a quitté Convyve, ce repas est donc annulé.',
    },
  },
};

/** Stands in for the other person's name in the post-meal prompt when it is unknown. */
export const postMealFallbackName = (lang: PushLang = 'en'): string =>
  COPY[lang].postMealFallbackName;

export function buildRequestCreated(lang: PushLang = 'en'): PushPayload {
  return {
    notification: { ...COPY[lang].requestCreated },
    data: { type: 'request' },
  };
}

export function buildRequestUpdated(
  status: 'approved' | 'denied',
  mealId = '',
  lang: PushLang = 'en',
): PushPayload {
  const c = COPY[lang];
  return {
    notification: { ...(status === 'approved' ? c.requestApproved : c.requestDenied) },
    data: { type: 'request_update', status, mealId },
  };
}

export function buildMessageCreated(
  senderName: string,
  text: string,
  matchId = '',
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _lang: PushLang = 'en', // user-written content: no copy to translate
): PushPayload {
  return {
    notification: { title: senderName, body: truncate(text) },
    data: { type: 'message', matchId },
  };
}

export function buildPostMealPrompt(otherName: string, lang: PushLang = 'en'): PushPayload {
  const c = COPY[lang];
  return {
    notification: { title: c.postMealTitle, body: c.postMealBody(otherName) },
    data: { type: 'rate', matchId: '' },
  };
}

export function buildMealReminder(
  kind: ReminderKind,
  restaurantName: string,
  mealAt: Date,
  now: Date,
  mealId = '',
  lang: PushLang = 'en',
): PushPayload {
  const c = COPY[lang];
  const title = kind === '24h' ? c.reminderTitle24h(mealDayLabel(mealAt, now)) : c.reminderTitle2h;
  return {
    notification: {
      title,
      body: c.reminderBody(truncate(restaurantName, 80), formatMealTime(mealAt)),
    },
    data: { type: 'meal_reminder', reminder: kind, mealId },
  };
}

/**
 * To the HOST when their matched guest is gone: deleted their account (default) or
 * withdrew from the meal (`withdrew: true`).
 */
export function buildMatchLeft(
  reopened: boolean,
  mealId = '',
  withdrew = false,
  lang: PushLang = 'en',
): PushPayload {
  const c = COPY[lang];
  return {
    notification: {
      title: withdrew ? c.matchLeftTitle.withdrew : c.matchLeftTitle.left,
      body: reopened ? c.matchLeftBody.reopened : c.matchLeftBody.cancelled,
    },
    data: { type: 'match_left', mealId, reopened: String(reopened) },
  };
}

/**
 * To the matched GUEST when the meal is gone: the host deleted their account (default) or
 * cancelled the meal (`byHost: true`).
 */
export function buildMealCancelled(
  mealId = '',
  byHost = false,
  lang: PushLang = 'en',
): PushPayload {
  const c = COPY[lang];
  return {
    notification: {
      title: c.mealCancelledTitle,
      body: byHost ? c.mealCancelledBody.byHost : c.mealCancelledBody.hostLeft,
    },
    data: { type: 'meal_cancelled', mealId },
  };
}
