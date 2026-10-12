import { ageFromDobMs, splitLegacyUser } from '../src/lib/profile_split';

const NOW = Date.UTC(2026, 9, 10); // 2026-10-10

describe('ageFromDobMs', () => {
  test('before and after the birthday', () => {
    expect(ageFromDobMs(Date.UTC(2000, 9, 11), NOW)).toBe(25);
    expect(ageFromDobMs(Date.UTC(2000, 9, 10), NOW)).toBe(26);
    expect(ageFromDobMs(Date.UTC(2000, 0, 1), NOW)).toBe(26);
  });
});

describe('splitLegacyUser', () => {
  const legacy = {
    uid: 'u1',
    dob: 'ignored-by-split',
    ageVerified: true,
    gender: 'woman',
    displayName: 'Ada',
    photoUrls: ['a'],
    bio: 'hi',
    ratingSum: 9,
    ratingCount: 2,
    ratingAvg: 4.5,
  };

  test('moves public fields to the profile and never copies dob/gender', () => {
    const { profile, deleteFromUser } = splitLegacyUser('u1', legacy, Date.UTC(2000, 0, 1), NOW);
    expect(profile).toEqual({
      uid: 'u1', displayName: 'Ada', photoUrls: ['a'], bio: 'hi',
      ratingSum: 9, ratingCount: 2, ratingAvg: 4.5, age: 26,
    });
    expect(profile).not.toHaveProperty('dob');
    expect(profile).not.toHaveProperty('gender');
    expect(deleteFromUser.sort()).toEqual(
      ['bio', 'displayName', 'photoUrls', 'ratingAvg', 'ratingCount', 'ratingSum'],
    );
  });

  test('only touches fields that exist; no public age outside 18..120', () => {
    const { profile, deleteFromUser } = splitLegacyUser('u2', { uid: 'u2' }, Date.UTC(2015, 0, 1), NOW);
    expect(profile).toEqual({ uid: 'u2' });
    expect(deleteFromUser).toEqual([]);
  });

  test('is idempotent on an already-clean user doc', () => {
    const first = splitLegacyUser('u3', { uid: 'u3', ageVerified: true }, Date.UTC(1990, 0, 1), NOW);
    expect(first.deleteFromUser).toEqual([]);
    expect(first.profile).toEqual({ uid: 'u3', age: 36 });
  });
});
