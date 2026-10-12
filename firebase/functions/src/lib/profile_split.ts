/**
 * One-off migration helper: splits a legacy `users/{uid}` doc (which mixed public and
 * private fields) into the new PUBLIC `profiles/{uid}` doc plus the list of public
 * fields to delete from the now-PRIVATE `users/{uid}` doc.
 */

const PUBLIC_FIELDS = [
  'displayName', 'photoUrls', 'bio', 'ratingSum', 'ratingCount', 'ratingAvg',
] as const;

/** Whole years between `dobMs` and `nowMs` (UTC calendar). */
export function ageFromDobMs(dobMs: number, nowMs: number): number {
  const dob = new Date(dobMs);
  const now = new Date(nowMs);
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const hadBirthday =
    now.getUTCMonth() > dob.getUTCMonth() ||
    (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() >= dob.getUTCDate());
  if (!hadBirthday) age -= 1;
  return age;
}

export interface LegacySplit {
  profile: Record<string, unknown>;
  /** Fields to remove from `users/{uid}` (only those actually present). */
  deleteFromUser: string[];
}

export function splitLegacyUser(
  uid: string,
  data: Record<string, unknown>,
  dobMs: number | null,
  nowMs: number,
): LegacySplit {
  const profile: Record<string, unknown> = { uid };
  const deleteFromUser: string[] = [];
  for (const f of PUBLIC_FIELDS) {
    if (f in data) {
      if (data[f] !== undefined && data[f] !== null) profile[f] = data[f];
      deleteFromUser.push(f);
    }
  }
  if (dobMs !== null) {
    const age = ageFromDobMs(dobMs, nowMs);
    // The rules only accept 18..120; legacy test accounts outside it get no public age.
    if (age >= 18 && age <= 120) profile.age = age;
  }
  return { profile, deleteFromUser };
}
