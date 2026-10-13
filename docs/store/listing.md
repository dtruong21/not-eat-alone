# Convyve — App Store & Google Play Listing (DRAFT)

**DRAFT — Refine, review for accuracy, and upload at submission. All sections require final review before publication.**

*Last updated: 2026-10-13* · French version: [`listing.fr.md`](listing.fr.md) (DRAFT, needs native review)

---

## Verify before submission

The English text below was drafted before the app shipped and was checked against `docs/PRD.md`, `CHANGELOG.md` and the app strings on 2026-10-13. These promises do not match the product (or are not decided). The text is left as written so the owner can choose; the French draft already drops them.

| # | Where | What the text says | What the product does | Suggested fix |
|---|---|---|---|---|
| 1 | Long description, "Free to use, forever"; positioning statement ("free") | Free forever | PRD: v1 is free; ads/subscription are only deferred ("later"). No in-app purchases or ads today. | "Free to use. No ads, no in-app purchases." Do not promise "forever". |
| 2 | Long description, "Ratings & show-up records ... rate and review their companions before matching"; What's New "Rate and review"; screenshot 5 (old) | Users see ratings, reviews and show-up records before matching | Ratings (stars, average and count) show on profiles, meal host, requests and chat. After a meal people are asked "Did they show up?" but show-up is never displayed to others. Written comments are not shown (PRD defers "Comments on ratings"). | "Ratings: see a diner's average rating before you accept or request." Drop "reviews" and "show-up records". |
| 3 | Long description, "Post" bullet | "date, time, cuisine, dietary notes, and add a photo" | Create a meal = restaurant (Paris search), date/time and an optional note. No cuisine or dietary field, no meal photo (profile photos only). | "Post the meal: restaurant, date, time and a note." |
| 4 | Long description + What's New: "more cities coming soon" | A promise of expansion | PRD: geo-expansion is post-v1, not scheduled. The app only says "we're just getting started here". | "We're just getting started." Keep the promise only if the owner commits. |
| 5 | Section 5 and checklist: "Expected rating: 17+ ... appeal to 4+" | Apple 17+ | The questionnaire and age tiers change (Apple has moved to 13+/16+/18+). The app is 18+ (self-declared date of birth, not verified). | Answer the current questionnaire in App Store Connect; expect 18+ and do not appeal to 4+. |
| 6 | Long description: "Women-only meals" | Reads as guaranteed women-only | Women-only is self-declared gender in v1 (PRD), enforced by rules but not identity-verified. | Keep, but the privacy policy / FAQ must say gender is self-declared. |
| 7 | Long description: "18 and older" | Reads as verified | Age gate is self-attested; no ID check (PRD). | Wording is fine; never say "verified". |
| 8 | Section 8 checklist: "Settings > Delete Account (permanent, instant)", "Your data is yours ... instantly" | All data removed instantly | Ratings are kept after deletion (section 11, privacy policy). | Reword as "delete your account anytime"; keep the ratings note in the privacy policy. |
| 9 | Section 10: "App version is `1.2.0`" | 1.2.0 | `pubspec.yaml` is `1.1.0+2`. | Fixed below: "consistent with `pubspec.yaml`". No version bump was made here. |
| 10 | PRD open question (Apple 1.2 / Google UGC) | n/a | No automated profanity/image moderation; reviewers may reject. | See PRD "Moderation" decision; have a blocklist fallback ready. |
| 11 | Counts under Subtitle, Short description, Keywords | 29 / 60 / 92 characters | Actual: 15 / 58 / 83. | Corrected above. |

---

## 1. Core Metadata

### App name
**Convyve**

### Subtitle (iOS App Store, ≤30 characters)
```
Don't eat alone
```
*(15 characters)*

### Short description (Google Play, ≤80 characters)
```
Meet over a meal — post a table, match 1:1, dine together.
```
*(58 characters)*

### Promotional text / One-liner
```
Never eat at a restaurant alone again. Find your dining companion.
```
*(66 characters; the iOS limit is 170)*

---

## 2. Keywords for ASO (iOS App Store, ~100 characters, comma-separated, no spaces wasted)

```
meal,dinner,dining,solo,restaurant,friends,meet,social,table,foodie,companion,paris
```
*(83 characters, counted with `len()`; limit 100)*

**Rationale:** Targets meal discovery, social dining, and Paris soft-launch. Avoids dating app keywords (swipe, match, etc.) to signal meal-first positioning and stay compliant with App Store social-app rules.

---

## 3. Full Description

### App Store & Google Play Long Description

```
Never eat at a restaurant alone again.

Convyve is a free, meal-first social app. Post a table you've booked or found, match with one other diner near you, chat to get to know them, and meet over a real meal. No swiping. No groups. Just one-on-one dining.

HOW IT WORKS

• Post: You find a great restaurant and book a table. Open Convyve, post the meal (date, time, cuisine, dietary notes), and add a photo.
• Match: Nearby users see your meal and request to join. You choose one person you'd like to dine with.
• Chat: Message your match directly to plan the meal and get to know each other.
• Meet & Rate: Dine together, and rate your companion to help others find reliable diners.

SAFETY FIRST

We prioritize your safety in three ways:
• Women-only meals: Host a meal open only to women if you prefer.
• Block & report: Report inappropriate behavior or block users you don't want to see again.
• Ratings & show-up records: See how other users rate and review their companions before matching.

PARIS SOFT-LAUNCH

Convyve is currently available in Paris only as we grow. We're just getting started here — more cities coming soon.

AGE REQUIREMENT & POLICY

Convyve is for users 18 and older. By creating an account, you agree to our Terms of Service and Privacy Policy.

DESIGNED FOR YOU

• Simple, intuitive design — no clutter, just meals
• Free to use, forever
• Your data is yours — delete your account anytime, instantly

Download Convyve and find your next dining companion.
```

---

## 4. Category

- **Primary:** Social (Apple) / Social & Messaging (Google Play)
- **Secondary:** Lifestyle (optional)

---

## 5. Age Rating & Restrictions

- **Age Rating:** 18+ (Mature audience)
- **ESRB:** Not Rated (mobile rating only applies)
- **Content Descriptors:** None (no violence, sexual content, or other ESRB-flagged content)

---

## 6. Screenshots & Captions (5 total, in order)

Framed screenshots are committed under `docs/store/screenshots/` (real captures of the real app, demo data, coral background with caption). Regenerate with `tool/store_frames/` (see its README).

| Store | Folder (English) | Size |
|---|---|---|
| App Store, iPhone 6.9" | `docs/store/screenshots/en/ios-6.9/` | 1290 × 2796 px |
| Google Play, phone portrait | `docs/store/screenshots/en/play-phone/` | 1080 × 1920 px |

French set: `docs/store/screenshots/fr/` (same names and sizes; captions in `listing.fr.md`). PNG, opaque RGB (no alpha), 20 files in total.

**Re-check the stores' current screenshot size and count requirements at submission time; they change.**

| # | File | Shows | Caption (identical to `tool/store_frames/captions.dart`) |
|---|---|---|---|
| 1 | `01_discover.png` | Discover feed | `Find meals near you` |
| 2 | `02_meal_detail.png` | Meal detail with "Request to join" | `See the full meal, then ask to join` |
| 3 | `03_requests.png` | Requests inbox, host picks one | `Hosts pick one match. No group chaos` |
| 4 | `04_chat.png` | Chat with the match | `Get to know them before you meet` |
| 5 | `05_safety.png` | Safety tips sheet (block / report) | `Safety built in: block or report` |

(Caption lines are broken in the image; shown on one line here.) Screenshot 5 replaces the old "Ratings & Safety" idea: see "Verify before submission" #2.

---

## 7. What's New (First Release)

```
🍽️ Welcome to Convyve!

This is our first release. You can now:
• Post meals at your favorite restaurants
• Discover dining companions near you
• Match one-on-one for a real meal
• Chat to plan your dinner
• Rate and review your companions
• Host women-only meals if you prefer
• Block and report to stay safe
• Delete your account anytime

Paris only for now — more cities coming soon.

Enjoy your meal!
```

---

## 8. Submission Checklist

### Legal & Compliance

- [ ] **Privacy Policy URL**: `https://convyve.com/privacy` (hosted; currently in `docs/legal/privacy.md` — DRAFT, needs legal review before hosting)
- [ ] **Terms of Service URL**: `https://convyve.com/terms` (hosted; currently in `docs/legal/terms.md` — DRAFT, needs legal review)
- [ ] **Support/Contact URL**: `placeholder@convyve.com` (email, configure in both store consoles)
- [ ] **Privacy Policy**: Review `docs/legal/privacy.md` (DRAFT). Verify sections on data collection, retention, deletion, GDPR rights, and 18+ policy align with the app.
- [ ] **Terms of Service**: Review `docs/legal/terms.md` (DRAFT). Verify 18+ age gate, user conduct, safety disclaimer, and no liability for real-world meetups.

### Age Rating & Data Safety

#### App Store (iOS) — Age Rating Questionnaire
Answer in App Store Connect > App Information > Age Rating:
- [ ] "Frequent/Intense" graphic violence? **No**
- [ ] Cartoon/fantasy violence? **No**
- [ ] Frequent/intense adult content? **No**
- [ ] Prolonged scenes of violence? **No**
- [ ] Realistic violence? **No**
- [ ] All other categories? **No**
- **Expected rating:** 17+ (due to social interaction with adults / potential safety concerns in real-world meetups). *Note: If rated 17+, submit for review to confirm or appeal to 4+.*

#### Google Play — Data Safety Form
Complete in Google Play Console > App Content > Data Safety:

**Data types collected:**
- [ ] Personal info (name, email, phone, date of birth, gender, biography)
- [ ] Photos (user uploads)
- [ ] Location (coarse city/geohash, not GPS)
- [ ] Messages (direct messages between matches)
- [ ] Device ID (Firebase tokens)
- [ ] Analytics (Firebase Analytics — usage, crashes)

**Data sharing:**
- [ ] Shared with third parties: **Yes** — Google Firebase (Firestore, Auth, Storage, Analytics, Crashlytics, Cloud Messaging)
- [ ] Shared with unaffiliated third parties? **No**

**Data retention:**
- [ ] Profile & meal data: While account is active
- [ ] Messages: While account is active
- [ ] Ratings: Retained post-deletion for integrity (noted in privacy policy; can be deleted via GDPR erasure request)
- [ ] Analytics: Per Firebase's standard retention
- [ ] Device tokens: Cleared on account deletion

**User control:**
- [ ] Option to delete account? **Yes** — in-app via Settings > Delete Account (permanent, instant)
- [ ] Option to request data export? **No** (noted as future — currently manual GDPR request)

**Restrictions:**
- [ ] Restricted to minors? **Yes, 18+ only** (via age gate at sign-up; enforced via birthdate validation)

---

## 9. Demo Account for Review (Recommended)

**App Store & Google Play review teams may request test credentials.** Provide:

- **Demo Account Email:** `demo@convyve.test` (or similar; configure before submission)
- **Password:** [Configure a stable demo account in Firebase Auth; use a strong password]
- **Pre-populated data:** Create a few test meals, a match, and sample messages for the reviewer to explore without friction.
- **Note in submission:** "Demo account available upon request. Please use `demo@convyve.test` to test the full flow (post a meal, match, chat, rate)."

---

## 10. Pre-Submission Verification

### Code & Build
- [ ] Signed release APK/IPA generated locally (no store signing yet)
- [ ] App builds successfully with `flutter build apk --release` (Android) and `flutter build ios --release` (iOS)
- [ ] No native build warnings or errors
- [ ] `flutter analyze` passes (zero critical warnings)
- [ ] All `@TypedGoRoute` navigation works; no broken deep links

### Content & Metadata
- [ ] App name, subtitle, description, and keywords proofread for typos and consistency
- [x] Screenshots are high-quality and match captions (framed EN and FR sets generated, see section 6). Re-check store size requirements at submission.
- [ ] **Localizations**: French listing drafted in [`listing.fr.md`](listing.fr.md) (DRAFT: native French review needed). French privacy policy, terms and support pages are the owner's homework. Add the `fr-FR` localization in both store consoles and upload `screenshots/fr/`.
- [ ] Privacy Policy and Terms of Service hosted and reachable from Settings
- [ ] App version (`package_info_plus` / `lib/main.dart`) matches `pubspec.yaml` (currently `1.1.0+2`) and the store submission
- [ ] Privacy policy and terms are **legally reviewed** (currently DRAFT)

### Functionality
- [ ] Sign-up flow (Google / Apple / phone) works and enforces 18+ birthdate
- [ ] Discovery feed loads meals and filters by location (Paris geohash)
- [ ] Meal posting, request, match, and chat flows are end-to-end functional
- [ ] Ratings, block/report, and women-only meal filters work
- [ ] Settings screen accessible; Privacy Policy, Terms, and account deletion reachable
- [ ] No crashes or unhandled exceptions (Crashlytics clean)
- [ ] Push notifications (optional) are disabled or have opt-in UX (if enabled, test APNs / Firebase Cloud Messaging setup)

### Store Compliance
- [ ] App Store category: Social; content rating: 17+ or 4+ (pending review)
- [ ] Google Play category: Social & Messaging; content rating: All / Mature (pending review; depends on data-safety questionnaire response)
- [ ] Both store policies reviewed:
  - [ ] App Store: No dating/swipe app marketing (accurate — meal-first, 1:1, not dating)
  - [ ] Google Play: Compliant with community guidelines (no hate speech, fraud, or safety violations)

### Analytics & Observability
- [ ] Firebase Analytics events fire correctly (check dashboard for activity post-sign-up)
- [ ] Crashlytics enabled and reporting crashes (if any) — dashboard clean at launch
- [ ] App Check enforcement ready (token generation working; enforcement is a post-submission console toggle)

---

## 11. Known Limitations & Transparency Notes

- **Soft Paris-only gating:** Discovery is geohash-filtered to Paris; a soft dismissible notice appears on the feed ("Convyve is Paris-only for now — we're just getting started here"). No hard location block. This is a soft-launch stance, not enforced by the backend.
- **1:1 matching only:** The app enforces one-on-one matches (host picks one requester; no groups). This is a pillar feature and clearly communicated.
- **Women-only meals:** Available as a host option; hosted meals can be marked "Women only" to restrict who can request. Filtering on the Discovery side is optional.
- **Ratings retention:** Ratings are retained after account deletion to preserve recommendations. Users can request deletion via GDPR erasure (contact provided).
- **No swipe/dating positioning:** The app is meal-first and positioned as social dining, not a dating app. Marketing and store metadata reflect this.
- **No payment/premium tiers:** v1 is fully free with no in-app purchases or ads.
- **No real-time location tracking:** Only coarse geohash is used; exact GPS coordinates are never collected or stored.

---

## 12. Drafting Notes & TODOs for the User

Before uploading to App Store and Google Play:

1. **Customize URLs**: Replace `https://convyve.com/privacy`, `/terms`, and `placeholder@convyve.com` with real, hosted URLs and a monitored email address.
2. **Legal review**: Have a lawyer review `docs/legal/privacy.md` and `docs/legal/terms.md`. Ensure GDPR compliance (Paris/France), age-gating, and safety disclaimers are correct.
3. **Marketing assets**: The 5 screenshots per language are done (section 6). Re-check each store's current size and count requirements at submission; the sets use:
   - **App Store:** 6.9" iPhone, 1290 × 2796 px
   - **Google Play:** portrait phone, 1080 × 1920 px
4. **App icon**: Ensure icon is 1024 × 1024 px, follows store guidelines (no rounded corners, safe-zone padding), and is uploaded to both consoles.
5. **Demo account**: Create a stable test account in Firebase; provide credentials to both store review teams.
6. **Build signing**: Generate signed APK (Android) and IPA (iOS) using your private keys / certificates. Store the keys securely.
7. **App Store specific**:
   - [ ] Provide App Store Connect credentials or invite Apple to review via invitation
   - [ ] Complete "App Privacy" section in App Store Connect (privacy questions align with the privacy policy)
   - [ ] Respond to the age-rating questionnaire (likely 17+ for social interaction with real-world meetups; coordinate with legal)
   - [ ] Submit for review and monitor for feedback
8. **Google Play specific**:
   - [ ] Complete "Data Safety" questionnaire (sections outlined in this checklist)
   - [ ] Set content rating via IARC (all three questionnaires)
   - [ ] Upload signed APK or AAB (Android App Bundle)
   - [ ] Submit and monitor for review

---

## Appendix: ASO & Positioning

### ASO Strategy

**Primary keywords** (high search volume, high relevance):
- `meal`, `dinner`, `dining`, `restaurant`, `friends`, `social`

**Secondary keywords** (niche, soft-launch relevance):
- `solo`, `table`, `companion`, `foodie`, `paris`

**Why not included:**
- `dating`, `swipe`, `match`: Position as meal-first, not dating. Reduces App Store social-app policy risk.
- `groups`, `parties`: Feature is 1:1 only; no groups.
- `app`, `download`: Generic noise; avoids clutter.

### Positioning Statement

"Convyve is a free, meal-first social app for solo diners and friends who want to share a restaurant experience. Post a table, match one-on-one with a nearby diner, chat to plan, and meet over a real meal. No swiping, no groups. Safety-first with women-only meals, ratings, and reporting. Paris-only soft launch. 18+."

---

**END OF DRAFT**
