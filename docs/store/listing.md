# Convyve — App Store & Google Play Listing (DRAFT)

**DRAFT — Refine, review for accuracy, and upload at submission. All sections require final review before publication.**

*Last updated: 2026-09-23*

---

## 1. Core Metadata

### App name
**Convyve**

### Subtitle (iOS App Store, ≤30 characters)
```
Don't eat alone
```
*(29 characters)*

### Short description (Google Play, ≤80 characters)
```
Meet over a meal — post a table, match 1:1, dine together.
```
*(60 characters)*

### Promotional text / One-liner
```
Never eat at a restaurant alone again. Find your dining companion.
```

---

## 2. Keywords for ASO (iOS App Store, ~100 characters, comma-separated, no spaces wasted)

```
meal,dinner,dining,solo,restaurant,friends,meet,social,table,foodie,companion,paris
```
*(92 characters, excluding comma-spaces)*

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

### Screenshot 1: Discovery Feed
**Image:** Browse meals posted by nearby users in your city.
**Caption:**
```
Find meals near you. Browse restaurants and discover dining companions in your area.
```

### Screenshot 2: Meal Detail
**Image:** View full meal details, cuisine, dietary notes, and request to join.
**Caption:**
```
See the full meal — restaurant, time, cuisine, and host profile. Request to join.
```

### Screenshot 3: Request & Match
**Image:** Send a request; host approves one companion.
**Caption:**
```
Send a request. The host picks one match. No group chaos, just two diners.
```

### Screenshot 4: Chat
**Image:** Direct messaging with your matched companion.
**Caption:**
```
Chat to plan the meal. Get to know your companion before you meet.
```

### Screenshot 5: Ratings & Safety
**Image:** Rate and review companions; see others' ratings before matching.
**Caption:**
```
Rate your companion. See ratings and build trust. Safety at the core.
```

---

## 7. What's New (First Release, v1.2.0)

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
- [ ] Screenshots are high-quality, localized (English), and match captions
- [ ] Privacy Policy and Terms of Service hosted and reachable from Settings
- [ ] App version (`package_info_plus` / `lib/main.dart`) is `1.2.0` or consistent with the store submission
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
3. **Marketing assets**: Generate or design the 5 screenshots. Ensure they are high-res, English (or localized per store), and match captions. Both stores have specific size requirements:
   - **App Store:** 6.5" (1284 × 2778 px) or 5.5" (1125 × 2436 px) iPhone screenshots
   - **Google Play:** Landscape (1024 × 500 px) or portrait (1080 × 1920 px) phone screenshots
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
