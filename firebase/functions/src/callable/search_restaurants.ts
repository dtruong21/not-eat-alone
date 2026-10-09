import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import {
  PLACES_FIELD_MASK,
  buildSearchTextBody,
  mapPlacesResponse,
  normalizeQuery,
} from '../lib/places';
import { makeRateLimiter } from '../lib/rate_limit';

const PLACES_API_KEY = defineSecret('PLACES_API_KEY');
const PLACES_URL = 'https://places.googleapis.com/v1/places:searchText';
const allow = makeRateLimiter(30, 60_000);

/**
 * Server-side proxy for Places API (New) Text Search. Keeps the Places key out of
 * the app binary; App Check + auth + rate limit protect the quota.
 */
export const makeSearchRestaurants = () =>
  onCall(
    {
      region: 'europe-west1',
      secrets: [PLACES_API_KEY],
      enforceAppCheck: true,
      maxInstances: 10,
    },
    async (req) => {
      const uid = req.auth?.uid;
      if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

      const query = normalizeQuery(req.data?.query);
      if (query === null) throw new HttpsError('invalid-argument', 'Invalid query.');
      if (!allow(uid)) throw new HttpsError('resource-exhausted', 'Too many searches.');

      let res: Response;
      try {
        res = await fetch(PLACES_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': PLACES_API_KEY.value(),
            'X-Goog-FieldMask': PLACES_FIELD_MASK,
          },
          body: JSON.stringify(buildSearchTextBody(query)),
          signal: AbortSignal.timeout(8000),
        });
      } catch {
        throw new HttpsError('unavailable', 'Restaurant search is unavailable.');
      }
      if (!res.ok) {
        // Never forward upstream bodies: they can echo request details.
        console.error('places upstream error', res.status);
        throw new HttpsError('unavailable', 'Restaurant search is unavailable.');
      }
      return { restaurants: mapPlacesResponse(await res.json()) };
    },
  );
