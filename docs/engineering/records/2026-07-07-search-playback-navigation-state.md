# Search Playback Navigation State

## Human-Owned Source

- `docs/human/requirements/20260707-Bug-Search Playback Result Navigation State.md`

## Scope

Fix Search-result playback previous and next command availability immediately
after opening a Search result.

## Classification

- Product semantics: Search-result navigation buttons now reflect the active
  Search result as soon as it is opened.
- Platform UI/UX: disabled transport state now matches the Search result order;
  keyboard feedback remains unchanged.
- Platform integration: unchanged.
- Playback execution: unchanged; this does not change video opening or subtitle
  track loading.

## Changes

- Updated Search-result previous and next fallbacks to use the selected result's
  `searchRank` when no navigation snapshot is available.
- Rebuilt the Search navigation snapshot synchronously when a Search result is
  opened, using loaded Search results or the existing navigation neighborhood.
- Added a regression test covering first-result and second-result transport
  availability immediately after opening playback.
- Updated product mapping to document immediate command availability after
  opening a Search result.

## Verification

- `git diff --check`
- `swift test --filter openingSearchResultUpdatesNavigationStateImmediately`
- `swift test --filter SearchStore`
- `swift test --filter searchNavigation`
- `swift test`

## Outcome

Search-result playback now updates the navigation snapshot immediately when a
result opens. The first Search result disables the previous command while still
allowing next when a next result exists, and the second result immediately
enables previous without waiting for an asynchronous navigation refresh.
