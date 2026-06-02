# Vocabulary Derived Shiori Examples - Step 5

Date: 2026-06-02

Human requirement: `docs/human/requirements/20260601-Feature-Vocabulary.md`

## Scope

- Added temporary derived vocabulary examples from existing Shiori rows.
- Matched examples by checking whether Shiori content contains the selected vocabulary term.
- Rendered example cards in the vocabulary detail examples section with a source row and subtitle content rows.
- Loaded Shiori rows when the vocabulary panel appears so examples do not depend on visiting the Shiori panel first.
- Reused Shiori display titles for example source rows when available.

## Boundary

- Did not change the vocabulary or Shiori database schema.
- Did not persist independent vocabulary example records.
- Did not implement manual example add/delete, duplicate manual examples, or example playback playlists.

## Verification

- `git diff --check` passed.
- `swift test --filter VocabularyStoreTests` passed.
- `swift test` passed.

## Outcome

- Step 5 is implemented as temporary derived Shiori examples for the vocabulary detail panel. Matching Shiori rows now render as example cards with a source row and grouped subtitle content, while entries without matches continue to show the empty examples state.
