# AI Chunks Settings Step 3 Implementation Record

## Requirement

- `docs/human/requirements/20260527-Feature-AI Chunks.md`

## Scope

- Use the AI Chunking prompt settings when sending the current request.
- Log request duration, rendered request content, and raw response content.
- Preserve the current provider-specific implementation naming; provider-neutral
  renaming is intentionally deferred to a future requirement.
- Keep cache-key changes and cache clearing for the next implementation step.

## Steps

1. Extended the AI Chunking client result with request trace fields.
   Result: successful requests now carry the rendered prompt, raw model content,
   and measured request-processing duration.
2. Measured duration inside the client around the API request-processing chain.
   Result: `duration_ms` covers the interval from immediately before the API
   request to after response decoding and AI chunk item validation.
3. Connected `AppCoordinator` to `SettingsStore.aiChunkingPromptConfiguration`.
   Result: the active Translation Language and Prompt template are used for new
   AI Chunking requests.
4. Extended `[AIChunking]` request logs.
   Result: successful completion logs include `duration_ms`, `request_content`,
   and `response_content`; failure logs include rendered `request_content` when
   available for the attempted request.

## Verification

- `swift test` passed from `apps/macos-native` with 145 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- Step 3 is implemented and verified.
