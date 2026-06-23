---
description: Scaffold a TanStack Query hook over a Firestore wrapper
argument-hint: <hook name> <collection> [query | single]
---

Create a hook at `features/<feature>/hooks/<hookName>.ts` for: $ARGUMENTS

Pattern:
- For a single doc: `useQuery({ queryKey: [collection, id], queryFn: () => get<Name>(id), enabled: !!id })`
- For a list: `useQuery({ queryKey: [collection, ...filters], queryFn: () => list<Name>s(filters) })`
- For mutations: `useMutation` wrapping `create/update/delete`, with `queryClient.invalidateQueries({ queryKey: [collection] })` on success
- For optimistic updates: use `onMutate` + `onError` rollback (apply only if the UX needs sub-100ms feedback)

Constraints:
- Import the wrapper from `lib/firebase/<collection>`. Never import the Firestore SDK directly.
- Return type: `{ data, isLoading, error, ... }` — same shape TanStack already provides.
- No business logic in the hook beyond wiring. Computation belongs in the component or a pure helper in `features/<feature>/`.
- If the hook accepts an id that could be undefined, gate the query with `enabled` instead of conditional calling.

Output: the file diff only.
