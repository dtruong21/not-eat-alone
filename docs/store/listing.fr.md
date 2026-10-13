# Convyve — Fiche App Store et Google Play, français (France)

**DRAFT: needs native French review.** Drafted by the developer, not a native speaker. Do not paste into App Store Connect or Google Play Console before a native speaker has read every field. Nothing here has been submitted.

*Last updated: 2026-10-13* · English counterpart: [`listing.md`](listing.md) · In-app French terminology: [`../l10n/FRENCH-REVIEW.md`](../l10n/FRENCH-REVIEW.md)

---

## Decisions for the owner

1. **Register: informal "tu".** The app speaks to people with "tu" (see `FRENCH-REVIEW.md`), so the listing does too, to keep one voice from the store page to the first screen. Apple and Google copy is often formal "vous"; a formal listing would be the safer, more corporate choice and would clash with the app. Pick one before submission; switching means rewriting every field below.
2. **Claims were cut to what the product does.** This text drops claims in the English listing that the shipped app does not support (cuisine and dietary fields, meal photo, "show-up records", "Free to use, forever", "more cities coming soon"). See "Verify before submission" in `listing.md`. If the owner wants any of them back, they must be built or re-worded first.
3. **"Convive" and "Hôte" are used as in the app** ("Convive" for a guest, "Hôte" for the host).
4. **"Rencontre" is deliberately not a keyword.** In French it reads as dating; the English listing avoids dating words for the same reason.
5. **Support, privacy and terms pages need French versions** (see "Support and legal URLs").
6. **App Store and Play consoles each need the `fr-FR` localization added** (Apple: App Information, add Localization French; Google Play: Main store listing, Manage translations).

---

## 1. Core metadata

### Nom de l'app
**Convyve** (not translated)

### Sous-titre (iOS App Store, max 30 caractères)
<!--field:subtitle:30-->
```
Partage un vrai repas
```

### Texte promotionnel (iOS, max 170 caractères)
<!--field:promo:170-->
```
Une table, une place de libre : trouve quelqu’un avec qui partager un vrai repas, dans un lieu public. Convyve, c’est à Paris pour l’instant.
```

### Description courte (Google Play, max 80 caractères)
<!--field:short:80-->
```
Poste un repas à Paris, choisis qui te rejoint, dîne ensemble. Sans swipe.
```

### Mots-clés (iOS, max 100 caractères, séparés par des virgules, sans espace)
<!--field:keywords:100-->
```
dîner,déjeuner,restaurant,sortie,convive,amis,manger,seul,solo,resto,inconnus,paris,gourmand
```

**Choices:** the app name and subtitle words (`partage`, `repas`, `convyve`) are not repeated, because Apple already indexes them. `rencontre`, `date` and `swipe`-type words are left out on purpose (meal-first, not dating). `paris` is kept because the launch is Paris-only. No spaces after commas, no duplicates (13 terms, 13 unique). Apple ignores accents when matching, so `dîner` also matches `diner`.

---

## 2. Description complète (App Store et Google Play, max 4 000 caractères)

Mirrors the structure of the English long description (intro, how it works, safety, Paris, age, why Convyve), minus the claims the product does not support.

<!--field:full:4000-->
```
Fini les repas en solo au restaurant.

Convyve est une appli sociale centrée sur le repas. Poste un repas dans un restaurant de Paris, choisis une seule personne parmi celles qui demandent à te rejoindre, discute pour faire connaissance, puis retrouve cette personne autour d’une vraie table. Pas de swipe, pas de groupe : un repas, deux personnes.

COMMENT ÇA MARCHE

• Poste : tu as repéré un bon restaurant ? Crée un repas : choisis le restaurant, la date et l’heure, et ajoute une note si tu veux.
• Demande : les personnes près de toi voient ton repas dans Découvrir et demandent à te rejoindre. Tu en acceptes une seule.
• Discute : dès que tu acceptes, un chat s’ouvre pour organiser le repas et faire connaissance. Des rappels t’arrivent la veille et environ 2 heures avant.
• Dîne et note : après le repas, dis si la personne était bien là et donne-lui une note pour aider les autres convives.

LA SÉCURITÉ D’ABORD

• C’est toi qui choisis : l’hôte accepte ou refuse chaque demande. Aucun match automatique.
• Entre femmes : l’hôte peut réserver un repas aux femmes (genre déclaré).
• Bloquer et signaler : à tout moment, pour une personne ou un repas.
• Des conseils de sécurité dans l’appli : lieu public, un proche prévenu, ton instinct.
• Ta vie privée : les autres voient seulement ton nom, tes photos, ta bio, ton âge et ta note. Ta date de naissance et ton genre restent privés.

PARIS, POUR COMMENCER

Convyve n’est disponible qu’à Paris pour l’instant. On démarre tout juste.

ÂGE ET CONDITIONS

Convyve est réservé aux personnes de 18 ans et plus. En créant un compte, tu acceptes les Conditions d’utilisation et la Politique de confidentialité.

PENSÉ POUR TOI

• Un design simple : pas de fouillis, juste des repas
• Gratuit, sans publicité ni achat intégré
• En français et en anglais
• Connexion avec Apple, Google ou ton numéro de téléphone
• Tes données t’appartiennent : supprime ton compte quand tu veux, directement dans l’appli

Télécharge Convyve et trouve ton prochain repas en bonne compagnie.
```

---

## 3. Catégorie

- **Principale :** Réseaux sociaux (Apple) / Social (Google Play)
- **Secondaire :** Style de vie (optionnel, Apple)

Category names are picked in the console and shown in the store's own language; nothing to translate here.

---

## 4. Classification d'âge

- **18+ uniquement.** L'app est réservée aux personnes de 18 ans et plus, avec une date de naissance déclarée à l'inscription (non vérifiée par une pièce d'identité). Answer the age-rating questionnaires per "Verify before submission" #5 in `listing.md` (expect 18+); the rating is set in the console, not in the French text.

---

## 5. Nouveautés (première version, valable pour toute version initiale)

Version-agnostic on purpose (no version number). Written to fit Google Play's 500-character limit (Apple allows 4 000).

<!--field:whatsnew:500-->
```
🍽️ Bienvenue sur Convyve !

Voici ce que tu peux faire dès maintenant :
• Poster un repas dans ton restaurant préféré
• Découvrir les repas près de chez toi
• Demander à rejoindre, l’hôte choisit une seule personne
• Discuter pour organiser le repas
• Recevoir un rappel avant le repas
• Noter la personne après le repas
• Proposer un repas entre femmes
• Bloquer et signaler, en toute tranquillité
• Supprimer ton compte quand tu veux

À Paris pour l’instant. On démarre tout juste.

Bon appétit !
```

---

## 6. Légendes des captures d'écran

Same as `tool/store_frames/captions.dart` (`fr`). Files: `docs/store/screenshots/fr/ios-6.9/` (1290 × 2796) and `docs/store/screenshots/fr/play-phone/` (1080 × 1920). A line break in the image is a space here.

1. `Trouve un repas près de chez toi`
2. `Le repas en détail, puis rejoins la table`
3. `L’hôte choisit une seule personne`
4. `Discute d’abord, dîne ensuite`
5. `La sécurité d’abord : bloque ou signale`

Re-check the stores' current screenshot size and count requirements at submission time; they change.

---

## 7. Support et pages légales (needs French pages)

| Champ | Valeur | État |
|---|---|---|
| URL d'assistance (Apple « Support URL ») | `https://convyve.com/support` (placeholder) | **needs a hosted web page**: App Store Connect requires a URL, not an email; ideally a French page |
| Politique de confidentialité | `https://convyve.com/fr/privacy` (placeholder) | **needs French page**; the English draft is `docs/legal/privacy.md`, DRAFT, legal review pending |
| Conditions d'utilisation | `https://convyve.com/fr/terms` (placeholder) | **needs French page**; English draft is `docs/legal/terms.md`, DRAFT, legal review pending |
| E-mail d'assistance | `support@convyve.com` (the address the app ships in Settings, `lib/core/config/legal_urls.dart:12`) | must be a monitored mailbox; use it as Google Play's contact email |

These URLs do not exist yet. The in-app legal links (`lib/core/config/legal_urls.dart:7-8`) point to the English URLs `https://convyve.com/privacy` and `/terms`; the `/fr/` URLs above are placeholders and the app does not link to them yet. French law (RGPD, Paris launch) makes a French privacy policy the owner's homework before submitting the `fr-FR` localization.

---

## 8. Vérification des nombres de caractères

Characters are Unicode characters, not bytes (`len()` on the decoded UTF-8 text; the non-breaking spaces before `:`, `!` and `?` count as one each). Re-run this from the repository root after any edit:

```sh
python3 -I - docs/store/listing.fr.md <<'PY'
import re,sys
t=open(sys.argv[1],encoding='utf-8').read()
for m in re.finditer(r'<!--field:(\w+):(\d+)-->\n```\n(.*?)\n```',t,re.S):
    n,l,v=m.group(1),int(m.group(2)),m.group(3)
    print(f"{n:10} {len(v):5} / {l:<5} {'OK' if len(v)<=l else 'OVER'}")
PY
```

Output at the time of writing:

```
subtitle      21 / 30    OK
promo        141 / 170   OK
short         74 / 80    OK
keywords      92 / 100   OK
full        2025 / 4000  OK
whatsnew     498 / 500   OK
```

The What's New field is checked against 500 characters (Google Play's limit; Apple allows 4 000).

---

## 9. Points à relire par une personne francophone

- Subtitle "Partage un vrai repas": is "vrai repas" natural? ("à deux" was dropped from the subtitle, short description and closing line because it can read as a couple/dating connotation; the body still says "un repas, deux personnes" and "en bonne compagnie" closes the description.)
- Promo text "Une table, une place de libre : ..." (a wordplay on a free seat at a table).
- "Sans swipe" in the short description (anglicism; the app avoids dating-app codes, but "sans swipe" may not mean much to everyone).
- "choisis qui te rejoint" (grammar is correct but "te rejoint" is slightly ambiguous: "who joins you").
- "Convive" for a guest and "Hôte" for the host, and the inclusive/neutral wording ("cette personne", "Entre femmes") instead of gendered forms.
- "Demander à te rejoindre" (the in-app button is "Demander à rejoindre").
- "ton nom, tes photos, ta bio" ("bio" as in the app).
- "Bon appétit !" closing line and the 🍽️ emoji in the What's New.
- Description opener "Fini les repas en solo au restaurant." (replaced a masculine "seul"; check it works as a hook).
- What's New line "Bloquer et signaler, en toute tranquillité".
- "Aucun match automatique" (anglicism "match", chosen over "rencontre") and "genre déclaré" (self-declared gender).
- Screenshot captions 2 ("Le repas en détail, puis rejoins la table") and 4 ("Discute d’abord, dîne ensuite").
- Overall "tu" register for a store page (decision 1 above).
