import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { PushPayload } from './payloads';
import { tokensToPrune, SendResponse } from './prune';

export async function sendToUser(
  databaseId: string,
  uid: string,
  payload: PushPayload,
): Promise<void> {
  const db = getFirestore(getApp(), databaseId);
  const snap = await db.collection('users').doc(uid).collection('fcmTokens').get();
  const tokens = snap.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: payload.notification,
    data: payload.data,
  });

  const responses: SendResponse[] = res.responses.map((r) => ({
    success: r.success,
    error: r.error ? { code: r.error.code } : undefined,
  }));
  const prune = tokensToPrune(tokens, responses);
  await Promise.all(
    prune.map((t) => db.collection('users').doc(uid).collection('fcmTokens').doc(t).delete()),
  );
}
