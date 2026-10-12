import type { DocumentReference } from 'firebase-admin/firestore';

/** Deletes a match document together with its `messages` and `reads` subcollections. */
export async function deleteMatchTree(matchRef: DocumentReference): Promise<void> {
  for (const sub of ['messages', 'reads']) {
    const subSnap = await matchRef.collection(sub).get();
    await Promise.all(subSnap.docs.map((d) => d.ref.delete()));
  }
  await matchRef.delete();
}
