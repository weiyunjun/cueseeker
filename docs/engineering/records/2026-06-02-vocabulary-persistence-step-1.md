# Vocabulary Persistence Step 1 Implementation Record

## Requirement

- `docs/human/requirements/20260601-Feature-Vocabulary.md`

## Scope

- Implement the first vocabulary feature step: minimal vocabulary-entry
  persistence.
- Add storage for term, explanation, and created-at time.
- Keep UI, temporary Shiori-derived examples, playback wiring, and any shared
  group/example backend abstraction out of this step.

## Steps

1. Added a `VocabularyEntry` model in `CueSeekerCore`.
   Result: vocabulary entries have an id, term, explanation, and created-at
   timestamp.
2. Added the `vocabulary_entries` table and created-at ordering index.
   Result: vocabulary entries persist independently from subtitle, Shiori, and
   playback data.
3. Added `addVocabularyEntry` and `vocabularyEntries` database APIs.
   Result: duplicate terms can be inserted as separate records and loaded in
   newest-first order.
4. Added focused database coverage for duplicate terms and created-at ordering.
   Result: the product boundary from the human requirement is covered without
   adding example persistence or UI behavior.

## Verification

- `swift test --filter storesVocabularyEntriesAndAllowsDuplicateTerms` passed
  from `apps/macos-native`.
- `swift test` passed from `apps/macos-native` with 170 Swift Testing tests
  and 7 XCTest tests. The run still emitted existing playback subtitle track
  and library history disk I/O log messages, but the full suite passed.

## Outcome

- Step 1 is implemented and verified. Vocabulary entries can be persisted with
  duplicate terms and loaded newest-first, with no UI, example persistence, or
  backend group abstraction changes in this step.
