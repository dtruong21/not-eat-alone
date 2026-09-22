import { tokensToPrune } from '../src/lib/prune';

test('prunes only not-registered / invalid tokens', () => {
  const tokens = ['a', 'b', 'c'];
  const responses = [
    { success: true },
    { success: false, error: { code: 'messaging/registration-token-not-registered' } },
    { success: false, error: { code: 'messaging/internal-error' } },
  ];
  expect(tokensToPrune(tokens, responses)).toEqual(['b']);
});
