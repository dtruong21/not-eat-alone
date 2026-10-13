# UX plan 19: verification capture (French + English)

Plan 19 (French UI, English kept, in-app language switch in Settings) checked on the real app. Simulators "Convyve E2E" (iPhone 17 Pro, 402x874 pt) and "Convyve UX Small" (iPhone SE 3rd gen, 375x667 pt). The simulator language was never changed: the app language comes from `UX_LOCALE=fr` (see below; empty = English, whatever the simulator language is; E2E `pumpApp` pins `app_locale` to `en` the same way).
Cells captured: `19-fr-light-default` (French, iPhone 17 Pro), `19-light-default` (English, same device, regression check) and `se3-light-xxl-fr` (French, small phone, `accessibility-extra-large`). BEFORE for the English comparison = `18-light-default` (73 PNG, 0 `UXOVERFLOW`, plan 18 verification) and `se3-light-xxl` (73 PNG, 0 `UXOVERFLOW`).
Seed times and the status-bar clock differ between runs (the seed is relative to "now"): compare structure only. Both simulators were put back to light / `large` afterwards. Eight downscaled shots are in `docs/ux/shots-19/`.

## Harness changes (`ux_audit/`, README updated)

- **French cell without touching the simulator language.** `make ux-capture ... UX_LOCALE=fr` (the Makefile passes it to `flutter drive` as `--dart-define=UX_LOCALE=fr`); `tool/ux_matrix.sh --only se3-light-xxl --locale fr` runs a matrix cell with a `-fr` suffix. The capture test overrides `localeSeedProvider` with `fr` in the scope it re-pumps after boot (the same value `bootstrap` reads from `app_locale`).
- **Finders take the English string and look up its French twin** (`_text`, `_textContaining`, `_l`, map `_fr` in `capture_test.dart`; kept in step with `app_fr.arb` by hand). Material-owned strings ("OK") need no entry.
- **`pageBack` is English-only.** It looks for the "Back" tooltip, which is "Retour" in French; the failure was swallowed, so the first French run lost `44_meal_detail_not_selected` and `49_meal_detail_request_rejected` (the screen stayed on the previous detail). `_back` now taps the tooltip in the run's language.
- **`83_settings` waited for a row that is lazy.** It waited for `settings_contact_support`, which French's longer labels at 2.0x push below the built part of the list. It now waits for the first row, `settings_edit_profile` (the old comment already said "the first row").
- First attempt of the French default cell was covered by the native "Would Like to Send You Notifications" alert (same cause as plan 18); the run was stopped, "Convyve E2E" shut down and booted, and the cell re-run. A later small-phone attempt hung after "Xcode build done" (the known intermittent launch hang); it was killed (only processes of this task) and re-run.

## Counts

| Cell | PNG | `UXOVERFLOW` | Failed steps |
|---|---|---|---|
| `19-light-default` (English) | 73 | 0 | 0 |
| `19-fr-light-default` | 73 | 0 | 0 |
| `se3-light-xxl-fr`, first run | 68 | 1 | 5 (harness: Settings wait, see above) |
| `se3-light-xxl-fr`, after the fixes below | 73 | 0 | 0 |
| `se3-light-xxl` (English, plan 18, not re-run) | 73 | 0 | 0 |

English did not regress: same 73 shots, no overflow, no failed step (`93_discover_error` is the usual `UXNOTE` skip).

## French defects found

| Shot (cell) | Defect | Verdict |
|---|---|---|
| `20_discover_loading`, `22` (se3 xxl) | Bottom tab "Discussions" wrapped mid-word ("Discussion / s") and the tab bar overflowed (42 px `UXOVERFLOW`, together with the next item) | Fixed: `navChats` and `chatListTitle` are "Messages" (8 letters, as "Demandes"); `FRENCH-REVIEW.md` regenerated |
| `20`, `22` (se3 xxl) | Floating button "Proposer un repas" was wider than the screen ("+" cut off at the left) | Fixed: `discoverCreateMeal` and `createMealTitle` are "Créer un repas" (the English "Create a meal" fits) |
| `20_discover_loading` (se3 xxl) | The Paris notice took 6 lines (English: 5) and pushed the skeleton list 42 px out of the screen | Fixed: `parisNotice` is "Convyve n’est qu’à Paris pour l’instant — on démarre tout juste." (5 lines) |
| `06_phone_verify_error` | "Vérifie-le ou renvoie-le." wrapped after "renvoie-" leaving "le." alone | Fixed (final review wave): `phoneWrongCode` is now "Ce code n’a pas fonctionné. Vérifie-le ou demande un nouveau code." |
| `72_chat_post_meal_card` (default size) | The Rate button on the post-meal card reads "Noter Giulia Pe…" (English "Rate Giulia Pellegrini" wraps to two full lines): "Noter" is two letters longer and the French title takes two lines. A 3-line button or a 1:1 row breaks the English layout tests (card height, one-line title at 360 px) | Fixed (follow-ups plan 21): the button reads "Rate" / "Noter" at every size; the person is named in the card subtitle ("With Giulia Pellegrini", up to 2 lines) and in the button's screen-reader label; tested at 320 px and 1.0x/1.3x/2.0x in both languages |
| `62_chats_data` (default size) | Meal line "Du Pain et des Idées · sam. 10 oct., 08:…" ellipsized (English "Sat 10 Oct, 08:45" is two characters shorter, at the limit) | Left, P3 (same family as the chat-row ellipses at 2.0x, which are English too) |
| `63`/`65`/`72` (se3 xxl) | The two-line safety banner ended in "Nos co…" ("Bientôt à table ? Nos conseils de sécurité"); the English one ("Meeting up? Safety tips") fits | Fixed (final review wave): `safetyTipsBanner` is "Bientôt à table ? Conseils de sécurité" (not re-photographed; the crowded chat top at 2.0x is already a plan 18 follow-up) |

Not defects: apostrophes are curly everywhere, a non-breaking space keeps "?", "!" and ":" attached to the word before them (checked in `63`, `71`, `83`), dates are French and short ("jeu. 15 oct., 19:00", "Aujourd’hui", "Demain"), the native date picker and the iOS back/close tooltips follow the app language. The Apple sign-in button text is the native control (system font). Seeded demo content (restaurant names, bios, chat messages) is English because it is data.

## Per shot (French default size unless noted)

| Shot | What changed | Verdict |
|---|---|---|
| `01_signin`, `02`-`07` | "Bienvenue sur Convyve", "Continuer avec Google/Apple", "ou", "Numéro de téléphone", "Envoyer le code"; code screen "Saisis le code", "Valider", "Renvoyer le code dans 26 s" | OK |
| `10_age_gate`-`16` | "Confirme ta date de naissance", picker in French ("lun. 13 oct.", "Annuler", "OK"), profile setup "Configure ton profil", "Il manque encore : une photo, ton nom et ton genre." | OK |
| `20_discover_loading`-`26` | Title, Paris notice, "Pas encore de repas près de toi", cards with "Aujourd’hui 20:30 · 1,3 km" (comma decimal, NBSP before km), "Entre femmes" badge, "Créer un repas" button, tabs Découvrir / Messages / Demandes / Profil | OK after the fixes |
| `30_restaurant_search`-`37` | "Trouver un restaurant", "Chercher un restaurant", create meal "Créer un repas", "Note (facultative)", "Publier le repas", French date and time pickers | OK |
| `40_meal_detail_open` | "Détails du repas", "Ouvrir dans Maps", "Hôte", "Dario Romano, 27 ans", "Demander à rejoindre" | OK |
| `42`, `43`, `44`, `45`, `46`, `48`, `49` | Every action bar state: "Demande envoyée" + "L’hôte n’a pas encore répondu.", "Ouvrir la discussion" + "C’est un match !", "Pas cette fois" + "L’hôte a choisi quelqu’un d’autre.", "Entre femmes" + "Réservé aux femmes.", "C’est ton repas" + "Tes demandes : onglet Demandes.", the rejected-request snackbar "Impossible d’envoyer ta demande. Réessaie." | OK |
| `47_meal_detail_menu` | "Signaler ce repas", "Signaler l’hôte", "Bloquer l’hôte" | OK |
| `51`-`55` | "Demandes", "Refuser" / "Accepter", "L’heure du repas est passée", star rating "4,9 (22)" | OK |
| `60`-`62` | "Messages", "Trouver un repas", meal line under each name, "Dis bonjour 👋" | OK (one ellipsis, see above) |
| `63`-`66`, `76` | Meal header, safety banner "Bientôt à table ? Conseils de sécurité" (shortened after this capture), "Aujourd’hui", "Vu", safety sheet "Bientôt à table ? Reste en sécurité" with four tips and "Compris" | OK |
| `67`-`71` | Report sheet "Signaler Bastien Marchetti", reasons (Contenu inapproprié, Spam, Harcèlement, Faux profil, Autre), "Ajoute un commentaire (facultatif)" (wording changed after this capture: was "Ajoute une note"), block dialog "Bloquer Bastien Marchetti ?" with "Annuler" / "Bloquer" | OK |
| `72`-`75` | "Comment s’est passé ton repas ?", "Ça ne prend qu’un instant.", rating sheet "Comment s’est passé ton repas avec Giulia Pellegrini ?", "La personne est-elle venue ?", "Ajoute un commentaire (facultatif)", "Envoyer" | OK (Rate button no longer truncated, see above) |
| `80`-`82b` | "Profil", "Ta note 4,7 (7)", "Je suis" Femme / Homme / Non-binaire, "Nom", "Bio", "Enregistrer" | OK |
| `83_settings`, `84_settings_bottom` | Groups Compte, Sécurité, Notifications, Informations légales (was "Mentions légales" at capture time), À propos; "Modifier le profil", "Se déconnecter", "Personnes bloquées", "Conseils de sécurité", "Contacter l’assistance", "Réglages des notifications", "Licences open source"; new **Langue** row with the current value "Français"; "Version v1.1.0 (build 2)"; "Supprimer le compte" in red | OK (the language picker sheet itself is widget-tested, not photographed) |
| `85`, `86`, `87` | Delete dialog, "Personnes bloquées" with "Débloquer", empty state "Tu n’as bloqué personne" | OK |
| `90`-`92` | "Chargement impossible", "Vérifie ta connexion et réessaie.", "Réessayer" | OK |

## Small phone, `accessibility-extra-large` (se3-light-xxl-fr)

`UXOVERFLOW` lines: 1 on the first run (French tab bar), 0 after the fixes; no failed step, no missing indicator, 73 of 73 PNG. What still looks poor at this size is the same as in English (plan 18 list: names and meal lines ellipsized in rows, tall request tiles, crowded chat top) plus the longer French banner (see table). The tab bar, floating button and Paris notice now fit.

## Remaining defects and follow-ups

| Item | Severity | Owner |
|---|---|---|
| Push-notification text from Cloud Functions is English: needs server-side i18n and the user's language stored server-side (a field on `users/{uid}`, written from the language picker) | P2 | Follow-up (functions + user doc) |
| Store listing in French: **drafted** in [`docs/store/listing.fr.md`](../store/listing.fr.md) (plan 20, needs native review). French privacy policy, terms and support pages are still to do | P3 | Native reviewer / owner |
| Native French review of `docs/l10n/FRENCH-REVIEW.md` (the table was regenerated: "Messages", "Créer un repas" and the Paris notice changed in this task) | P2 | Native reviewer |
| Android notification settings row (needs an Android settings intent, so a package) | P3 | Follow-up (Android) |
| `ci.yml` runs the date tests only under Pacific/Kiritimati, so the America/Los_Angeles DST group never runs in CI (run by hand here, green) | P3 | CI owner |
| ~~The Paris notice is not remembered after dismissal~~ | P3 | Fixed (follow-ups plan 21): the dismissal is stored on this device (`SharedPreferences`, `paris_notice_dismissed`) |
| Meal line in the chat list ellipsized at default size for some dates | P3 | Later polish |
| Language picker: re-tapping the selected option is not reachable by screen readers (the barrier still dismisses the dialog) | P3 | Follow-up (a11y) |
| `ci.yml` path filter does not include `l10n.yaml`, so a change to it alone does not trigger the PR gate | P3 | CI owner (`ci.yml`) |
| iOS: `CFBundleLocalizations` (en, fr) is declared in `Info.plist`; `fr.lproj/InfoPlist.strings` for `NSLocationWhenInUseUsageDescription` (and the other usage descriptions) is still missing, so the system permission prompts stay English. Needs an Xcode project change; do it before store submission | P2 | Follow-up (iOS, before store submission) |
| Native French review items beyond the table: `ratingBadgeNew` ("Nouveau"), "Ouvrir dans Maps" vs "Plans", "Nous"/"On" register, "Réglages", `createMealNoteLabel` ("Note (facultative)") | P2 | Native reviewer |
| Seeded demo content (restaurant names, bios, messages) stays English because it is data; user-written content is never translated | Info | none |
| The harness `_fr` map must follow `app_fr.arb` by hand (a changed French string shows up as a failed step, not silently) | P3 (tooling) | Harness |
| Carried over from plan 18 and not touched by this plan: Google "G" asset, Android phone auto-verification, `AppButton` loading colour, `RatingBadge` semantics, snackbar (notice) persistence (approved/denied/unblocked notices are lost when the screen is left), `93_discover_error` not producible | P2-P3 | See `docs/ux/18-verification.md` |
| ~~Post-meal rating card: the Rate button read "Rate Giulia Pe…"~~ | P3 | Fixed (follow-ups plan 21): short "Rate" / "Noter" button, the person is named in the card subtitle and the button's screen-reader label |
| ~~Joining a meal that just closed showed a generic failure~~ | P3 | Fixed (follow-ups plan 21): "This meal is no longer open." |
| ~~A write refused after the 3 s offline grace was only logged, so the user believed it went through~~ | P2 | Fixed (follow-ups plan 21): the user is told |
| ~~Meal detail was a static snapshot (a meal cancelled while open stayed "Request to join"; no "Meal ended" state)~~ | P2 | Fixed (follow-ups plan 21): live `meals/{id}` stream, new "Meal ended" state, deleted/hidden meal shows "This meal is no longer open." |

Widget-tested only (not seen in the capture): the language picker sheet and its live rebuild, the Settings licence page, the iOS notification row opening Settings, "Meal cancelled" on meal detail.
