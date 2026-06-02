# Vocabulary Two-Column Layout - Step 4

Date: 2026-06-02

Human requirement: `docs/human/requirements/20260601-Feature-Vocabulary.md`

## Scope

- Replaced the temporary vocabulary list with a native two-column vocabulary panel.
- Kept the left column as full-content vocabulary cards ordered by the existing newest-first persistence query.
- Added a right-side detail area with the vocabulary term, explanation, collected time, and an examples section.
- Added an explicit empty examples state for this quick validation version.
- Added selection fallback so the newest entry is selected when vocabulary entries load without an existing valid selection.

## Boundary

- Did not change the vocabulary database schema.
- Did not implement derived Shiori examples or example playback playlists in this step.
- Did not add manual example editing, deletion, or persisted example records.

## Verification

- `git diff --check` passed.
- `swift test --filter VocabularyStoreTests` passed.
- `swift test` passed.

## Outcome

- Step 4 is implemented as the first complete vocabulary browsing layout: the vocabulary panel now has a left card list and right detail area, selected entries display their term, explanation, collected time, and an empty examples state, and invalid collected-time strings fail explicitly instead of falling back to a 1970 date.
