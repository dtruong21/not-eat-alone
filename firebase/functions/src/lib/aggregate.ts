export function nextAggregate(prevSum: number, prevCount: number, stars: number): {
  sum: number; count: number; avg: number;
} {
  const sum = prevSum + stars;
  const count = prevCount + 1;
  return { sum, count, avg: sum / count };
}

/** Inverse of nextAggregate — removes one rating's contribution. Never goes negative. */
export function decrementAggregate(prevSum: number, prevCount: number, stars: number): {
  sum: number; count: number; avg: number;
} {
  const sum = Math.max(0, prevSum - stars);
  const count = Math.max(0, prevCount - 1);
  return { sum, count, avg: count > 0 ? sum / count : 0 };
}
