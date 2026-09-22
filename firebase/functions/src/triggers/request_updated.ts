import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { sendToUser } from '../lib/messaging';
import { buildRequestUpdated } from '../lib/payloads';

export const makeRequestUpdated = (database: string) =>
  onDocumentUpdated(
    { document: 'requests/{requestId}', database, region: 'europe-west1' },
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      if (!before || !after) return;
      const status = after.status as string;
      if (before.status === status) return;
      if (status !== 'approved' && status !== 'denied') return;
      const guestId = after.guestId as string | undefined;
      if (!guestId) return;
      await sendToUser(
        database,
        guestId,
        buildRequestUpdated(status, (after.mealId as string) ?? ''),
      );
    },
  );
