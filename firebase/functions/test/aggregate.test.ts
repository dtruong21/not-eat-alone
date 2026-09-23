import { nextAggregate, decrementAggregate, decrementAggregateBy } from '../src/lib/aggregate';

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

test('decrementAggregateBy removes several ratings at once', () => {
  expect(decrementAggregateBy(20, 5, 7, 2)).toEqual({ sum: 13, count: 3, avg: 13 / 3 });
});
test('decrementAggregateBy decrement-all clears the aggregate', () => {
  expect(decrementAggregateBy(13, 3, 13, 3)).toEqual({ sum: 0, count: 0, avg: 0 });
});
test('decrementAggregateBy underflow clamps to 0', () => {
  expect(decrementAggregateBy(5, 1, 100, 50)).toEqual({ sum: 0, count: 0, avg: 0 });
});
