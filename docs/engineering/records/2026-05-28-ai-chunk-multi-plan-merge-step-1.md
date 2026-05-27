# AI Chunk Multi-Plan Merge Step 1 Implementation Record

## Requirement

- `docs/human/requirements/20260528-Feature-AI Chunk Multi Plan Merge.md`

## Scope

- Update the default AI Chunking prompt to the new Japanese multi-plan prompt.
- Force existing saved AI Chunking prompt templates, including user-customized
  templates, onto the new default prompt once.
- Bump the AI Chunking base prompt version so old single-plan cache entries are
  not reused for the new prompt contract.
- Keep response parsing, chunk validation, multi-plan merging, UI behavior, and
  text normalization for later implementation steps.

## Steps

1. Replaced the default prompt template with the multi-plan Japanese learning
   chunking prompt.
   Result: the rendered default prompt now asks for `plans` containing
   translated `items`.
2. Bumped `DeepSeekChunkingClient.promptVersion` from `chunk-v1` to `chunk-v2`.
   Result: AI Chunking cache keys naturally separate old single-plan results
   from new multi-plan requests.
3. Added a one-time default prompt version marker in Settings.
   Result: older saved prompt templates are overwritten with the new default on
   first launch, while later user edits continue to persist normally.
4. Added tests for the rendered default prompt, cache prompt version, and
   one-time prompt reset behavior.
   Result: the configuration-layer behavior for this step is covered before
   response parsing changes begin.

## Verification

- `swift test` passed from `apps/macos-native` with 149 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- Step 1 is implemented and verified.
