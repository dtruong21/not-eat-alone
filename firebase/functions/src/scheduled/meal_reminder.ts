import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { sendToUser } from '../lib/messaging';
import { buildMealReminder } from '../lib/payloads';
import { REMINDER_FLAG, REMINDER_KINDS, reminderWindow } from '../lib/reminders';

/**
 * Pre-meal reminders (T-24h and T-2h) to both people of a matched meal. Runs
 * every 15 minutes; each meal gets each reminder at most once (flag on the meal).
 */
export const makeMealReminder = (database: string) =>
  onSchedule(
    { schedule: 'every 15 minutes', region: 'europe-west1' },
    async () => {
      const db = getFirestore(getApp(), database);
      const now = new Date();
      for (const kind of REMINDER_KINDS) {
        const { fromMs, toMs } = reminderWindow(kind, now.getTime());
        const snap = await db.collection('meals')
          .where('status', '==', 'matched')
          .where('dateTime', '>', Timestamp.fromMillis(fromMs))
          .where('dateTime', '<=', Timestamp.fromMillis(toMs))
          .get();
        for (const doc of snap.docs) {
          const m = doc.data();
          const flag = REMINDER_FLAG[kind];
          if (m[flag] === true) continue;
          const mealAt = (m.dateTime as Timestamp).toDate();
          const payload = buildMealReminder(
            kind,
            (m.restaurant?.name as string | undefined) ?? 'your restaurant',
            mealAt,
            now,
            doc.id,
          );
          const recipients = [m.hostId, m.guestId].filter(
            (u): u is string => typeof u === 'string' && u !== '',
          );
          // Isolate each meal (one failure must not starve the batch). The flag is
          // set after the attempt: a lost reminder beats a duplicate one.
          try {
            const results = await Promise.allSettled(
              recipients.map((uid) => sendToUser(database, uid, payload)),
            );
            results.forEach((r) => {
              if (r.status === 'rejected') {
                console.error(`[mealReminder ${kind}] send failed for meal ${doc.id}`, r.reason);
              }
            });
            await doc.ref.set({ [flag]: true }, { merge: true });
          } catch (err) {
            console.error(`[mealReminder ${kind}] failed for meal ${doc.id}`, err);
          }
        }
      }
    },
  );
