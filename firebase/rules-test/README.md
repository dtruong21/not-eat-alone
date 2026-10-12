# Firestore rules tests

Run against the local Firestore emulator (needs Java):

```bash
cd firebase/rules-test
npm install
npm test
```

`npm test` runs from the repo root, starts the Firestore emulator with the repo's `firebase.json` / `firebase/firestore.rules`, and runs `node --test`.
Not wired into CI yet.
