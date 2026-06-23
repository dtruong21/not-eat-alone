# Security & Secrets

How {{PROJECT_NAME}} handles secrets, what's safe to commit, and what isn't.

---

## TL;DR

| Item | Sensitive? | Where it lives | In git? |
|---|---|---|---|
| Firebase web config (apiKey, projectId, …) | **No** — public by design | `.env` locally | No (gitignored as hygiene) |
| Google OAuth Client IDs | **No** — public by design | `.env` | No, gitignored |
| Firestore Security Rules | Public (deployed) | `firestore.rules` | **Yes** — version-controlled |
| Cloud Function source | Public | `functions/src/` | **Yes** |
| Firebase Admin SDK service account JSON | **YES — secret** | NEVER on disk for client app | **NEVER commit** |
| Android signing keystore | **YES — secret** | EAS managed credentials | **NEVER commit** |
| iOS distribution certificate | **YES — secret** | EAS / Apple Developer | **NEVER commit** |
| OAuth Client **Secret** (if used) | **YES — secret** | EAS secret / Firebase | **NEVER commit** |

---

## What's NOT actually secret

### Firebase web config

`EXPO_PUBLIC_FIREBASE_API_KEY` looks like a secret. **It isn't.** Firebase web config values ship in every bundle of every Firebase app — anyone with the app can extract them in 30 seconds.

**Security comes from Firestore Security Rules + Firebase Authentication**, not from hiding the config. Rules in `firestore.rules` enforce:
- Users can only read/write their own data
- All paths gated on `request.auth.uid` matching the data owner
- Shared resources gated on membership

If an attacker has the Firebase API key but no valid auth token, rules deny every request.

### OAuth Client IDs

Client IDs are identifiers for the OAuth flow. They ship in client builds on purpose. The **client secret** (if used — token-based flows don't need one) WOULD be sensitive.

---

## What IS actually secret

### Firebase Admin SDK service account

If you generate a service account JSON for admin scripts (e.g. one-off migrations), **do not commit it**. It bypasses all security rules.

```bash
# DO: keep in a path that's gitignored
~/secrets/{{project}}-admin.json

# DON'T: project root
./service-account.json   # not gitignored — risk
```

Cloud Functions don't need a JSON file — `initializeApp()` with no args uses the function's runtime identity.

### Signing credentials

EAS manages iOS certs + Android keystores. Run `eas credentials` to view/manage. **Never** download to disk and commit.

---

## Local `.env` pattern

- `.env.example` is committed (template, empty values)
- `.env` is gitignored (actual values)
- Move machines: copy `.env` manually (password manager / encrypted note). Never paste secrets to Slack/email.

If you accidentally commit `.env`: rotate every value in it. Reality check: since none of the values are real secrets, an accidental commit is bad hygiene — not a breach.

---

## CI / deploy secrets

If you set up CI (GitHub Actions, Gitea Actions):

```bash
firebase login:ci    # generates a deploy token
```

Store as a repo secret. Reference as `FIREBASE_TOKEN` in the workflow YAML.

---

## Threat model

{{PROJECT_NAME}} stores personal user data — not financial, not health-protected, not regulated. The threat model is: a malicious user trying to read/write *another user's* data. Mitigated by Firestore rules + Firebase Auth. A leaked Firebase web config doesn't change the model. A leaked Cloud Function service account or signing key WOULD — those are the actual secrets, and they live with EAS / Firebase, not in this repo.

---

## Audit checklist (run before public launch)

- [ ] `git log --all -p -- .env` returns nothing
- [ ] `firestore.rules` deployed to prod (`firebase deploy --only firestore:rules`)
- [ ] Rules tested against Rules Playground or emulator — denies cross-user reads
- [ ] Account deletion cascade fires (test with throwaway account)
- [ ] No service account JSON in repo: `find . -name "*service-account*.json" -not -path "./node_modules/*"`
- [ ] Screenshots in store metadata contain no real personal data
