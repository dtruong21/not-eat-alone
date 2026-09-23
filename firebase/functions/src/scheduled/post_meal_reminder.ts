import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { sendToUser } from '../lib/messaging';
import { buildPostMealPrompt } from '../lib/payloads';

export const makePostMealReminder = (database: string) =>
  onSchedule(
    { schedule: 'every 60 minutes', region: 'europe-west1' },
    async () => {
      const db = getFirestore(getApp(), database);
      const now = Timestamp.now();
      const snap = await db.collection('meals')
        .where('status', '==', 'matched')
        .where('dateTime', '<=', now)
        .get();
      for (const doc of snap.docs) {
        const m = doc.data();
        if (m.postMealNotified === true) continue;
        const hostId = m.hostId as string | undefined;
        const guestId = m.guestId as string | undefined;
        const matchId = doc.id;
        const payloadFor = (name: string) => {
          const p = buildPostMealPrompt(name);
          p.data.matchId = matchId;
          return p;
        };
        if (hostId) await sendToUser(database, hostId, payloadFor('your match'));
        if (guestId) await sendToUser(database, guestId, payloadFor('your match'));
        await doc.ref.set({ status: 'completed', postMealNotified: true }, { merge: true });
      }
    },
  );
