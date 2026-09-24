import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { nextAggregate } from '../lib/aggregate';

export const makeRatingCreated = (database: string) =>
  onDocumentCreated(
    { document: 'ratings/{ratingId}', database, region: 'europe-west1' },
    async (event) => {
      const snapshot = event.data;
      const data = snapshot?.data();
      const targetUid = data?.targetUid as string | undefined;
      const stars = data?.stars as number | undefined;
      if (!snapshot || !targetUid || typeof stars !== 'number') return;
      const db = getFirestore(getApp(), database);
      const userRef = db.collection('users').doc(targetUid);
      const ratingRef = snapshot.ref;
      await db.runTransaction(async (txn) => {
        // Firestore triggers are at-least-once: guard against a duplicate
        // delivery double-counting this rating by marking the rating doc
        // `aggregated` inside the same transaction that applies the increment.
        const ratingSnap = await txn.get(ratingRef);
        if (ratingSnap.get('aggregated') === true) return;
        const snap = await txn.get(userRef);
        const prev = snap.data() ?? {};
        const agg = nextAggregate(
          (prev.ratingSum as number) ?? 0,
          (prev.ratingCount as number) ?? 0,
          stars,
        );
        txn.set(userRef, {
          ratingSum: agg.sum, ratingCount: agg.count, ratingAvg: agg.avg,
        }, { merge: true });
        txn.set(ratingRef, { aggregated: true }, { merge: true });
      });
    },
  );
