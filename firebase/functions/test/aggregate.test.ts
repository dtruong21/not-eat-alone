import { nextAggregate, decrementAggregate } from '../src/lib/aggregate';

test('first rating', () => {
  expect(nextAggregate(0, 0, 5)).toEqual({ sum: 5, count: 1, avg: 5 });
});
test('running average', () => {
  expect(nextAggregate(5, 1, 3)).toEqual({ sum: 8, count: 2, avg: 4 });
});

test('decrement to a smaller average', () => {
  expect(decrementAggregate(8, 2, 3)).toEqual({ sum: 5, count: 1, avg: 5 });
});
test('decrement the last rating', () => {
  expect(decrementAggregate(5, 1, 5)).toEqual({ sum: 0, count: 0, avg: 0 });
});
test('decrement underflow guard never goes negative', () => {
  expect(decrementAggregate(0, 0, 5)).toEqual({ sum: 0, count: 0, avg: 0 });
});
