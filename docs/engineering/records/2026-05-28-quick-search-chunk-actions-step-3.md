# Quick Search Chunk Actions Step 3 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-Quick Search Chunk Actions.md`

## Scope

- Implement Quick Search sentence action selection for `/chunk`, `/rechunk`,
  and `/copy`.
- Keep the sentence action row as one vertical focus stop while allowing
  left/right selection between its buttons.
- Copy only the displayed Quick Search sentence, not the active playback cue
  selection.
- Reuse the existing playback subtitle copy feedback HUD after Quick Search
  copy execution.

## Steps

1. Added a Quick Search `.copy` action option.
   Result: the sentence action row can represent both the chunk action and copy
   action without adding a new focus target.
2. Changed option-stop modeling so the sentence action row is one vertical stop.
   Result: up/down navigation enters the row with `/chunk` or `/rechunk`
   selected by default, while left/right cycles between that action and
   `/copy`.
3. Updated Quick Search rendering to show the selected state on either the
   chunk action or `/copy`.
   Result: both buttons reuse the same command-label visual helper introduced
   in step 2.
4. Added `copyQuickSearchCurrentSentenceToClipboard()`.
   Result: Enter on `/copy` writes only the displayed Quick Search sentence to
   `NSPasteboard` and then calls the existing subtitle-copy feedback method.
5. Added PlaybackStore coverage for action-row left/right cycling and default
   action selection when entering the sentence row from cached chunks.
   Result: the new keyboard selection behavior is covered without involving
   real pasteboard state.

## Verification

- `git diff --check` passed.
- First `swift test` run compiled the code but hit the existing intermittent
  `SettingsStore.swift:199` `NSApp` optional crash.
- A second `swift test` run passed from `apps/macos-native` with 163 Swift
  Testing tests and 7 XCTest tests.
- The passing test run still emitted existing playback-history disk I/O log
  messages, but the full suite passed.

## Outcome

- Step 3 is implemented and verified.
