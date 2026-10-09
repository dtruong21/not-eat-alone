import {
  MAX_QUERY_LENGTH,
  PARIS_BOUNDS,
  buildSearchTextBody,
  mapPlacesResponse,
  normalizeQuery,
} from '../src/lib/places';
import { makeRateLimiter } from '../src/lib/rate_limit';

describe('normalizeQuery', () => {
  test('missing/empty becomes empty string', () => {
    expect(normalizeQuery(undefined)).toBe('');
    expect(normalizeQuery('   ')).toBe('');
  });
  test('trims and collapses whitespace', () => {
    expect(normalizeQuery('  le   comptoir ')).toBe('le comptoir');
  });
  test('rejects non-strings and over-long input', () => {
    expect(normalizeQuery(42)).toBeNull();
    expect(normalizeQuery({})).toBeNull();
    expect(normalizeQuery('a'.repeat(MAX_QUERY_LENGTH + 1))).toBeNull();
    expect(normalizeQuery('a'.repeat(MAX_QUERY_LENGTH))).not.toBeNull();
  });
});

describe('buildSearchTextBody', () => {
  test('restricts to Paris restaurants', () => {
    const body = buildSearchTextBody('septime');
    expect(body.textQuery).toBe('septime');
    expect(body.includedType).toBe('restaurant');
    expect(body.locationRestriction).toEqual({ rectangle: PARIS_BOUNDS });
  });
  test('empty query falls back to a default', () => {
    expect(buildSearchTextBody('').textQuery).toBe('restaurant');
  });
});

describe('mapPlacesResponse', () => {
  const valid = {
    id: 'abc',
    displayName: { text: 'Septime' },
    formattedAddress: '80 Rue de Charonne, 75011 Paris',
    location: { latitude: 48.8558, longitude: 2.3799 },
  };
  test('maps valid places to the app DTO shape', () => {
    expect(mapPlacesResponse({ places: [valid] })).toEqual([
      {
        placeId: 'abc',
        name: 'Septime',
        address: '80 Rue de Charonne, 75011 Paris',
        lat: 48.8558,
        lng: 2.3799,
      },
    ]);
  });
  test('drops malformed entries and tolerates empty responses', () => {
    expect(mapPlacesResponse({ places: [{ id: 'x' }, valid] })).toHaveLength(1);
    expect(mapPlacesResponse({})).toEqual([]);
    expect(mapPlacesResponse(null)).toEqual([]);
  });
});

describe('makeRateLimiter', () => {
  test('blocks past the limit and recovers after the window', () => {
    let t = 0;
    const allow = makeRateLimiter(2, 1000, () => t);
    expect(allow('u')).toBe(true);
    expect(allow('u')).toBe(true);
    expect(allow('u')).toBe(false);
    expect(allow('other')).toBe(true);
    t = 1001;
    expect(allow('u')).toBe(true);
  });
});
