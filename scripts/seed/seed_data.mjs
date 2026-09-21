// Pure, unit-testable doc builders for the STAGE Firestore seed data.
//
// Deliberately has NO firebase-admin import — everything here is plain JS
// data construction so it can be exercised by `node:test` without hitting
// any network or requiring credentials. `seed_stage.mjs` is the only file
// that talks to Firestore.

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/**
 * Standard base-32 geohash encoding of (lat, lng). Nearby points share a
 * common prefix — used for proximity queries (Plan 5 discovery).
 *
 * Direct port of `lib/core/util/geohash.dart`'s `encodeGeohash`.
 *
 * @param {number} lat
 * @param {number} lng
 * @param {number} [precision]
 * @returns {string}
 */
export function encodeGeohash(lat, lng, precision = 9) {
  let latMin = -90.0;
  let latMax = 90.0;
  let lngMin = -180.0;
  let lngMax = 180.0;
  let hash = '';
  let isEven = true;
  let bit = 0;
  let ch = 0;

  while (hash.length < precision) {
    if (isEven) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      hash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }

  return hash;
}

// Same ~20 Paris restaurants as
// `lib/features/meal/data/datasources/fake_restaurant_search_datasource.dart`
// (placeId/name/address/lat/lng copied verbatim).
export const restaurants = [
  {
    placeId: 'fake_001',
    name: 'Le Comptoir du Relais',
    address: "9 Carrefour de l'Odéon, 75006 Paris",
    lat: 48.8517,
    lng: 2.3389,
  },
  {
    placeId: 'fake_002',
    name: 'Bistrot Paul Bert',
    address: '18 Rue Paul Bert, 75011 Paris',
    lat: 48.8534,
    lng: 2.3839,
  },
  {
    placeId: 'fake_003',
    name: 'Septime',
    address: '80 Rue de Charonne, 75011 Paris',
    lat: 48.8558,
    lng: 2.3799,
  },
  {
    placeId: 'fake_004',
    name: 'Le Chateaubriand',
    address: '129 Avenue Parmentier, 75011 Paris',
    lat: 48.8657,
    lng: 2.3746,
  },
  {
    placeId: 'fake_005',
    name: 'Breizh Café',
    address: '109 Rue Vieille du Temple, 75003 Paris',
    lat: 48.8634,
    lng: 2.3625,
  },
  {
    placeId: 'fake_006',
    name: "L'Ami Jean",
    address: '27 Rue Malar, 75007 Paris',
    lat: 48.8595,
    lng: 2.3054,
  },
  {
    placeId: 'fake_007',
    name: 'Chez Georges',
    address: '1 Rue du Mail, 75002 Paris',
    lat: 48.8677,
    lng: 2.3417,
  },
  {
    placeId: 'fake_008',
    name: 'Le Baratin',
    address: '3 Rue Jouye-Rouve, 75020 Paris',
    lat: 48.8721,
    lng: 2.3865,
  },
  {
    placeId: 'fake_009',
    name: 'Frenchie',
    address: '5-6 Rue du Nil, 75002 Paris',
    lat: 48.8677,
    lng: 2.3468,
  },
  {
    placeId: 'fake_010',
    name: 'Clover Grill',
    address: '6 Rue Bailleul, 75001 Paris',
    lat: 48.8604,
    lng: 2.3417,
  },
  {
    placeId: 'fake_011',
    name: 'Le Servan',
    address: '32 Rue Saint-Maur, 75011 Paris',
    lat: 48.8617,
    lng: 2.3806,
  },
  {
    placeId: 'fake_012',
    name: 'Bouillon Pigalle',
    address: '22 Boulevard de Clichy, 75018 Paris',
    lat: 48.8827,
    lng: 2.3374,
  },
  {
    placeId: 'fake_013',
    name: 'Au Pied de Cochon',
    address: '6 Rue Coquillière, 75001 Paris',
    lat: 48.8625,
    lng: 2.3448,
  },
  {
    placeId: 'fake_014',
    name: 'Robert et Louise',
    address: '64 Rue Vieille du Temple, 75003 Paris',
    lat: 48.8615,
    lng: 2.3617,
  },
  {
    placeId: 'fake_015',
    name: 'Chez Janou',
    address: '2 Rue Roger Verlomme, 75003 Paris',
    lat: 48.8564,
    lng: 2.3654,
  },
  {
    placeId: 'fake_016',
    name: 'Le Grand Véfour',
    address: '17 Rue de Beaujolais, 75001 Paris',
    lat: 48.8646,
    lng: 2.3379,
  },
  {
    placeId: 'fake_017',
    name: "La Tour d'Argent",
    address: '15 Quai de la Tournelle, 75005 Paris',
    lat: 48.8503,
    lng: 2.3543,
  },
  {
    placeId: 'fake_018',
    name: 'Le Petit Cambodge',
    address: '20 Rue Alibert, 75010 Paris',
    lat: 48.8703,
    lng: 2.3641,
  },
  {
    placeId: 'fake_019',
    name: 'Holybelly',
    address: '19 Rue Lucien Sampaix, 75010 Paris',
    lat: 48.8717,
    lng: 2.3609,
  },
  {
    placeId: 'fake_020',
    name: 'Clamato',
    address: '80 Rue de Charonne, 75011 Paris',
    lat: 48.8556,
    lng: 2.3798,
  },
];

const GENDERS = ['woman', 'man', 'nonBinary'];

const DISPLAY_NAMES = [
  'Alice Martin',
  'Benoît Dubois',
  'Camille Rousseau',
  'Diego Fernandez',
  'Élise Laurent',
  'Farah Haddad',
  'Gabriel Silva',
  'Hana Kobayashi',
  'Idris Okafor',
  'Julia Novak',
  'Kenji Tanaka',
  'Léa Bernard',
];

const BIOS = [
  'Always up for trying a new bistro.',
  'Wine enthusiast, terrible cook.',
  'Looking for good conversation over good food.',
  'Runner, reader, ramen addict.',
  'New in Paris, exploring one meal at a time.',
  'Croissant connoisseur.',
  'Here for the food, staying for the company.',
  'Vegetarian who loves a challenge.',
  'Weekend brunch is my love language.',
  'Ask me about the best falafel in the city.',
  'Coffee first, everything else after.',
  'Trying to eat my way through every arrondissement.',
];

const MEAL_NOTES = [
  'Casual dinner, open to all topics.',
  'Looking for fellow foodies to split plates with.',
  "First time here, would love company.",
  'Business-casual, networking welcome.',
  'Quiet conversation over a slow meal.',
  'Celebrating a small win, join if you like.',
  'Trying the tasting menu, need a partner in crime.',
  'Post-work unwind, nothing fancy.',
  'Weekend brunch, no agenda.',
  'Exploring the neighborhood, tag along.',
  'Solo traveler looking for good company.',
  'Regular here, happy to show you around the menu.',
  'Low-key lunch between meetings.',
  'Celebrating Friday the right way.',
  'Anyone free for an early dinner?',
  'Looking to practice my French over dinner.',
  'Big appetite, bigger conversations welcome.',
  'Last-minute plan, first come first served.',
];

const MS_PER_YEAR = 365.25 * 24 * 60 * 60 * 1000;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Builds ~12 seed user doc objects matching `AppUserDto`'s shape:
 * `{ id, uid, displayName, gender, dob, ageVerified, photoUrls, bio, createdAt }`.
 *
 * @returns {Array<object>}
 */
export function buildSeedUsers() {
  const now = Date.now();

  return DISPLAY_NAMES.map((displayName, index) => {
    const n = index + 1;
    const id = `seed_user_${String(n).padStart(2, '0')}`;
    // Ages spread ~25-40 years old.
    const ageYears = 25 + (index % 16);
    const dob = new Date(now - ageYears * MS_PER_YEAR);

    return {
      id,
      uid: id,
      displayName,
      gender: GENDERS[index % GENDERS.length],
      dob,
      ageVerified: true,
      photoUrls: [`https://picsum.photos/seed/${id}/400`],
      bio: BIOS[index % BIOS.length],
      createdAt: new Date(now),
    };
  });
}

/**
 * Builds ~18 seed meal doc objects matching `MealDto`'s shape:
 * `{ id, hostId, restaurant, dateTime, geohash, note, womenOnly, seats,
 *    status, guestId, createdAt }`.
 *
 * @param {Array<object>} [restaurantList]
 * @param {Array<object>} [users]
 * @returns {Array<object>}
 */
export function buildSeedMeals(restaurantList = restaurants, users = buildSeedUsers()) {
  const now = Date.now();
  const count = 18;

  return Array.from({ length: count }, (_, index) => {
    const n = index + 1;
    const id = `seed_meal_${String(n).padStart(2, '0')}`;
    const restaurant = restaurantList[index % restaurantList.length];
    const host = users[index % users.length];
    // Spread future meals over the next ~14 days, varied hours.
    const daysOut = 1 + (index % 14);
    const hourOffset = (index % 6) * 2; // vary time of day
    const dateTime = new Date(
      now + daysOut * MS_PER_DAY + hourOffset * 60 * 60 * 1000,
    );

    return {
      id,
      hostId: host.uid,
      restaurant: {
        placeId: restaurant.placeId,
        name: restaurant.name,
        address: restaurant.address,
        lat: restaurant.lat,
        lng: restaurant.lng,
      },
      dateTime,
      geohash: encodeGeohash(restaurant.lat, restaurant.lng, 9),
      note: MEAL_NOTES[index % MEAL_NOTES.length],
      womenOnly: index % 4 === 0,
      seats: 1,
      status: 'open',
      guestId: null,
      createdAt: new Date(now),
    };
  });
}
