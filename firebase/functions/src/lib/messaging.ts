import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { PushPayload } from './payloads';
import { PushLang, groupTokensByLang } from './push_lang';
import { tokensToPrune, SendResponse } from './prune';

export interface MulticastMessage {
  tokens: string[];
  notification: PushPayload['notification'];
  data: PushPayload['data'];
}

/** Injectable I/O so the grouping/pruning logic runs under jest without Firebase. */
export interface SendDeps {
  readTokens(uid: string): Promise<{ id: string; data(): Record<string, unknown> }[]>;
  send(msg: MulticastMessage): Promise<{ responses: { success: boolean; error?: { code: string } }[] }>;
  deleteToken(uid: string, token: string): Promise<void>;
}

export type PayloadOrBuilder = PushPayload | ((lang: PushLang) => PushPayload);

export async function sendToUserWith(
  deps: SendDeps,
  uid: string,
  payload: PayloadOrBuilder,
): Promise<void> {
  const docs = await deps.readTokens(uid);
  if (docs.length === 0) return;

  // A plain payload is language-agnostic: one multicast to every token, as before.
  const groups: [PushPayload, string[]][] =
    typeof payload === 'function'
      ? [...groupTokensByLang(docs)].map(([lang, tokens]) => [payload(lang), tokens])
      : [[payload, docs.map((d) => d.id)]];

  // Attempt every group even if one throws; surface the first error afterwards.
  const results = await Promise.allSettled(
    groups.map(async ([p, tokens]) => {
      const res = await deps.send({ tokens, notification: p.notification, data: p.data });
      const responses: SendResponse[] = res.responses.map((r) => ({
        success: r.success,
        error: r.error ? { code: r.error.code } : undefined,
      }));
      await Promise.all(tokensToPrune(tokens, responses).map((t) => deps.deleteToken(uid, t)));
    }),
  );
  const failures = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
  failures.forEach((f) => {
    // Error code only: never tokens or message text.
    const code = (f.reason as { code?: unknown } | null)?.code;
    console.error(`[sendToUser] language group failed (${typeof code === 'string' ? code : 'unknown'})`);
  });
  if (failures.length > 0) throw failures[0].reason;
}

export async function sendToUser(
  databaseId: string,
  uid: string,
  payload: PayloadOrBuilder,
): Promise<void> {
  const db = getFirestore(getApp(), databaseId);
  const tokens = (u: string) => db.collection('users').doc(u).collection('fcmTokens');
  return sendToUserWith(
    {
      readTokens: async (u) => (await tokens(u).get()).docs,
      send: (msg) => getMessaging().sendEachForMulticast(msg),
      deleteToken: async (u, t) => {
        await tokens(u).doc(t).delete();
      },
    },
    uid,
    payload,
  );
}
