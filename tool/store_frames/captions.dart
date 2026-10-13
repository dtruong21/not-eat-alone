/// Store-screenshot captions, one list per locale, in shot order.
///
/// Explicit line breaks keep every caption to two balanced lines.
/// French is a DRAFT for native review (informal "tu", typographic
/// apostrophes, no-break space before `:` `!` `?` `;`).
library;

/// Shot order: 1 discover, 2 meal detail, 3 requests, 4 chat, 5 safety.
const storeCaptions = <String, List<String>>{
  'en': [
    'Find meals\nnear you',
    'See the full meal,\nthen ask to join',
    'Hosts pick one match.\nNo group chaos',
    'Get to know them\nbefore you meet',
    'Safety built in:\nblock or report',
  ],
  'fr': [
    'Trouve un repas\nprès de chez toi',
    'Le repas en détail,\npuis rejoins la table',
    'L’hôte choisit\nune seule personne',
    'Discute d’abord,\ndîne ensuite',
    'La sécurité d’abord :\nbloque ou signale',
  ],
};
