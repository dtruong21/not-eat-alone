import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import type { Firestore, WhereFilterOp } from 'firebase-admin/firestore';
import { deletionTargets } from '../lib/deletion_plan';

export const makeDeleteAccount = () =>
  onCall({ region: 'europe-west1' }, async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
    const databaseId = (req.data?.databaseId as string | undefined) ?? '(default)';
    const t = deletionTargets(uid);
    const db = getFirestore(getApp(), databaseId);

    // matches (+ subcollections) then requests, meals, blocks, user doc.
    const matchSnap = await db
      .collection('matches')
      .where(t.matchesWhere.field, 'array-contains', uid)
      .get();
    for (const m of matchSnap.docs) {
      for (const sub of ['messages', 'reads']) {
        const subSnap = await m.ref.collection(sub).get();
        await Promise.all(subSnap.docs.map((d) => d.ref.delete()));
      }
      await m.ref.delete();
    }
    await deleteWhere(db, 'meals', t.mealsWhere.field, uid);
    for (const q of t.requestsWhere) await deleteWhere(db, 'requests', q.field, uid);
    await deleteWhere(db, 'blocks', t.blocksWhere.field, uid, 'array-contains');
    // user doc + fcmTokens
    const tokens = await db.collection('users').doc(uid).collection('fcmTokens').get();
    await Promise.all(tokens.docs.map((d) => d.ref.delete()));
    await db.collection('users').doc(uid).delete();

    // storage
    try {
      await getStorage().bucket().deleteFiles({ prefix: t.storagePrefixFor(databaseId) });
    } catch {
      /* best-effort */
    }

    await getAuth().deleteUser(uid);
    return { ok: true };
  });

async function deleteWhere(
  db: Firestore,
  coll: string,
  field: string,
  value: string,
  op: WhereFilterOp = '==',
): Promise<void> {
  const snap = await db.collection(coll).where(field, op, value).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}
