# Privacy Policy — Convyve

**DRAFT — This privacy policy is a draft and requires legal review before publishing.**

*Last updated: 2026-09-23*

---

## 1. Controller identity

**Convyve** (the "Service," "we," "us," or "our") is the data controller for your personal data. If you have questions about this privacy policy or our data practices, please contact us at:

**placeholder@convyve.com**

*Note: Replace the placeholder email with an actual legal contact before publishing.*

---

## 2. What data we collect

### Account & Profile

- **Account creation:** email address, phone number (authentication method)
- **Profile information:** display name, date of birth, age, gender, biography, profile photos (stored in Firebase Storage)
- **Authentication:** sign-in credentials via Firebase Auth (Google, Apple, or phone number); sign-in provider identifiers

### Location

- **Coarse location:** country, city, and geohash (via the Geolocator library) — used **only** to show meals and users near you on the Discovery feed. We do not collect precise GPS coordinates or track your real-time location.

### Service content

- **Meals:** meal name, date/time, cuisine, allergies/dietary notes, photos, restaurant/venue details, and participant list
- **Matches:** pairs of users who have matched (both expressed interest)
- **Messages:** direct messages between matched users
- **Ratings:** ratings you give to other users after a meal

### Device & platform

- **Device push tokens:** Firebase Cloud Messaging (FCM) tokens used to send you notifications (meal reminders, matches, new messages). Tokens are cleared when you delete your account or disable notifications.

### Analytics & diagnostics

- **Firebase Analytics:** app usage (screens viewed, feature interactions, session length, crash events)
- **Firebase Crashlytics:** crash dumps, stack traces, device OS version, app version (collected only if crashes occur; disabled in debug mode)

---

## 3. How we use your data

| Purpose | Data used | Legal basis |
|---------|-----------|-------------|
| **Provide the matching service** | Profile, location, meals, matches, messages | Performance of contract (your use agreement) |
| **Show you relevant meals & users** | Location, profile, meal data | Performance of contract |
| **Send notifications** | Device tokens, message/match events | Legitimate interest (service engagement) |
| **Prevent abuse & ensure safety** | Ratings, message history, IP addresses (via Firebase) | Legitimate interest (user safety) |
| **Improve the app** | Analytics events, crash reports, user feedback | Legitimate interest (service improvement) |
| **Comply with laws** | Any data necessary for legal/regulatory compliance | Legal obligation |

We do **not**:
- Use your data to train AI/ML models
- Sell your data to third parties
- Share meal content or ratings with advertisers
- Use your data for purpose creep

---

## 4. Who we share your data with

### Third-party processors (on your behalf)

- **Google Firebase**:
  - **Cloud Firestore:** stores all meal, match, message, and rating data (document database)
  - **Firebase Authentication:** manages sign-in and account authentication
  - **Cloud Storage:** stores your profile photos and meal images
  - **Cloud Functions:** executes server-side logic (match creation, notifications)
  - **Firebase Analytics:** collects usage analytics
  - **Firebase Crashlytics:** collects and reports crash data
  - **Cloud Messaging:** delivers push notifications
  
- **Google & Apple** (for sign-in only):
  - **Google Sign-In / Apple Sign-In:** if you authenticate via these providers, they receive your choice to sign in but do not receive your Convyve profile data (only a provider token)

All processors have signed Data Processing Addendums (DPAs) as part of Google's standard terms and are GDPR-compliant.

### Other sharing

- We do **not** share your data with advertisers, data brokers, or other unaffiliated third parties
- If legally required (court order, law enforcement), we will share the minimum data necessary and, where possible, notify you

---

## 5. Data retention & deletion

### Automatic retention

- **Active account data** (profile, meals, matches, messages, ratings): retained while your account is active
- **Deleted messages:** soft-deleted (marked as deleted in Firestore) but may remain in backups for up to 30 days
- **Analytics & crash data:** Firebase retains for up to 60 days by default
- **Push tokens:** retained until revoked or the app is uninstalled

### Account deletion

When you delete your account via **Settings → Delete Account**, we will:
- Permanently delete your account, profile photo, and personal data
- Depersonalize your meal posts (convert to "anonymous user meal")
- Depersonalize your ratings and review comments (remove your name)
- Depersonalize your messages (clear sender name; content may remain for other participants)
- Remove your profile from search and discovery
- Disable sign-in with your credentials

**Note:** You retain the right to request complete data deletion under GDPR; this account-deletion flow implements that right. See "Your rights" below.

---

## 6. Data security

### Technical measures

- **App Check**: Firebase App Check verifies that requests to your backend come from the genuine app (not from a hacked or forged client)
- **Firestore Security Rules**: all database access is scoped to the authenticated user (you can only read/write your own data, except for public meal/profile data visible to other users)
- **HTTPS/TLS**: all data in transit is encrypted
- **Firebase Storage rules**: your photos are private by default; only you and the service can access them

We do **not** encrypt your data at rest within Firebase by default; encryption at rest is available as a paid Firebase add-on and is not yet enabled (noted for future hardening).

---

## 7. International data transfers

Your data is processed by **Google Firebase**, which operates globally. When you use Convyve:
- Your data may be transferred to and stored in Google data centers **outside the EU** (e.g., the United States)
- Google has committed to Standard Contractual Clauses (SCCs) and other EU adequacy mechanisms for such transfers
- By using the app, you consent to this international transfer

---

## 8. 18+ requirement

Convyve is **not intended for users under 18**. We do not knowingly collect data from anyone under 18. If we become aware of data from a user under 18:
- We will delete that account and associated data within 30 days
- We may report the incident to a parent/guardian or relevant authorities as required by law

---

## 9. Your rights

Under **GDPR** (and equivalent EU/France data protection laws), you have the right to:

- **Access** (Art. 15): request a copy of all your personal data
- **Rectification** (Art. 16): correct inaccurate or incomplete data
- **Erasure** ("right to be forgotten," Art. 17): request deletion of your data (subject to lawful retention needs)
- **Restrict processing** (Art. 18): prevent processing of your data temporarily
- **Portability** (Art. 20): receive your data in a portable format (e.g., JSON export)
- **Object** (Art. 21): object to processing for marketing or analytics
- **Lodge a complaint** (Art. 77): contact your national data protection authority (e.g., **CNIL** in France: www.cnil.fr)

To exercise any of these rights, email us at **placeholder@convyve.com** and include "GDPR request" in the subject line. We will respond within **30 days**.

---

## 10. Cookies & tracking

Convyve is a **mobile app** and does not use HTTP cookies. However:
- **Firebase SDKs** may use **analytics cookies** if accessed via a web version (not currently available; noted for future expansion)
- **Third-party libraries** (Google, Apple, Firebase) may collect identifiers and usage data per their own privacy policies

---

## 11. Policy changes

We may update this privacy policy at any time. When we make material changes:
- We will update the "Last updated" date above
- We will notify you via in-app message or email
- Your continued use after the notification constitutes acceptance

---

## 12. Contact us

If you have questions, concerns, or wish to exercise your rights, contact:

**Convyve Legal/Privacy**
Email: **placeholder@convyve.com**

For GDPR/French data protection concerns, you may also lodge a complaint with:
**CNIL** (Commission Nationale de l'Informatique et des Libertés)
www.cnil.fr | complaint@cnil.fr

---

**This policy is a draft and is provided for internal review and legal counsel. Do not publish without legal review and sign-off.**
