# Push notifications: French review (needs native review)

> **Needs native review.** The French below was drafted by the
> developer, not by a native speaker. Do not ship to the stores
> before it has been read through.

The app's own strings are reviewed in [`FRENCH-REVIEW.md`](FRENCH-REVIEW.md)
(generated from `lib/l10n/app_fr.arb`). Push text is different: it is built
by Cloud Functions, in the language stored on the device's token document
(`users/{uid}/fcmTokens/{token}.lang`, `en` or `fr`; absent = `en`). This file
is **hand-maintained** and mirrors the `COPY` table in
`firebase/functions/src/lib/payloads.ts`. A script check of every string
against the code was run when this file was written; re-check after edits.

## How to review

1. Read the table; edit the **French** column (or send `notification -> new French`).
2. Apply each change to the `fr` block of `COPY` in
   `firebase/functions/src/lib/payloads.ts` (same notification), then update the
   exact-text expectations in `firebase/functions/test/payloads.test.ts`.
3. From `firebase/functions`: `npm run build && npm run lint && npm test`.
4. Update this file by hand to match.

Conventions: informal "tu"; short and warm like the English; brand "Convyve";
typographic apostrophe ’ (never the ASCII one); a non-breaking space
(U+00A0, written ` ` in `payloads.ts`, shown here as ⍽) before `? ! : ;`.
Push banners are short: the OS truncates long titles and bodies.

## How the language reaches the server

- Each device writes `users/{uid}/fcmTokens/{token}` with `token`, `platform`,
  `lang` (`en` or `fr`; absent or anything else = `en`) and `updatedAt`. `lang` is the
  language the app is showing (explicit Settings choice, else the device language,
  else English). It is re-written on every app start and as soon as the language is
  changed in Settings, and it is per device: the same account signed in on two
  devices gets each push in that device's language.
- Cloud Functions group a user's token docs by `lang` and send one multicast per
  language. `firestore.rules` and indexes are unchanged (the owner-only `fcmTokens`
  rule already allows the field).
- Release order is independent. Old app versions never write `lang`, so they stay
  English; a new app against an old Functions deploy only adds a field that is ignored.
- Functions are deployed by the repository CD after the merge to `develop`
  ([`docs/CICD.md`](../CICD.md), "Backend CD"); nothing is deployed by hand for this
  change. After the merge, check that the *Deploy Firebase backend* job succeeded and,
  once APNs is set up, spot-check one push on a real device in each language.

Known limits:

- A language change made in the OS while "System default" is selected is picked up
  at the next app start, not live.
- A push shown while the app is in the foreground uses the server text as sent.
- Legacy tokens (no `lang`) stay English until that device updates the app and starts it.

## Strings

`{name}` is the other person's display name, `{restaurant}` the restaurant name
(cut at 80 characters with …), `{time}` the meal time in Paris (`20:00`).

| Notification | Trigger | English title / body | French title / body | Notes |
| --- | --- | --- | --- | --- |
| Request created | A guest asks to join; sent to the host | New request / Someone wants to join your meal. | Nouvelle demande / Quelqu’un veut se joindre à ton repas. | |
| Request approved | The host approves; sent to the guest | You're in! / Your request was approved — say hi. | C’est validé⍽! / Ta demande a été acceptée⍽: dis bonjour. | |
| Request denied | The host declines; sent to the guest | Request update / Your request was declined. | Mise à jour de ta demande / Ta demande a été refusée. | |
| New message | A chat message; sent to the other person | {sender name} / {message text, cut at 120 characters} | same | User-written content, never translated. Only the no-display-name title falls back (table below). |
| Post-meal prompt | After the meal; asks for a rating | How was it? / Rate your meal with {name}. | Comment c’était⍽? / Note ton repas avec {name}. | |
| Meal reminder, 24 h, same Paris day | 24 h before; the meal is on the same Paris calendar day | Your meal is today / {restaurant} at {time} | Ton repas, c’est aujourd’hui / {restaurant} à {time} | |
| Meal reminder, 24 h, next day | 24 h before; the meal is on the next Paris day | Your meal is tomorrow / {restaurant} at {time} | Ton repas, c’est demain / {restaurant} à {time} | |
| Meal reminder, 2 h | 2 h before | Your meal is coming up / {restaurant} at {time} | Ton repas approche / {restaurant} à {time} | |
| Match left (account deleted) | The matched guest deleted their account; sent to the host | Your match left Convyve / (body below) | L’autre personne a quitté Convyve / (body below) | Neutral "l’autre personne" on purpose: no gender, no "match". |
| Match left (withdrew) | The matched guest withdrew from the meal; sent to the host | Your match withdrew / (body below) | L’autre personne a annulé sa participation / (body below) | Same. |
| Match left body, meal reopened | Either match-left case; the meal is open again | (title above) / Your meal is open again so someone else can join. | (title above) / Ton repas est de nouveau ouvert aux autres. | |
| Match left body, meal cancelled | Either match-left case; the meal is cancelled | (title above) / Your meal was cancelled. | (title above) / Ton repas a été annulé. | |
| Meal cancelled title | Sent to the matched guest in both cases below | Meal cancelled / (body below) | Repas annulé / (body below) | |
| Meal cancelled body, host cancelled | The host cancelled the meal | (title above) / The host cancelled this meal. | (title above) / L’hôte a annulé ce repas. | Same wording as `mealActionStatusCancelled` in the app. |
| Meal cancelled body, host left | The host deleted their account | (title above) / The host left Convyve, so this meal is cancelled. | (title above) / L’hôte a quitté Convyve, ce repas est donc annulé. | |

## Fallbacks

Used when the server has no name to show.

| Where | English | French |
| --- | --- | --- |
| Post-meal prompt, the other person's name is unknown (`{name}`) | your match | l’autre personne |
| Meal reminder, the restaurant name is missing (`{restaurant}`) | your restaurant | ton restaurant |
| New message, the sender has no display name (title) | New message | Nouveau message |

## Questions for the native reviewer

- "C’est validé !" (request approved) and "Mise à jour de ta demande" (declined): right tone?
- "L’autre personne" for the match: acceptable, or prefer another neutral wording?
- "Ton repas, c’est aujourd’hui / demain" vs a plainer "Ton repas est aujourd’hui".
- The reminder body "{restaurant} à {time}" with the time as 20:00 (24 h): fine, or "20 h 00"?
