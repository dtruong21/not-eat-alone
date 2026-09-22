import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { sendToUser } from '../lib/messaging';
import { buildMessageCreated } from '../lib/payloads';

export const makeMessageCreated = (database: string) =>
  onDocumentCreated(
    { document: 'matches/{matchId}/messages/{messageId}', database, region: 'europe-west1' },
    async (event) => {
      const msg = event.data?.data();
      const matchId = event.params.matchId;
      const senderId = msg?.senderId as string | undefined;
      const text = (msg?.text as string) ?? '';
      if (!senderId) return;

      const db = getFirestore(getApp(), database);
      const matchSnap = await db.collection('matches').doc(matchId).get();
      const participants = (matchSnap.data()?.participants as string[]) ?? [];
      const recipient = participants.find((p) => p !== senderId);
      if (!recipient) return;

      const senderSnap = await db.collection('users').doc(senderId).get();
      const senderName = (senderSnap.data()?.displayName as string) ?? 'New message';

      await sendToUser(database, recipient, buildMessageCreated(senderName, text, matchId));
    },
  );
