import { buildMessageCreated, buildRequestUpdated, buildPostMealPrompt } from '../src/lib/payloads';

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
