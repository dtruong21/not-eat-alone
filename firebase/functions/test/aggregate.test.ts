import { nextAggregate } from '../src/lib/aggregate';

test('first rating', () => {
  expect(nextAggregate(0, 0, 5)).toEqual({ sum: 5, count: 1, avg: 5 });
});
test('running average', () => {
  expect(nextAggregate(5, 1, 3)).toEqual({ sum: 8, count: 2, avg: 4 });
});
