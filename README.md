# Convyve

Post a meal at a restaurant, match 1:1 with someone nearby, and don't eat alone.

## Run

Pinned via [FVM](https://fvm.app). Two flavors, `stage` and `prod`, each pointed at its own Firebase app registration and Firestore database:

```bash
fvm flutter run --flavor stage -t lib/main_stage.dart
fvm flutter run --flavor prod  -t lib/main_prod.dart
```

## End-to-end tests

The `integration_test/` suite drives the real app on an iOS Simulator against the Firebase Emulator Suite (no real Firebase project needed).

Prerequisites: Xcode + an iOS Simulator runtime, Node 22, Java 21+, [`firebase-tools`](https://firebase.google.com/docs/cli), FVM, and a dedicated simulator named `Convyve E2E`, created once with `xcrun simctl create "Convyve E2E" <iPhone devicetype id> <iOS runtime id>` (ids from `xcrun simctl list devicetypes` / `runtimes`).

```bash
make e2e
```

Note: `make e2e` copies the **prod** `GoogleService-Info.plist` into the gitignored `ios/Runner/` and leaves it there, so a later unflavored local `flutter run` would use the prod app registration; delete `ios/Runner/GoogleService-Info.plist` to undo it (prefer `--flavor` runs, which copy the right file).

See [docs/TEST-PLAN.md](docs/TEST-PLAN.md#end-to-end-tests-emulator) for coverage, setup details and known flakes.

## Docs

- [Spec](docs/superpowers/specs/2026-09-18-not-eat-alone-v1-design.md)
- [Roadmap](docs/superpowers/plans/2026-09-18-not-eat-alone-roadmap.md)

## License

[MIT](LICENSE) © 2026 dtruong21
