export type WhereOp = '==' | 'array-contains';

export interface WhereQuery {
  field: string;
  op: WhereOp;
  value: string;
}

export interface DeletionTargets {
  userDoc: string;
  mealsWhere: WhereQuery;
  requestsWhere: WhereQuery[];
  matchesWhere: WhereQuery;
  blocksWhere: WhereQuery;
  ratingsAuthoredWhere: WhereQuery;
  ratingsAboutWhere: WhereQuery;
  storagePrefixFor: (databaseId: string) => string;
}

/** Maps a Firestore databaseId to the Storage flavor prefix: 'stage' -> 'stage', else 'prod'. */
export function storagePrefixFor(databaseId: string): string {
  return databaseId === 'stage' ? 'stage' : 'prod';
}

/** Pure description of the Firestore/Storage surfaces to delete for a given uid. */
export function deletionTargets(uid: string): DeletionTargets {
  return {
    userDoc: `users/${uid}`,
    mealsWhere: { field: 'hostId', op: '==', value: uid },
    requestsWhere: [
      { field: 'guestId', op: '==', value: uid },
      { field: 'hostId', op: '==', value: uid },
    ],
    matchesWhere: { field: 'participants', op: 'array-contains', value: uid },
    blocksWhere: { field: 'pair', op: 'array-contains', value: uid },
    ratingsAuthoredWhere: { field: 'raterUid', op: '==', value: uid },
    ratingsAboutWhere: { field: 'targetUid', op: '==', value: uid },
    storagePrefixFor: (databaseId: string) => `${storagePrefixFor(databaseId)}/users/${uid}/`,
  };
}
