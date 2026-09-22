import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { sendToUser } from '../lib/messaging';
import { buildRequestCreated } from '../lib/payloads';

export const makeRequestCreated = (database: string) =>
  onDocumentCreated(
    { document: 'requests/{requestId}', database, region: 'europe-west1' },
    async (event) => {
      const data = event.data?.data();
      const hostId = data?.hostId as string | undefined;
      if (!hostId) return;
      await sendToUser(database, hostId, buildRequestCreated());
    },
  );
