# Search State Ownership Refinement

## Requirement

- `docs/human/requirements/20260727-Engineering-Search State Ownership Refinement.md`
- `docs/human/design/Command Panel.md`

## Scope

Refine the native macOS Search ownership boundary without changing Search,
Filter, Context, pagination, selection, or playback behavior.

## Steps

1. Removed the obsolete grouped/card Search result presentation state, actions,
   per-file loading tasks, export entry point, performance hooks, and tests.
2. Preserved Search file summaries because exact counts, table hydration, and
   playback title fallback still consume them.

## Verification

- `swift test --filter SearchStoreTests`
- Result: 20 tests passed.

## Outcome

The unified result table remains the only production Search result presentation
path. The first refinement step matched expectations.

## Follow-ups

- Move Search query lifecycle state and database access into `SearchStore`.
- Restrict Search state mutation to intent-oriented APIs.
