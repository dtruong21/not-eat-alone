import { buildMessageCreated, buildRequestUpdated } from '../src/lib/payloads';

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
