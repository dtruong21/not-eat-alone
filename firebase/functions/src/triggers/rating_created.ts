import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { nextAggregate } from '../lib/aggregate';

export const makeRatingCreated = (database: string) =>
  onDocumentCreated(
    { document: 'ratings/{ratingId}', database, region: 'europe-west1' },
    async (event) => {
      const data = event.data?.data();
      const targetUid = data?.targetUid as string | undefined;
      const stars = data?.stars as number | undefined;
      if (!targetUid || typeof stars !== 'number') return;
      const db = getFirestore(getApp(), database);
      const userRef = db.collection('users').doc(targetUid);
      await db.runTransaction(async (txn) => {
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
      });
    },
  );
