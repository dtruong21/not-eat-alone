import { deletionTargets } from '../src/lib/deletion_plan';

test('deletion targets cover the user data surfaces', () => {
  const t = deletionTargets('u1');
  // returns a structured description the executor iterates — assert the shapes.
  expect(t.userDoc).toBe('users/u1');
  expect(t.mealsWhere).toEqual({ field: 'hostId', op: '==', value: 'u1' });
  expect(t.requestsWhere.map((q) => q.field)).toEqual(['guestId', 'hostId']);
  expect(t.matchesWhere).toEqual({ field: 'participants', op: 'array-contains', value: 'u1' });
  expect(t.blocksWhere).toEqual({ field: 'pair', op: 'array-contains', value: 'u1' });
  expect(t.storagePrefixFor('stage')).toBe('stage/users/u1/');
  expect(t.storagePrefixFor('(default)')).toBe('prod/users/u1/');
});
