# AI Chunks Settings Step 1 Implementation Record

## Requirement

- `docs/human/requirements/20260527-Feature-AI Chunks.md`

## Scope

- Add the first implementation step for AI Chunking settings.
- Introduce a persisted translation language setting.
- Introduce a persisted prompt template setting.
- Add default prompt template, placeholder validation, and prompt rendering.
- Keep UI wiring, request logging, cache-key changes, and cache clearing for
  later implementation steps.

## Steps

1. Added AI Chunking prompt configuration types.
   Result: the supported translation languages are represented as stable
   values, and prompt templates can validate and render `{{sentence}}` and
   `{{language}}`.
2. Updated the DeepSeek chunking client to render its existing default prompt
   through the new prompt configuration.
   Result: the default request behavior remains equivalent while later steps can
   inject settings-backed prompt configuration.
3. Extended `SettingsStore` with translation language and prompt template
   persistence.
   Result: language changes save immediately, prompt templates are saved only
   after validation, and restoring the default prompt clears the custom
   persisted value.
4. Added CueSeekerApp tests for default rendering, custom language rendering,
   placeholder validation, prompt persistence, and invalid prompt rejection.
   Result: the first implementation step has focused automated coverage.

## Verification

- `swift test` passed from `apps/macos-native` with 145 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- Step 1 is implemented and verified.
