import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  encodeGeohash,
  restaurants,
  buildSeedUsers,
  buildSeedMeals,
} from './seed_data.mjs';

const VALID_GENDERS = new Set(['woman', 'man', 'nonBinary']);

test('encodeGeohash matches the canonical known-point prefix', () => {
  assert.equal(encodeGeohash(57.64911, 10.40744, 11), 'u4pruydqqvj');
});

test('encodeGeohash defaults to precision 9', () => {
  const hash = encodeGeohash(48.8517, 2.3389);
  assert.equal(hash.length, 9);
});

test('restaurants has ~20 Paris entries with required fields', () => {
  assert.ok(restaurants.length >= 15);
  for (const r of restaurants) {
    assert.equal(typeof r.placeId, 'string');
    assert.equal(typeof r.name, 'string');
    assert.equal(typeof r.address, 'string');
    assert.equal(typeof r.lat, 'number');
    assert.equal(typeof r.lng, 'number');
  }
});

test('buildSeedUsers returns >=10 valid users', () => {
  const users = buildSeedUsers();
  assert.ok(users.length >= 10, `expected >=10 users, got ${users.length}`);

  for (const user of users) {
    assert.equal(user.ageVerified, true);
    assert.ok(user.photoUrls.length >= 1);
    assert.ok(VALID_GENDERS.has(user.gender), `invalid gender: ${user.gender}`);
    assert.ok(user.dob instanceof Date);
    assert.equal(user.uid, user.id);
    assert.equal(typeof user.displayName, 'string');
  }

  // ids/uids unique
  const ids = new Set(users.map((u) => u.id));
  assert.equal(ids.size, users.length);
});

test('buildSeedMeals returns >=15 valid open meals', () => {
  const users = buildSeedUsers();
  const meals = buildSeedMeals(restaurants, users);
  assert.ok(meals.length >= 15, `expected >=15 meals, got ${meals.length}`);

  const now = Date.now();
  const validHostIds = new Set(users.map((u) => u.uid));

  for (const meal of meals) {
    assert.equal(meal.status, 'open');
    assert.equal(meal.geohash.length, 9);
    assert.ok(meal.dateTime instanceof Date);
    assert.ok(meal.dateTime.getTime() > now, 'dateTime must be in the future');
    assert.ok(validHostIds.has(meal.hostId));
    assert.equal(meal.seats, 1);
    assert.equal(typeof meal.restaurant.placeId, 'string');
  }

  // At least one womenOnly meal for filter testing.
  assert.ok(meals.some((m) => m.womenOnly === true));

  // ids unique
  const ids = new Set(meals.map((m) => m.id));
  assert.equal(ids.size, meals.length);
});
