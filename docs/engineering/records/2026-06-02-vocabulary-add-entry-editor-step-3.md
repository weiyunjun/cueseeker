# Vocabulary Add Entry Editor - Step 3

Date: 2026-06-02

Human requirement: `docs/human/requirements/20260601-Feature-Vocabulary.md`

## Scope

- Added a native add-vocabulary sheet opened from the existing topbar plus entry.
- Added term and explanation inputs, including a multiline explanation editor.
- Added coordinator save handling that trims submitted text, persists through the existing vocabulary entry database API, refreshes the store, selects the new entry, and closes the editor.
- Added a minimal vocabulary card list so saved entries are visible before the later full two-column layout step.

## Boundary

- Did not change the vocabulary database schema.
- Did not implement derived Shiori examples, example playback playlists, manual example editing, or the final two-column details layout.

## Verification

- `git diff --check` passed.
- `swift test --filter VocabularyStoreTests` passed.
- `swift test` passed.

## Outcome

- Step 3 is implemented as a quick validation path for adding vocabulary entries. The entry editor can be opened from the topbar plus button, cancellation closes the editor, confirmation persists the entry through the existing vocabulary storage API, and the saved entry is visible in the vocabulary panel.
