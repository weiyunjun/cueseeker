# AI Chunks Settings Step 4 Implementation Record

## Requirement

- `docs/human/requirements/20260527-Feature-AI Chunks.md`

## Scope

- Make AI Chunking cache keys follow the active Translation Language and prompt
  template.
- Clear existing AI Chunking cache entries once when this prompt-aware cache
  strategy first runs.
- Preserve the current database schema by using the existing `prompt_version`
  cache dimension.
- Keep human acceptance and any later naming/provider cleanup for later work.

## Steps

1. Added prompt-configuration cache version generation.
   Result: cache `prompt_version` now combines the base chunk prompt version
   with a stable hash of the prompt template and Translation Language.
2. Updated cache lookup and cache writes to use the prompt-aware version.
   Result: changing Translation Language or prompt template isolates AI Chunking
   cache entries and prevents reuse of results from a different prompt
   configuration.
3. Added a core database method to clear AI Chunking cache entries.
   Result: the app can explicitly discard historical cached AI chunk results
   without touching other subtitle/search data.
4. Added one-time app startup cache clearing.
   Result: after database migration, the app clears AI Chunking cache entries
   once and records `aiChunkingPromptAwareCacheCleared` in UserDefaults; later
   launches do not repeat the clear.
5. Added automated coverage for prompt-aware cache versions, cache clearing,
   and the one-time clearing marker.
   Result: tests cover the language/prompt cache split and the historical cache
   clearing rule.

## Verification

- `swift test` passed from `apps/macos-native` with 148 Swift Testing tests
  and 7 XCTest tests.
- The test run still emitted existing playback-history disk I/O log messages,
  but the full suite passed.

## Outcome

- Step 4 is implemented and verified.
