# Vocabulary Entrypoints Step 2 Implementation Record

## Requirement

- `docs/human/requirements/20260601-Feature-Vocabulary.md`

## Scope

- Implement the second vocabulary feature step: App state and topbar entry
  points.
- Add a Vocabulary workbench mode, Vocabulary store, coordinator loading action,
  and add-entry request state.
- Add topbar entry buttons for browsing Vocabulary and requesting add-entry
  creation.
- Keep the add-entry editor, two-column Vocabulary UI, Shiori-derived examples,
  and playback playlist behavior out of this step.

## Steps

1. Added `VocabularyStore` and injected it into the App environment.
   Result: Vocabulary state is owned separately from Search, Library, Shiori,
   and Playback state.
2. Added Vocabulary coordinator actions.
   Result: the App can hydrate persisted vocabulary entries and request the
   add-entry flow.
3. Added `vocabulary` to the workbench panel modes and topbar mode buttons.
   Result: the Vocabulary entry sits to the right of Shiori in the topbar.
4. Added the topbar add button.
   Result: the right-side `+` requests Vocabulary entry creation and switches
   the workbench to Vocabulary mode.
5. Added focused App coverage for the add-entry request action.
   Result: the second-step state transition is covered without implementing the
   editor UI.

## Verification

- `swift test --filter requestingVocabularyEntryCreationSelectsVocabularyModeAndPresentsEditor`
  passed from `apps/macos-native`.
- `swift test` passed from `apps/macos-native` with 171 Swift Testing tests
  and 7 XCTest tests. The run still emitted existing playback subtitle track
  and library history disk I/O log messages, but the full suite passed.

## Outcome

- Step 2 is implemented and verified. Vocabulary has App-owned state, a
  workbench mode, a topbar browse entry, and a topbar add-request entry. The
  editor UI, two-column Vocabulary UI, example derivation, and playback
  playlist behavior remain deferred to later steps.
