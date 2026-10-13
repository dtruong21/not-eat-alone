import { groupTokensByLang, normalizePushLang } from '../src/lib/push_lang';
import { SendDeps, sendToUserWith } from '../src/lib/messaging';
import { PushPayload } from '../src/lib/payloads';

describe('normalizePushLang', () => {
  test.each([
    ['fr', 'fr'],
    ['en', 'en'],
    [undefined, 'en'],
    [null, 'en'],
    ['FR', 'en'],
    ['fr-FR', 'en'],
    [42, 'en'],
  ])('%p -> %s', (v, want) => expect(normalizePushLang(v)).toBe(want));
});

const doc = (id: string, lang?: unknown) => ({ id, data: () => (lang === undefined ? {} : { lang }) });

describe('groupTokensByLang', () => {
  test('mixed, missing lang is en', () => {
    const g = groupTokensByLang([doc('a', 'fr'), doc('b'), doc('c', 'en'), doc('d', 'fr'), doc('e', 'de')]);
    expect(g.get('fr')).toEqual(['a', 'd']);
    expect(g.get('en')).toEqual(['b', 'c', 'e']);
  });
  test('all fr has no en group', () => {
    const g = groupTokensByLang([doc('a', 'fr'), doc('b', 'fr')]);
    expect([...g.keys()]).toEqual(['fr']);
  });
  test('empty', () => expect(groupTokensByLang([]).size).toBe(0));
});

describe('sendToUserWith', () => {
  const byLang = (lang: string): PushPayload => ({
    notification: { title: `t-${lang}`, body: `b-${lang}` },
    data: { type: 'x' },
  });
  const ok = { success: true };

  function deps(
    docs: ReturnType<typeof doc>[],
    send: SendDeps['send'],
  ): SendDeps & { deleted: string[] } {
    const deleted: string[] = [];
    return {
      deleted,
      readTokens: async () => docs,
      send,
      deleteToken: async (_u, t) => {
        deleted.push(t);
      },
    };
  }

  test('one multicast per language with that language payload', async () => {
    const sent: { tokens: string[]; title: string }[] = [];
    const d = deps([doc('a', 'fr'), doc('b'), doc('c', 'fr')], async (m) => {
      sent.push({ tokens: m.tokens, title: m.notification.title });
      return { responses: m.tokens.map(() => ok) };
    });
    await sendToUserWith(d, 'u1', byLang);
    expect(sent).toHaveLength(2);
    expect(sent).toContainEqual({ tokens: ['a', 'c'], title: 't-fr' });
    expect(sent).toContainEqual({ tokens: ['b'], title: 't-en' });
    expect(d.deleted).toEqual([]);
  });

  test('plain payload sends all tokens together', async () => {
    const sent: string[][] = [];
    const d = deps([doc('a', 'fr'), doc('b')], async (m) => {
      sent.push(m.tokens);
      return { responses: m.tokens.map(() => ok) };
    });
    await sendToUserWith(d, 'u1', byLang('en'));
    expect(sent).toEqual([['a', 'b']]);
  });

  test('prunes invalid tokens across groups', async () => {
    const bad = { success: false, error: { code: 'messaging/registration-token-not-registered' } };
    const d = deps([doc('a', 'fr'), doc('b'), doc('c')], async (m) => ({
      responses: m.tokens.map((t) => (t === 'a' || t === 'c' ? bad : ok)),
    }));
    await sendToUserWith(d, 'u1', byLang);
    expect(d.deleted.sort()).toEqual(['a', 'c']);
  });

  test('zero tokens sends nothing', async () => {
    const send = jest.fn();
    await sendToUserWith(deps([], send), 'u1', byLang);
    expect(send).not.toHaveBeenCalled();
  });

  test('a throwing group does not stop the other, then rethrows without logging secrets', async () => {
    const err = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    const sent: string[] = [];
    const d = deps([doc('secret-fr-token', 'fr'), doc('b')], async (m) => {
      if (m.notification.title === 't-fr') throw Object.assign(new Error('boom t-fr'), { code: 'messaging/internal' });
      sent.push(m.tokens[0]);
      return { responses: m.tokens.map(() => ok) };
    });
    await expect(sendToUserWith(d, 'u1', byLang)).rejects.toThrow('boom');
    expect(sent).toEqual(['b']);
    const logged = JSON.stringify(err.mock.calls);
    expect(logged).toContain('messaging/internal');
    expect(logged).not.toContain('secret-fr-token');
    expect(logged).not.toContain('t-fr');
    err.mockRestore();
  });
});
