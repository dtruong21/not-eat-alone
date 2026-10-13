import {
  buildMessageCreated,
  buildRequestUpdated,
  buildPostMealPrompt,
  buildRequestCreated,
  buildMealReminder,
  buildMatchLeft,
  buildMealCancelled,
  postMealFallbackName,
  restaurantFallbackName,
  messageFallbackTitle,
} from '../src/lib/payloads';

test('message payload truncates long text and carries matchId via caller', () => {
  const p = buildMessageCreated('Amélie', 'x'.repeat(500));
  expect(p.notification.title).toBe('Amélie');
  expect(p.notification.body.length).toBeLessThanOrEqual(120);
  expect(p.data.type).toBe('message');
});

test('request_update approved vs denied body differs', () => {
  expect(buildRequestUpdated('approved').data.status).toBe('approved');
  expect(buildRequestUpdated('denied').data.status).toBe('denied');
});

test('post-meal prompt carries otherName in body and rate type, matchId filled by caller', () => {
  const p = buildPostMealPrompt('Sam');
  expect(p.notification.title).toBe('How was it?');
  expect(p.notification.body).toBe('Rate your meal with Sam.');
  expect(p.data.type).toBe('rate');
  expect(p.data.matchId).toBe('');
});

// ---- Plan 22: language-aware copy. English pinned from the pre-i18n source. ----
const NB = '\u00a0';
const meal = new Date('2026-10-14T18:00:00Z'); // 20:00 Paris (CEST)
const sameDay = new Date('2026-10-14T06:00:00Z');
const dayBefore = new Date('2026-10-13T18:00:00Z');

test('en: request created', () => {
  expect(buildRequestCreated().notification).toEqual({
    title: 'New request',
    body: 'Someone wants to join your meal.',
  });
  expect(buildRequestCreated('en').notification).toEqual(buildRequestCreated().notification);
});
test('fr: request created', () => {
  expect(buildRequestCreated('fr').notification).toEqual({
    title: 'Nouvelle demande',
    body: 'Quelqu’un veut se joindre à ton repas.',
  });
});

test('en: request updated', () => {
  expect(buildRequestUpdated('approved', 'm1').notification).toEqual({
    title: "You're in!",
    body: 'Your request was approved — say hi.',
  });
  expect(buildRequestUpdated('denied', 'm1').notification).toEqual({
    title: 'Request update',
    body: 'Your request was declined.',
  });
});
test('fr: request updated (NBSP before ! and :)', () => {
  expect(buildRequestUpdated('approved', 'm1', 'fr').notification).toEqual({
    title: `C’est validé${NB}!`,
    body: `Ta demande a été acceptée${NB}: dis bonjour.`,
  });
  expect(buildRequestUpdated('approved', 'm1', 'fr').notification.title).toBe('C’est validé\u00a0!');
  expect(buildRequestUpdated('approved', 'm1', 'fr').notification.body).toContain('acceptée\u00a0: dis');
  expect(buildRequestUpdated('denied', 'm1', 'fr').notification).toEqual({
    title: 'Mise à jour de ta demande',
    body: 'Ta demande a été refusée.',
  });
});

test('en: message created is user content', () => {
  const p = buildMessageCreated("L'Amélie", 'salut', 'mt1');
  expect(p.notification).toEqual({ title: "L'Amélie", body: 'salut' });
});
test('fr: message created passes sender and text through, truncated at 120', () => {
  const p = buildMessageCreated('Jean-d’Arc', 'y'.repeat(500), 'mt1', 'fr');
  expect(p.notification.title).toBe('Jean-d’Arc');
  expect(p.notification.body).toBe(`${'y'.repeat(119)}…`);
  expect(p.notification.body.length).toBe(120);
});

test('en: post-meal prompt', () => {
  expect(buildPostMealPrompt("D'Arcy").notification).toEqual({
    title: 'How was it?',
    body: "Rate your meal with D'Arcy.",
  });
  expect(postMealFallbackName()).toBe('your match');
});
test('fr: post-meal prompt (NBSP before ?)', () => {
  expect(buildPostMealPrompt('Jean-d’Arc', 'fr').notification).toEqual({
    title: `Comment c’était${NB}?`,
    body: 'Note ton repas avec Jean-d’Arc.',
  });
  expect(postMealFallbackName('fr')).toBe('l’autre personne');
});

test('en: meal reminders', () => {
  expect(buildMealReminder('24h', 'Chez Paul', meal, sameDay).notification).toEqual({
    title: 'Your meal is today',
    body: 'Chez Paul at 20:00',
  });
  expect(buildMealReminder('24h', 'Chez Paul', meal, dayBefore).notification.title).toBe(
    'Your meal is tomorrow',
  );
  expect(buildMealReminder('2h', 'Chez Paul', meal, sameDay).notification).toEqual({
    title: 'Your meal is coming up',
    body: 'Chez Paul at 20:00',
  });
});
test('fr: meal reminders, apostrophe name and 80-char truncation', () => {
  expect(buildMealReminder('24h', 'L’Ami Louis', meal, sameDay, 'm1', 'fr').notification).toEqual({
    title: 'Ton repas, c’est aujourd’hui',
    body: 'L’Ami Louis à 20:00',
  });
  expect(buildMealReminder('24h', 'X', meal, dayBefore, 'm1', 'fr').notification.title).toBe(
    'Ton repas, c’est demain',
  );
  expect(buildMealReminder('2h', 'X', meal, sameDay, 'm1', 'fr').notification.title).toBe(
    'Ton repas approche',
  );
  const long = buildMealReminder('2h', 'R'.repeat(200), meal, sameDay, 'm1', 'fr').notification;
  expect(long.body).toBe(`${'R'.repeat(79)}… à 20:00`);
  const longEn = buildMealReminder('2h', 'R'.repeat(200), meal, sameDay).notification;
  expect(longEn.body).toBe(`${'R'.repeat(79)}… at 20:00`);
});

test('en: match left', () => {
  expect(buildMatchLeft(true, 'm1').notification).toEqual({
    title: 'Your match left Convyve',
    body: 'Your meal is open again so someone else can join.',
  });
  expect(buildMatchLeft(false, 'm1', true).notification).toEqual({
    title: 'Your match withdrew',
    body: 'Your meal was cancelled.',
  });
});
test('fr: match left', () => {
  expect(buildMatchLeft(true, 'm1', false, 'fr').notification).toEqual({
    title: 'L’autre personne a quitté Convyve',
    body: 'Ton repas est de nouveau ouvert aux autres.',
  });
  expect(buildMatchLeft(false, 'm1', true, 'fr').notification).toEqual({
    title: 'L’autre personne a annulé sa participation',
    body: 'Ton repas a été annulé.',
  });
});

test('en: meal cancelled', () => {
  expect(buildMealCancelled('m1').notification).toEqual({
    title: 'Meal cancelled',
    body: 'The host left Convyve, so this meal is cancelled.',
  });
  expect(buildMealCancelled('m1', true).notification.body).toBe('The host cancelled this meal.');
});
test('fr: meal cancelled', () => {
  expect(buildMealCancelled('m1', false, 'fr').notification).toEqual({
    title: 'Repas annulé',
    body: 'L’hôte a quitté Convyve, ce repas est donc annulé.',
  });
  expect(buildMealCancelled('m1', true, 'fr').notification.body).toBe('L’hôte a annulé ce repas.');
});

test('data is language-independent for every builder', () => {
  const pairs: [() => { data: Record<string, string> }, () => { data: Record<string, string> }][] = [
    [() => buildRequestCreated('en'), () => buildRequestCreated('fr')],
    [() => buildRequestUpdated('denied', 'm1', 'en'), () => buildRequestUpdated('denied', 'm1', 'fr')],
    [() => buildMessageCreated('a', 'b', 'mt', 'en'), () => buildMessageCreated('a', 'b', 'mt', 'fr')],
    [() => buildPostMealPrompt('a', 'en'), () => buildPostMealPrompt('a', 'fr')],
    [
      () => buildMealReminder('24h', 'r', meal, sameDay, 'm1', 'en'),
      () => buildMealReminder('24h', 'r', meal, sameDay, 'm1', 'fr'),
    ],
    [() => buildMatchLeft(true, 'm1', true, 'en'), () => buildMatchLeft(true, 'm1', true, 'fr')],
    [() => buildMealCancelled('m1', true, 'en'), () => buildMealCancelled('m1', true, 'fr')],
  ];
  for (const [en, fr] of pairs) expect(fr().data).toEqual(en().data);
});

test('per-language fallbacks', () => {
  expect(restaurantFallbackName()).toBe('your restaurant');
  expect(restaurantFallbackName('fr')).toBe('ton restaurant');
  expect(messageFallbackTitle()).toBe('New message');
  expect(messageFallbackTitle('fr')).toBe('Nouveau message');
  expect(
    buildMealReminder('2h', restaurantFallbackName('fr'), meal, sameDay, 'm1', 'fr').notification.body,
  ).toBe('ton restaurant à 20:00');
  expect(buildMessageCreated(messageFallbackTitle('fr'), 'salut', 'mt', 'fr').notification.title).toBe(
    'Nouveau message',
  );
});
