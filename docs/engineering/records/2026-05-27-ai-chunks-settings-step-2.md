# AI Chunks Settings Step 2 Implementation Record

## Requirement

- `docs/human/requirements/20260527-Feature-AI Chunks.md`

## Scope

- Add Settings UI for the AI Chunking translation language.
- Add Settings UI for AI Chunking prompt editing.
- Preserve the existing DeepSeek API key settings behavior.
- Keep request logging, cache-key changes, and cache clearing for later
  implementation steps.

## Steps

1. Added an AI Chunking settings panel directly below the AI Chunking toggle.
   Result: the category now presents the toggle first, then Translation
   Language, then Prompt settings.
2. Added a Translation Language picker backed by `SettingsStore`.
   Result: the setting can be changed from the Experimental Features page and
   persists through the existing store behavior.
3. Added a Prompt text editor with editing state.
   Result: focusing or clicking the text editor reveals Default, Cancel, and
   Save actions; Save validates through `SettingsStore`, Cancel restores the
   saved prompt, and Default resets the draft to the built-in prompt.
4. Applied the disabled state for AI Chunking-dependent controls.
   Result: when AI Chunking is off, Translation Language and Prompt settings
   are dimmed and cannot be edited.

## Verification

- `swift test` passed from `apps/macos-native` with 145 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- Step 2 is implemented and verified.
