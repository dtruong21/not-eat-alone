import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { sendToUser } from '../lib/messaging';
import { buildPostMealPrompt, postMealFallbackName } from '../lib/payloads';
import { PushLang } from '../lib/push_lang';

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
        const payloadFor = (lang: PushLang) => {
          const p = buildPostMealPrompt(postMealFallbackName(lang), lang);
          p.data.matchId = matchId;
          return p;
        };
        // Isolate each meal: one meal's messaging/write failure must not abort
        // the whole scheduled run and starve the remaining meals in this batch.
        try {
          if (hostId) await sendToUser(database, hostId, payloadFor);
          if (guestId) await sendToUser(database, guestId, payloadFor);
          await doc.ref.set({ status: 'completed', postMealNotified: true }, { merge: true });
        } catch (err) {
          console.error(`[postMealReminder] failed for meal ${matchId}`, err);
        }
      }
    },
  );
