---
description: Scaffold a Riverpod AsyncNotifier controller over a domain repository interface
argument-hint: <controller name> <feature> [single | list]
---

Scaffold an application-layer Riverpod controller for: $ARGUMENTS

Layer boundary (non-negotiable, see `docs/MASTER-SPEC.md` §2a): the controller lives in `lib/features/<feature>/application/` and depends on the domain repository INTERFACE via its provider (`<feature>RepositoryProvider`, e.g. from `.claude/commands/firestore.md` scaffolding) — never on the `data/` impl type or `cloud_firestore` directly. Reference implementation: `lib/features/onboarding/application/age_gate_controller.dart`.

Create the file at `lib/features/<feature>/application/<name>_controller.dart`. Use `@riverpod` codegen (`AsyncNotifier`-style via `_$<Name>Controller`) — never raw `FutureProvider` or `StateNotifier`.

### Pattern (mirrors `age_gate_controller.dart`)

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/features/<feature>/application/<feature>_providers.dart'; // <feature>RepositoryProvider

part '<name>_controller.g.dart';

@riverpod
class <Name>Controller extends _$<Name>Controller {
  @override
  Future<<Model>?> build(String id) async {
    return ref.watch(<feature>RepositoryProvider).watch(id).first;
  }

  /// Mutations use `AsyncValue.guard` so errors land in `state.error`
  /// instead of throwing — the screen renders them rather than crashing.
  Future<void> submit(<Model> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // `ref.read`, not `ref.watch` — this is after `build()`.
      await ref.read(<feature>RepositoryProvider).upsert(data);
      return data;
    });
  }
}
```

### List pattern (stream-backed collections)

```dart
@riverpod
class <Name>ListController extends _$<Name>ListController {
  @override
  Stream<List<<Model>>> build() {
    return ref.watch(<feature>RepositoryProvider).watchAll();
  }

  Future<void> create(<Model> data) async {
    final repo = ref.read(<feature>RepositoryProvider);
    await repo.upsert(data);
    // stream-backed: no manual invalidate needed
  }
}
```

### Orchestration across features (mirrors `age_gate_controller.dart`)

A controller MAY depend on more than one feature's repository interface when it's coordinating a cross-feature step (e.g. age-gate reads/writes `user` and signs out via `auth`) — it does NOT need to own a repository interface of its own. Consume each dependency's `<feature>RepositoryProvider` directly:

```dart
Future<void> submit(DateTime dob) async {
  if (!isAdult(dob)) {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return const <State>(blocked: true);
    });
    return;
  }
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async {
    final uid = ref.read(authRepositoryProvider).currentUser!.uid;
    await ref.read(userRepositoryProvider).upsertAgeVerified(uid: uid, dob: dob);
    return const <State>();
  });
}
```

Constraints:
- Import the repository ONLY via its interface's provider (`<feature>RepositoryProvider`, typed `Provider<XRepository>`) from `lib/features/<feature>/application/<feature>_providers.dart`. NEVER import a `*_repository_impl.dart` or `cloud_firestore` here.
- `ref.watch` only inside `build()`. After `build()`, use `ref.read` — this is rule #1 in the master spec.
- Errors propagate naturally through `AsyncValue.error`. Don't catch and swallow.
- Mutations use `AsyncValue.guard` to land errors back in `state` cleanly.
- Add `part '<name>_controller.g.dart';` for the `@riverpod` generator. Run `dart run build_runner build --delete-conflicting-outputs`.

Output: the file diff only.
