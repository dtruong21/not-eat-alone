export function nextAggregate(prevSum: number, prevCount: number, stars: number): {
  sum: number; count: number; avg: number;
} {
  const sum = prevSum + stars;
  const count = prevCount + 1;
  return { sum, count, avg: sum / count };
}

/**
 * Inverse of nextAggregate, generalized to remove several ratings' contribution at once
 * (e.g. all ratings one user authored for the same target). Never goes negative.
 */
export function decrementAggregateBy(
  prevSum: number,
  prevCount: number,
  starsSum: number,
  ratingsCount: number,
): { sum: number; count: number; avg: number } {
  const sum = Math.max(0, prevSum - starsSum);
  const count = Math.max(0, prevCount - ratingsCount);
  return { sum, count, avg: count > 0 ? sum / count : 0 };
}

/** Inverse of nextAggregate — removes one rating's contribution. Never goes negative. */
export function decrementAggregate(prevSum: number, prevCount: number, stars: number): {
  sum: number; count: number; avg: number;
} {
  return decrementAggregateBy(prevSum, prevCount, stars, 1);
}
