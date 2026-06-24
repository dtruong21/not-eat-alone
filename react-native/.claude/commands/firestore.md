---
description: Scaffold a typed Firestore collection wrapper
argument-hint: <collection name> [field1:type field2:type ...]
---

Create a Firestore wrapper at `lib/firebase/<collection>.ts` for: $ARGUMENTS

Required exports:
- `<Name>Schema` — zod schema matching the document shape (use the field:type pairs from args)
- `<Name>` — TypeScript type inferred from the schema
- `<name>Path(...args)` — path helper as a constant at top of file
- `get<Name>(id)` — single doc fetch, parses with zod
- `list<Name>s(parent?)` — collection query, parses each doc
- `create<Name>(data)` — typed write, returns the new doc id
- `update<Name>(id, patch)` — partial update via `updateDoc`
- `delete<Name>(id)` — soft delete via `archivedAt` if the schema has it, hard delete via `deleteDoc` otherwise

Constraints:
- Use Firebase v10+ modular API (`getDoc`, `collection`, etc.) — never namespaced.
- Parse every doc with zod at the boundary. Throw `new Error("<Name> doc <id> failed schema: ...")` on parse failure.
- All timestamps use `serverTimestamp()` on write; on read, convert to JS `Date` inside the zod transform.
- Import the firebase client from `lib/firebase/client.ts`. Never call `initializeApp` here.

Output: the file diff only. No explanation.
