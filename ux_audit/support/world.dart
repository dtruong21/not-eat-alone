/// The seeded "realistic world" the UX capture harness photographs.
///
/// Everything is written through the Firestore emulator's admin REST API
/// (`adminSetDoc`, rules bypassed) so the world can contain states a client
/// can't create: past meals, matched meals, decided requests, matches,
/// ratings, messages from other users. Auth users are minted with the real
/// `signInTestUser` path, and every uid used below is the `.uid` of the
/// `User` it returned (the Auth emulator mints its own uids), never the
/// deterministic label passed in.
///
/// Times are relative to "now" so the feed always has a tonight-to-next-week
/// spread. Avatars are served by `tool/ux_images.py` on 127.0.0.1:8765.
///
/// DEV TOOLING ONLY — never imported from `lib/`.
library;

import 'package:not_eat_alone/core/util/geohash.dart';

import '../../integration_test/support/auth.dart';
import '../../integration_test/support/emulator_admin.dart';

/// Where `tool/ux_images.py` serves the placeholder portraits.
const String kAvatarBase = 'http://127.0.0.1:8765';

/// The ids the capture needs, returned by [seedWorld].
class UxWorld {
  const UxWorld({
    required this.viewerUid,
    required this.uids,
    required this.openMealByOtherId,
    required this.matchMealId,
    required this.matchPartnerUid,
    required this.ownMealId,
    required this.pastMatchMealId,
    required this.mealIds,
  });

  /// The user the capture signs in as ("Amélie Lefèvre", a woman).
  final String viewerUid;

  /// Persona key (`bastien`, `dario`, ...) -> Firebase uid.
  final Map<String, String> uids;

  /// An open, joinable meal by another host (Dario, "Pizzeria Popolare").
  final String openMealByOtherId;

  /// The match id (== meal id) of the seeded ~15-message chat, hosted by
  /// [matchPartnerUid] with the viewer as the approved guest.
  final String matchMealId;
  final String matchPartnerUid;

  /// The viewer's own upcoming meal (two pending requests on it).
  final String ownMealId;

  /// A past meal the viewer hosted that was matched and rated.
  final String pastMatchMealId;

  /// Meal label -> meal id, for the later full-matrix capture.
  final Map<String, String> mealIds;
}

class _Persona {
  const _Persona(
    this.key,
    this.name,
    this.age,
    this.gender,
    this.bio,
    this.photos, {
    this.ratingCount = 0,
    this.ratingAvg = 0.0,
  });

  final String key;
  final String name;
  final int age;
  final String gender;
  final String bio;
  final List<String> photos;
  final int ratingCount;
  final double ratingAvg;
}

const _personas = <_Persona>[
  _Persona(
    'bastien',
    'Bastien Marchetti',
    34,
    'man',
    'Sommelier by day, terrible at small talk by night. Always up for a '
        'long dinner and an argument about the best croissant in the 11th.',
    ['bastien'],
    ratingCount: 14,
    ratingAvg: 4.8,
  ),
  _Persona(
    'dario',
    'Dario Romano',
    27,
    'man',
    'New in Paris from Naples. Pizza snob, will gently judge your order.',
    ['dario'],
    ratingCount: 3,
    ratingAvg: 4.3,
  ),
  _Persona(
    'emilia',
    'Emilia Vasquez-Hernandez',
    41,
    'woman',
    'Architect. I like places with a story and a table by the window.',
    ['emilia', 'giulia'],
    ratingCount: 22,
    ratingAvg: 4.9,
  ),
  _Persona(
    'farid',
    'Farid Benali',
    31,
    'man',
    '',
    ['farid'],
    ratingCount: 1,
    ratingAvg: 5,
  ),
  _Persona(
    'giulia',
    'Giulia Pellegrini',
    25,
    'woman',
    'Erasmus that never ended. Tell me your favourite hidden bistro.',
    ['giulia'],
    ratingCount: 6,
    ratingAvg: 4.6,
  ),
  _Persona(
    'hugo',
    'Hugo Thibault',
    38,
    'man',
    'Cyclist, cook, occasional poet.',
    ['hugo'],
  ),
  _Persona(
    'ines',
    'Inès Charpentier',
    29,
    'nonBinary',
    'Vegetarian-ish. Will absolutely share dessert.',
    ['ines'],
    ratingCount: 2,
    ratingAvg: 4,
  ),
  _Persona(
    'viewer',
    'Amélie Lefèvre',
    29,
    'woman',
    'Product designer who eats out far too often. Looking for good '
        'company and better restaurants.',
    ['amelie', 'lea'],
    ratingCount: 7,
    ratingAvg: 4.7,
  ),
];

String _photo(String key) => '$kAvatarBase/$key.png';

List<String> _photoUrls(_Persona p) => p.photos.map(_photo).toList();

typedef _Place = ({
  String id,
  String name,
  String address,
  double lat,
  double lng,
});

const _places = <String, _Place>{
  'comptoir': (
    id: 'ux-place-comptoir',
    name: 'Le Comptoir du Relais',
    address: "9 Carrefour de l'Odéon, 75006 Paris",
    lat: 48.8512,
    lng: 2.3388,
  ),
  'pizzeria': (
    id: 'ux-place-pizzeria',
    name: 'Pizzeria Popolare',
    address: '111 Rue Réaumur, 75002 Paris',
    lat: 48.8671,
    lng: 2.3452,
  ),
  'chartier': (
    id: 'ux-place-chartier',
    name: 'Bouillon Chartier Grands Boulevards',
    address: '7 Rue du Faubourg Montmartre, 75009 Paris',
    lat: 48.8718,
    lng: 2.3425,
  ),
  'cambodge': (
    id: 'ux-place-cambodge',
    name: 'Le Petit Cambodge',
    address: '20 Rue Alibert, 75010 Paris',
    lat: 48.8700,
    lng: 2.3677,
  ),
  'flore': (
    id: 'ux-place-flore',
    name: 'Café de Flore',
    address: '172 Boulevard Saint-Germain, 75006 Paris',
    lat: 48.8541,
    lng: 2.3326,
  ),
  'septime': (
    id: 'ux-place-septime',
    name: 'Septime',
    address: '80 Rue de Charonne, 75011 Paris',
    lat: 48.8534,
    lng: 2.3809,
  ),
  'gladines': (
    id: 'ux-place-gladines',
    name: 'Chez Gladines',
    address: '30 Rue des Cinq Diamants, 75013 Paris',
    lat: 48.8272,
    lng: 2.3510,
  ),
  'lipp': (
    id: 'ux-place-lipp',
    name: 'Brasserie Lipp, Saint-Germain-des-Prés, salle du fond',
    address: '151 Boulevard Saint-Germain, 75006 Paris',
    lat: 48.8539,
    lng: 2.3334,
  ),
  'kunitoraya': (
    id: 'ux-place-kunitoraya',
    name: 'Kunitoraya',
    address: '5 Rue Villédo, 75001 Paris',
    lat: 48.8651,
    lng: 2.3359,
  ),
  'pinkmamma': (
    id: 'ux-place-pinkmamma',
    name: 'Pink Mamma',
    address: '20bis Rue de Douai, 75009 Paris',
    lat: 48.8820,
    lng: 2.3347,
  ),
  'bao': (
    id: 'ux-place-bao',
    name: 'Bao Family',
    address: '12 Rue Moret, 75011 Paris',
    lat: 48.8656,
    lng: 2.3817,
  ),
  'pigalle': (
    id: 'ux-place-pigalle',
    name: 'Le Bouillon Pigalle',
    address: '22 Boulevard de Clichy, 75018 Paris',
    lat: 48.8826,
    lng: 2.3382,
  ),
  'pain': (
    id: 'ux-place-pain',
    name: 'Du Pain et des Idées',
    address: '34 Rue Yves Toudic, 75010 Paris',
    lat: 48.8709,
    lng: 2.3629,
  ),
};

/// Evening [daysAhead] days from today at [hour]:[minute] local time.
DateTime _at(int daysAhead, int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + daysAhead, hour, minute);
}

Map<String, Object?> _restaurant(_Place p) => {
      'placeId': p.id,
      'name': p.name,
      'address': p.address,
      'lat': p.lat,
      'lng': p.lng,
    };

/// Writes a `meals/{id}` doc through the admin REST API and returns its id.
Future<String> _meal({
  required String id,
  required String hostId,
  required String place,
  required DateTime when,
  String? note,
  bool womenOnly = false,
  String status = 'open',
  String? guestId,
}) async {
  final p = _places[place]!;
  await adminSetDoc('meals', id, {
    'id': id,
    'hostId': hostId,
    'status': status,
    'geohash': encodeGeohash(p.lat, p.lng),
    'dateTime': when,
    'note': note,
    'womenOnly': womenOnly,
    'seats': 1,
    'guestId': guestId,
    'restaurant': _restaurant(p),
    'createdAt': DateTime.now().subtract(const Duration(days: 4)),
  });
  return id;
}

Future<void> _request({
  required String mealId,
  required String guestId,
  required String hostId,
  required String status,
  required DateTime createdAt,
}) async {
  final id = '${mealId}_$guestId';
  await adminSetDoc('requests', id, {
    'id': id,
    'mealId': mealId,
    'guestId': guestId,
    'hostId': hostId,
    'status': status,
    'createdAt': createdAt,
  });
}

Future<void> _match({
  required String mealId,
  required String hostId,
  required String guestId,
  required DateTime createdAt,
}) async {
  await adminSetDoc('matches', mealId, {
    'id': mealId,
    'mealId': mealId,
    'hostId': hostId,
    'guestId': guestId,
    'participants': [hostId, guestId],
    'createdAt': createdAt,
  });
}

Future<void> _message({
  required String matchId,
  required String index,
  required String senderId,
  required String text,
  required DateTime at,
}) async {
  final id = 'ux-msg-$index';
  await adminSetDoc('matches/$matchId/messages', id, {
    'id': id,
    'matchId': matchId,
    'senderId': senderId,
    'text': text,
    'createdAt': at,
  });
}

/// Seeds the whole world and leaves the Auth session signed in as the viewer.
///
/// Call after the app is booted (so the sign-in screen can be photographed
/// first). Clears both emulators before writing.
Future<UxWorld> seedWorld() async {
  await clearEmulators();

  // 1. Mint the Auth users via the real sign-in path. The viewer goes last so
  //    the session ends up signed in as them. (The app churns through
  //    onboarding for the profile-less personas meanwhile; harmless.)
  final uids = <String, String>{};
  for (final p in _personas) {
    final user = await signInTestUser(uid: 'ux-${p.key}');
    uids[p.key] = user.uid;
  }
  final viewer = uids['viewer']!;
  final bastien = uids['bastien']!;
  final dario = uids['dario']!;
  final emilia = uids['emilia']!;
  final farid = uids['farid']!;
  final giulia = uids['giulia']!;
  final hugo = uids['hugo']!;
  final now = DateTime.now();

  // 2. Users.
  for (final p in _personas) {
    await adminSetDoc('users', uids[p.key]!, {
      'uid': uids[p.key],
      'dob': DateTime(now.year - p.age, 3, 14),
      'ageVerified': true,
      'createdAt': now.subtract(const Duration(days: 60)),
      'displayName': p.name,
      'photoUrls': _photoUrls(p),
      if (p.bio.isNotEmpty) 'bio': p.bio,
      'gender': p.gender,
      'ratingCount': p.ratingCount,
      'ratingAvg': p.ratingAvg,
      'ratingSum': p.ratingAvg * p.ratingCount,
    });
  }

  // 3. Meals. Open meals by other hosts (Discover), nearest-first order is
  //    decided by the app. Hugo is blocked by the viewer, so his meal is
  //    hidden from Discover.
  final mealIds = <String, String>{};
  Future<String> open(
    String label,
    String host,
    String place,
    DateTime when, {
    String? note,
    bool womenOnly = false,
  }) async {
    final id = 'ux-meal-$label';
    mealIds[label] = id;
    await _meal(
      id: id,
      hostId: host,
      place: place,
      when: when,
      note: note,
      womenOnly: womenOnly,
    );
    return id;
  }

  final pizzeria = await open(
    'pizzeria',
    dario,
    'pizzeria',
    // "Tonight" while there is still a tonight; otherwise tomorrow lunch.
    _at(0, 20, 30).isAfter(now.add(const Duration(hours: 1)))
        ? _at(0, 20, 30)
        : _at(1, 12, 30),
    note: 'Margherita is non-negotiable. I booked the table in the back.',
  );
  await open(
    'chartier',
    emilia,
    'chartier',
    _at(1, 19, 30),
    note: 'Classic French on a budget. Expect a queue, bring patience and an '
        'appetite. I will save us a spot on the right side of the room, '
        'under the big mirror, and I would love to hear what everyone '
        'does for a living.',
  );
  await open(
    'cambodge',
    farid,
    'cambodge',
    _at(1, 12, 30),
  );
  await open(
    'flore',
    giulia,
    'flore',
    _at(2, 17),
    note: 'Women-only brunch-ish thing. Hot chocolate and gossip.',
    womenOnly: true,
  );
  await open(
    'septime',
    hugo,
    'septime',
    _at(3, 20),
    note: 'Tasting menu, shared.',
  );
  await open(
    'gladines',
    dario,
    'gladines',
    _at(3, 20, 15),
    note: 'Huge portions. Come hungry.',
  );
  await open(
    'lipp',
    emilia,
    'lipp',
    _at(5, 20),
    note: 'Dinner and then a walk along the Seine if the weather holds.',
  );
  await open('kunitoraya', farid, 'kunitoraya', _at(4, 19));
  await open(
    'pinkmamma',
    giulia,
    'pinkmamma',
    _at(6, 21),
    note: 'No reservations, so be on time!',
  );
  await open(
    'bao',
    dario,
    'bao',
    _at(7, 13),
    note: 'Lunch.',
  );

  // The viewer's own upcoming meal, with two pending requests.
  final ownMeal = await open(
    'own',
    viewer,
    'pigalle',
    _at(2, 19, 30),
    note: 'First time hosting! I will be the one with the red scarf.',
  );
  await _request(
    mealId: ownMeal,
    guestId: dario,
    hostId: viewer,
    status: 'pending',
    createdAt: now.subtract(const Duration(hours: 5)),
  );
  await _request(
    mealId: ownMeal,
    guestId: emilia,
    hostId: viewer,
    status: 'pending',
    createdAt: now.subtract(const Duration(minutes: 40)),
  );

  // The viewer has asked to join Farid's lunch (shows "Requested").
  await _request(
    mealId: 'ux-meal-cambodge',
    guestId: viewer,
    hostId: farid,
    status: 'pending',
    createdAt: now.subtract(const Duration(hours: 2)),
  );

  // Matched meal hosted by Bastien with the viewer as the approved guest,
  // and the ~15-message chat. Not in Discover (status matched).
  final matchMeal = await _meal(
    id: 'ux-meal-comptoir',
    hostId: bastien,
    place: 'comptoir',
    when: _at(1, 20),
    note: 'Taking the 20:00 slot. I will wear a blue jacket.',
    status: 'matched',
    guestId: viewer,
  );
  mealIds['comptoir'] = matchMeal;
  final matchCreated = now.subtract(const Duration(days: 3, hours: 1));
  await _request(
    mealId: matchMeal,
    guestId: viewer,
    hostId: bastien,
    status: 'approved',
    createdAt: matchCreated.subtract(const Duration(hours: 3)),
  );
  await _match(
    mealId: matchMeal,
    hostId: bastien,
    guestId: viewer,
    createdAt: matchCreated,
  );
  final chat = <({int minutesAgo, bool mine, String text})>[
    (
      minutesAgo: 4300,
      mine: false,
      text: 'Hi Amélie! Glad to have you at the table on Thursday 🙂',
    ),
    (
      minutesAgo: 4285,
      mine: true,
      text: 'Hi Bastien! Thanks for accepting. I have wanted to try this '
          'place for ages.',
    ),
    (
      minutesAgo: 4270,
      mine: false,
      text: 'Same! Have you been in the area before? It is right by Odéon, '
          'a short walk from the metro.',
    ),
    (
      minutesAgo: 4100,
      mine: true,
      text: 'Not for dinner. Is it okay if I am 5 minutes late? I am coming '
          'straight from work.',
    ),
    (
      minutesAgo: 4090,
      mine: false,
      text: 'No problem at all. I will grab the table and give the name '
          'Marchetti.',
    ),
    (minutesAgo: 2900, mine: true, text: 'Perfect.'),
    (
      minutesAgo: 2895,
      mine: true,
      text: 'Any allergies I should know about? I am vegetarian but I eat '
          'fish.',
    ),
    (
      minutesAgo: 2850,
      mine: false,
      text: 'Good to know, the menu has a great fish dish. I eat '
          'everything, so no worries on my side.',
    ),
    (
      minutesAgo: 2848,
      mine: false,
      text: 'Quick plan:\n- 20:00 at the door\n- we split a starter\n'
          '- no phones at the table 😄',
    ),
    (minutesAgo: 2800, mine: true, text: 'Deal!'),
    (
      minutesAgo: 1500,
      mine: true,
      text: 'By the way, I might bring a friend along for the aperitif only. '
          'She lives around the corner and wants to say hi before dinner. '
          'Would that be okay with you, or would you rather keep it just '
          'the two of us? Totally fine either way!',
    ),
    (
      minutesAgo: 1440,
      mine: false,
      text: 'Of course, the more the merrier for a drink.',
    ),
    (
      minutesAgo: 190,
      mine: false,
      text: 'Reminder: tomorrow 20:00, Le Comptoir du Relais. Looking '
          'forward to it!',
    ),
    (minutesAgo: 120, mine: true, text: 'See you there! 🍷'),
    (
      minutesAgo: 118,
      mine: true,
      text: 'Which entrance, by the way? There seem to be two.',
    ),
  ];
  for (var i = 0; i < chat.length; i++) {
    final m = chat[i];
    await _message(
      matchId: matchMeal,
      index: i.toString().padLeft(2, '0'),
      senderId: m.mine ? viewer : bastien,
      text: m.text,
      at: now.subtract(Duration(minutes: m.minutesAgo)),
    );
  }
  // Bastien has read everything, so the viewer's last message shows "Seen".
  await adminSetDoc('matches/$matchMeal/reads', bastien, {
    'uid': bastien,
    'lastReadAt': now.subtract(const Duration(minutes: 100)),
  });

  // A past meal the viewer hosted with Giulia: matched, a short chat, and a
  // 5-star rating from Giulia (the viewer has not rated back yet).
  final past = await _meal(
    id: 'ux-meal-past-matched',
    hostId: viewer,
    place: 'pain',
    when: now.subtract(const Duration(days: 3, hours: 2)),
    note: 'Sunday brunch.',
    status: 'matched',
    guestId: giulia,
  );
  mealIds['pastMatched'] = past;
  await _request(
    mealId: past,
    guestId: giulia,
    hostId: viewer,
    status: 'approved',
    createdAt: now.subtract(const Duration(days: 6)),
  );
  await _match(
    mealId: past,
    hostId: viewer,
    guestId: giulia,
    createdAt: now.subtract(const Duration(days: 5, hours: 20)),
  );
  const pastChat = <({bool mine, String text})>[
    (mine: false, text: 'Looking forward to brunch!'),
    (mine: true, text: 'Me too, the bakery opens at 8 so we can queue early.'),
    (mine: false, text: 'That was such a lovely morning, thank you!'),
  ];
  for (var i = 0; i < pastChat.length; i++) {
    await _message(
      matchId: past,
      index: i.toString().padLeft(2, '0'),
      senderId: pastChat[i].mine ? viewer : giulia,
      text: pastChat[i].text,
      at: now.subtract(Duration(days: 5 - i, hours: 2)),
    );
  }
  await adminSetDoc('ratings', '${past}_$giulia', {
    'id': '${past}_$giulia',
    'matchId': past,
    'raterUid': giulia,
    'targetUid': viewer,
    'stars': 5,
    'showedUp': true,
    'comment': 'Wonderful morning, great conversation and the best croissants.',
    'createdAt': now.subtract(const Duration(days: 2)),
    // Already counted in the viewer's aggregate above: tells the
    // ratingCreated function not to count it again.
    'aggregated': true,
  });

  // A past, still-pending request on a meal the viewer hosted (Farid's
  // request was never answered): the inbox's "past meal" state.
  final pastOpen = await _meal(
    id: 'ux-meal-past-open',
    hostId: viewer,
    place: 'pain',
    when: now.subtract(const Duration(days: 1, hours: 4)),
    note: 'Coffee and croissants.',
  );
  mealIds['pastOpen'] = pastOpen;
  await _request(
    mealId: pastOpen,
    guestId: farid,
    hostId: viewer,
    status: 'pending',
    createdAt: now.subtract(const Duration(days: 3)),
  );

  // The viewer blocked Hugo.
  await adminSetDoc('blocks', '${viewer}_$hugo', {
    'id': '${viewer}_$hugo',
    'blockerUid': viewer,
    'blockedUid': hugo,
    'pair': [viewer, hugo],
    'createdAt': now.subtract(const Duration(days: 10)),
  });

  // 4. Leave the session signed in as the viewer (signInTestUser returns the
  //    emulator-minted uid; it must equal the one used above).
  final signedIn = await signInTestUser(uid: 'ux-viewer');
  if (signedIn.uid != viewer) {
    throw StateError('viewer uid changed between sign-ins');
  }

  return UxWorld(
    viewerUid: viewer,
    uids: uids,
    openMealByOtherId: pizzeria,
    matchMealId: matchMeal,
    matchPartnerUid: bastien,
    ownMealId: ownMeal,
    pastMatchMealId: past,
    mealIds: mealIds,
  );
}
