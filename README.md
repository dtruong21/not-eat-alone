# not-eat-alone

Post a meal at a restaurant, match 1:1 with someone nearby, and don't eat alone.

## Run

Pinned via [FVM](https://fvm.app). Two flavors, `stage` and `prod`, each pointed at its own Firebase app registration and Firestore database:

```bash
fvm flutter run --flavor stage -t lib/main_stage.dart
fvm flutter run --flavor prod  -t lib/main_prod.dart
```

## Docs

- [Spec](docs/superpowers/specs/2026-09-18-not-eat-alone-v1-design.md)
- [Roadmap](docs/superpowers/plans/2026-09-18-not-eat-alone-roadmap.md)

## License

[MIT](LICENSE) © 2026 dtruong21
