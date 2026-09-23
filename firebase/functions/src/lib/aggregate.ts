export function nextAggregate(prevSum: number, prevCount: number, stars: number): {
  sum: number; count: number; avg: number;
} {
  const sum = prevSum + stars;
  const count = prevCount + 1;
  return { sum, count, avg: sum / count };
}
