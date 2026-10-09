/**
 * Best-effort per-key sliding-window limiter. In-memory, so it is per function
 * instance: it blunts a single abusive client, while `maxInstances` and the
 * Maps-project quota cap bound the worst case.
 */
export function makeRateLimiter(limit: number, windowMs: number, now: () => number = Date.now) {
  const hits = new Map<string, number[]>();
  return (key: string): boolean => {
    const t = now();
    const recent = (hits.get(key) ?? []).filter((h) => t - h < windowMs);
    if (recent.length >= limit) {
      hits.set(key, recent);
      return false;
    }
    recent.push(t);
    hits.set(key, recent);
    return true;
  };
}
