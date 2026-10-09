/** Pure helpers for the `searchRestaurants` callable (validation, request, mapping). */

/** Paris soft-launch bounding box (v1 is Paris-only). */
export const PARIS_BOUNDS = {
  low: { latitude: 48.815, longitude: 2.224 },
  high: { latitude: 48.902, longitude: 2.47 },
} as const;

export const MAX_QUERY_LENGTH = 80;
export const MAX_RESULTS = 20;

/** Used when the client sends an empty query (initial picker state). */
const DEFAULT_QUERY = 'restaurant';

/** Shape consumed by the app's `RestaurantDto.fromJson`. */
export interface RestaurantResult {
  placeId: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
}

/** Billed per field: only request what the app renders. */
export const PLACES_FIELD_MASK =
  'places.id,places.displayName,places.formattedAddress,places.location';

export function normalizeQuery(raw: unknown): string | null {
  if (raw === undefined || raw === null) return '';
  if (typeof raw !== 'string') return null;
  const query = raw.replace(/\s+/g, ' ').trim();
  return query.length > MAX_QUERY_LENGTH ? null : query;
}

export function buildSearchTextBody(query: string): Record<string, unknown> {
  return {
    textQuery: query === '' ? DEFAULT_QUERY : query,
    includedType: 'restaurant',
    strictTypeFiltering: true,
    languageCode: 'en',
    regionCode: 'FR',
    pageSize: MAX_RESULTS,
    locationRestriction: { rectangle: PARIS_BOUNDS },
  };
}

interface PlacesPlace {
  id?: unknown;
  displayName?: { text?: unknown };
  formattedAddress?: unknown;
  location?: { latitude?: unknown; longitude?: unknown };
}

/** Maps a Places API (New) `searchText` response, dropping malformed entries. */
export function mapPlacesResponse(body: unknown): RestaurantResult[] {
  const places = (body as { places?: unknown } | null)?.places;
  if (!Array.isArray(places)) return [];
  const out: RestaurantResult[] = [];
  for (const p of places as PlacesPlace[]) {
    const lat = p.location?.latitude;
    const lng = p.location?.longitude;
    if (
      typeof p.id !== 'string' ||
      typeof p.displayName?.text !== 'string' ||
      typeof p.formattedAddress !== 'string' ||
      typeof lat !== 'number' ||
      typeof lng !== 'number'
    ) {
      continue;
    }
    out.push({
      placeId: p.id,
      name: p.displayName.text,
      address: p.formattedAddress,
      lat,
      lng,
    });
  }
  return out;
}
