import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import type { Firestore, WhereFilterOp } from 'firebase-admin/firestore';
import { deletionTargets } from '../lib/deletion_plan';
import { decrementAggregate } from '../lib/aggregate';

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
    // ratings authored by the departing user: decrement each target's live aggregate,
    // then remove the rating (targets are other users, independent of this user's own doc).
    await purgeAuthoredRatings(db, t.ratingsAuthoredWhere.field, uid);
    // ratings about the departing user: no aggregate to adjust — their own aggregate
    // is removed along with the rest of their user doc below.
    await deleteWhere(db, 'ratings', t.ratingsAboutWhere.field, uid);
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

/**
 * Deletes every rating the departing user authored and, for each one whose target user is
 * still live, adjusts that user's ratingSum/ratingCount/ratingAvg via decrementAggregate.
 * Malformed docs (missing targetUid/stars) are skipped for the aggregate step but still
 * deleted; a single bad rating never blocks the rest of the cascade.
 */
async function purgeAuthoredRatings(db: Firestore, field: string, uid: string): Promise<void> {
  const snap = await db.collection('ratings').where(field, '==', uid).get();
  await Promise.all(
    snap.docs.map(async (doc) => {
      const data = doc.data() as { targetUid?: string; stars?: number };
      const targetUid = data.targetUid;
      const stars = data.stars;
      if (!targetUid || typeof stars !== 'number') {
        await doc.ref.delete();
        return;
      }
      try {
        const targetRef = db.collection('users').doc(targetUid);
        await db.runTransaction(async (txn) => {
          const targetSnap = await txn.get(targetRef);
          if (targetSnap.exists) {
            const prev = targetSnap.data() ?? {};
            const agg = decrementAggregate(
              (prev.ratingSum as number) ?? 0,
              (prev.ratingCount as number) ?? 0,
              stars,
            );
            txn.set(
              targetRef,
              { ratingSum: agg.sum, ratingCount: agg.count, ratingAvg: agg.avg },
              { merge: true },
            );
          }
          txn.delete(doc.ref);
        });
      } catch {
        // best-effort: ensure the rating doc itself is still removed even if the
        // aggregate-adjusting transaction failed for some reason.
        await doc.ref.delete().catch(() => undefined);
      }
    }),
  );
}
