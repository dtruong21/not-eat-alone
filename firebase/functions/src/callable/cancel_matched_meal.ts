import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { decideCancel } from '../lib/cancel_meal';
import type { CancelDecision } from '../lib/cancel_meal';
import { deleteMatchTree } from '../lib/match_tree';
import { sendToUser } from '../lib/messaging';
import { buildMatchLeft, buildMealCancelled } from '../lib/payloads';

/**
 * "Can't make it": the host cancels, or the guest withdraws from, a MATCHED, future meal.
 * Server-side because clients cannot change a matched meal (rules) and the other person must
 * be told. Host: meal -> `cancelled`, chat closed, guest notified. Guest: meal reopens (fresh
 * reminders), the guest's request and the chat are removed, host notified.
 */
export const makeCancelMatchedMeal = () =>
  onCall({ region: 'europe-west1', enforceAppCheck: true }, async (req) => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
    const mealId = req.data?.mealId;
    if (typeof mealId !== 'string' || mealId === '' || mealId.length > 128) {
      throw new HttpsError('invalid-argument', 'mealId is required.');
    }
    const databaseId = (req.data?.databaseId as string | undefined) ?? '(default)';
    if (databaseId !== '(default)' && databaseId !== 'stage') {
      throw new HttpsError('invalid-argument', 'Unknown database.');
    }

    const decision = await applyCancel(
      getFirestore(getApp(), databaseId),
      databaseId,
      uid,
      mealId,
    );
    if (!decision.ok) throw new HttpsError(decision.code, decision.message);
    return { ok: true, role: decision.role };
  });

/** Decides and applies the cancellation; exported so it can be exercised against the emulator. */
export async function applyCancel(
  db: Firestore,
  databaseId: string,
  uid: string,
  mealId: string,
): Promise<CancelDecision> {
  const mealRef = db.collection('meals').doc(mealId);

  // Decide and write in one transaction so a double tap or a concurrent leave can't apply
  // twice; side effects (chat removal, push) happen only for the winner.
  const decision = await db.runTransaction(async (txn) => {
    const snap = await txn.get(mealRef);
    const data = snap.data();
    const d = decideCancel(
      snap.exists && data
        ? {
            status: data.status,
            hostId: data.hostId,
            guestId: data.guestId,
            dateTimeMs: (data.dateTime as Timestamp | undefined)?.toMillis() ?? 0,
          }
        : null,
      uid,
      Date.now(),
    );
    if (!d.ok) return d;
    txn.update(mealRef, {
      ...d.set,
      ...Object.fromEntries(d.deleteFields.map((f) => [f, FieldValue.delete()])),
    });
    if (d.removeGuestRequest) {
      txn.delete(db.collection('requests').doc(`${mealId}_${uid}`));
    }
    return d;
  });
  if (!decision.ok) return decision;

  // The chat is gone either way (matches are 1:1 with meals: matchId == mealId).
  await deleteMatchTree(db.collection('matches').doc(mealId));

  try {
    await sendToUser(
      databaseId,
      decision.notifyUid,
      decision.role === 'host' ? buildMealCancelled(mealId, true) : buildMatchLeft(true, mealId, true),
    );
  } catch (err) {
    console.error(`[cancelMatchedMeal] notify failed for meal ${mealId}`, err);
  }
  return decision;
}
