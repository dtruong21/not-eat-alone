import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import type { Firestore, WhereFilterOp } from 'firebase-admin/firestore';
import { deletionTargets } from '../lib/deletion_plan';
import { decrementAggregateBy } from '../lib/aggregate';
import { planGuestLeft, shouldNotifyGuestOfHostLeaving } from '../lib/matched_meals';
import { deleteMatchTree } from '../lib/match_tree';
import { sendToUser } from '../lib/messaging';
import { buildMatchLeft, buildMealCancelled } from '../lib/payloads';

export const makeDeleteAccount = () =>
  onCall({ region: 'europe-west1', enforceAppCheck: true }, async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
    const databaseId = (req.data?.databaseId as string | undefined) ?? '(default)';
    // Only the two databases this project has; never an arbitrary client-supplied name.
    if (databaseId !== '(default)' && databaseId !== 'stage') {
      throw new HttpsError('invalid-argument', 'Unknown database.');
    }
    const t = deletionTargets(uid);
    const db = getFirestore(getApp(), databaseId);

    // Matched meals first: the other person must not be left with a ghost match.
    await releaseMatchedMeals(db, databaseId, uid);

    // matches (+ subcollections) then requests, meals, blocks, user doc.
    // Union three queries: the `participants` array-contains (current) plus
    // hostId/guestId equality — legacy matches created before the participants
    // array existed have no `participants` field and would otherwise be missed,
    // leaving orphaned matches + messages after a deletion.
    const matchDocs = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
    const matchQueries = [
      db.collection('matches').where(t.matchesWhere.field, 'array-contains', uid),
      db.collection('matches').where('hostId', '==', uid),
      db.collection('matches').where('guestId', '==', uid),
    ];
    for (const q of matchQueries) {
      const s = await q.get();
      for (const d of s.docs) matchDocs.set(d.id, d);
    }
    for (const m of matchDocs.values()) await deleteMatchTree(m.ref);
    // ratings authored by the departing user: decrement each target's live aggregate,
    // then remove the rating (targets are other users, independent of this user's own doc).
    await purgeAuthoredRatings(db, t.ratingsAuthoredWhere.field, uid);
    // ratings about the departing user: no aggregate to adjust — their own aggregate
    // is removed along with their profile doc below.
    await deleteWhere(db, 'ratings', t.ratingsAboutWhere.field, uid);
    await deleteWhere(db, 'meals', t.mealsWhere.field, uid);
    for (const q of t.requestsWhere) await deleteWhere(db, 'requests', q.field, uid);
    await deleteWhere(db, 'blocks', t.blocksWhere.field, uid, 'array-contains');
    // user doc + fcmTokens
    const tokens = await db.collection('users').doc(uid).collection('fcmTokens').get();
    await Promise.all(tokens.docs.map((d) => d.ref.delete()));
    await db.collection('users').doc(uid).delete();
    await db.collection('profiles').doc(uid).delete();

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

interface AuthoredRatingsGroup {
  starsSum: number;
  count: number;
  refs: FirebaseFirestore.DocumentReference[];
}

/**
 * Deletes every rating the departing user authored and, per DISTINCT target user, adjusts
 * that user's ratingSum/ratingCount/ratingAvg via decrementAggregateBy in a SINGLE
 * transaction — decrementing by the composed total (sum of stars + count of ratings) this
 * user gave that target. Grouping by target (rather than one transaction per rating) avoids
 * firing N concurrent transactions on the same users/{targetUid} doc when the departing user
 * rated the same target across multiple matches, which would otherwise contend and could
 * exhaust the Firestore transaction retry budget.
 *
 * Malformed docs (missing targetUid/stars) are skipped for the aggregate step but still
 * deleted. A failure adjusting/deleting one target's group is logged (so aggregate drift is
 * detectable/reconcilable) and does not abort the rest of the cascade.
 */
async function purgeAuthoredRatings(db: Firestore, field: string, uid: string): Promise<void> {
  const snap = await db.collection('ratings').where(field, '==', uid).get();

  const groups = new Map<string, AuthoredRatingsGroup>();
  const malformedRefs: FirebaseFirestore.DocumentReference[] = [];
  for (const doc of snap.docs) {
    const data = doc.data() as { targetUid?: string; stars?: number };
    const targetUid = data.targetUid;
    const stars = data.stars;
    if (!targetUid || typeof stars !== 'number') {
      malformedRefs.push(doc.ref);
      continue;
    }
    const group = groups.get(targetUid) ?? { starsSum: 0, count: 0, refs: [] };
    group.starsSum += stars;
    group.count += 1;
    group.refs.push(doc.ref);
    groups.set(targetUid, group);
  }

  await Promise.all(
    malformedRefs.map((ref) =>
      ref.delete().catch((err) => {
        console.error(`[deleteAccount] malformed rating delete failed for ${ref.path}`, err);
      }),
    ),
  );

  await Promise.all(
    Array.from(groups.entries()).map(async ([targetUid, group]) => {
      try {
        const targetRef = db.collection('profiles').doc(targetUid);
        await db.runTransaction(async (txn) => {
          const targetSnap = await txn.get(targetRef);
          if (targetSnap.exists) {
            const prev = targetSnap.data() ?? {};
            const agg = decrementAggregateBy(
              (prev.ratingSum as number) ?? 0,
              (prev.ratingCount as number) ?? 0,
              group.starsSum,
              group.count,
            );
            txn.set(
              targetRef,
              { ratingSum: agg.sum, ratingCount: agg.count, ratingAvg: agg.avg },
              { merge: true },
            );
          }
          for (const ref of group.refs) txn.delete(ref);
        });
      } catch (err) {
        console.error(
          `[deleteAccount] rating aggregate/delete failed for target ${targetUid}`,
          err,
        );
        // best-effort: ensure the rating docs are still removed even if the
        // aggregate-adjusting transaction failed, so orphaned ratings don't linger —
        // the aggregate itself may now be stale and needs manual reconciliation.
        await Promise.all(
          group.refs.map((ref) =>
            ref.delete().catch((delErr) => {
              console.error(`[deleteAccount] fallback rating delete failed for ${ref.path}`, delErr);
            }),
          ),
        );
      }
    }),
  );
}

/**
 * Meals still matched with the departing user:
 *  - as GUEST: the host's meal reopens (or is cancelled if it already happened) and the host
 *    is told, so Discover lists it again, reminders restart and nobody is asked to rate a ghost;
 *  - as HOST: their meals are deleted below, so a matched guest of a future meal is told.
 * Push failures never block the deletion.
 */
export async function releaseMatchedMeals(db: Firestore, databaseId: string, uid: string): Promise<void> {
  const now = Date.now();

  const asGuest = await db
    .collection('meals')
    .where('guestId', '==', uid)
    .where('status', '==', 'matched')
    .get();
  for (const doc of asGuest.docs) {
    const m = doc.data();
    const at = (m.dateTime as Timestamp | undefined)?.toMillis() ?? 0;
    const plan = planGuestLeft(at, now);
    await doc.ref.update({
      ...plan.set,
      ...Object.fromEntries(plan.deleteFields.map((f) => [f, FieldValue.delete()])),
    });
    const hostId = m.hostId as string | undefined;
    if (hostId) {
      try {
        await sendToUser(databaseId, hostId, (lang) =>
          buildMatchLeft(plan.reopened, doc.id, false, lang),
        );
      } catch (err) {
        console.error(`[deleteAccount] notify host failed for meal ${doc.id}`, err);
      }
    }
  }

  const asHost = await db
    .collection('meals')
    .where('hostId', '==', uid)
    .where('status', '==', 'matched')
    .get();
  for (const doc of asHost.docs) {
    const m = doc.data();
    const at = (m.dateTime as Timestamp | undefined)?.toMillis() ?? 0;
    const guestId = m.guestId as string | undefined;
    if (guestId && shouldNotifyGuestOfHostLeaving(at, now)) {
      try {
        await sendToUser(databaseId, guestId, (lang) => buildMealCancelled(doc.id, false, lang));
      } catch (err) {
        console.error(`[deleteAccount] notify guest failed for meal ${doc.id}`, err);
      }
    }
  }
}
