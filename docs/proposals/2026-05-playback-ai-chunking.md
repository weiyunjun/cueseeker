# Proposal: Playback AI Chunking

Status: Proposal

## Background

Playback Quick Search provides a keyboard-first search overlay that can search
the current subtitle line and play results through the existing Search flow.

The next product step is optional AI-assisted chunking inside that overlay. The
AI feature should help the user choose a useful learning/search unit from the
current subtitle sentence. It should not own search results, ranking, playback,
or a separate search state.

## Goals

- Add an optional AI chunking entry below the playback Quick Search field.
- Keep the feature disabled by default.
- Allow the user to enable the feature from Settings and configure an API key.
- Store API keys securely in macOS Keychain, not in `UserDefaults`, source
  files, logs, or plaintext app storage.
- Use a single stateless AI request for each chunking attempt.
- Start with DeepSeek as the only implemented provider while keeping the app
  boundary provider-oriented.
- Normalize subtitle text before sending it to AI by replacing punctuation and
  subtitle separators with spaces.
- Show AI errors inside the overlay instead of failing silently.
- Show returned chunks in the overlay with keyboard selection.
- Search the selected chunk through the existing Quick Search/Search flow.
- Persist validated chunking results so repeated subtitle lines can show chunks
  without another provider request.
- Log cache decisions and AI request usage, including token counts, without
  logging secrets or full request authorization data.

## Non-goals

- Do not implement synonym or antonym expansion in the first version.
- Do not implement the previous prompt2 flow in the first version.
- Do not combine synonym and antonym result sets.
- Do not change local search ranking, query semantics, or database schema for
  local subtitle search.
- Do not create an AI-owned search result list or playback playlist.
- Do not run a long conversation or retain chat history across requests.
- Do not persist API keys, authorization headers, or raw provider request bodies
  in the chunk cache.

## Product Rules

AI chunking is an assistive selector, not an AI search engine.

The first version flow is:

```text
Current subtitle sentence
AI chunks the sentence
User selects one chunk
CueSeeker searches that chunk locally
Existing search results and playback behavior continue
```

The AI provider returns candidate chunks only. The local subtitle database and
existing Search state remain authoritative for search results.

## Text Normalization

The app should normalize text before sending it to AI.

Rules:

- Replace punctuation with spaces instead of deleting punctuation.
- Replace subtitle separators and line breaks with spaces.
- Collapse consecutive whitespace to a single space.
- Trim leading and trailing whitespace.
- Send the normalized sentence to AI.

Replacing with spaces avoids accidental token joining across punctuation or
subtitle layout boundaries.

Example:

```text
Input:
安い小芝居しとけば　同情が買えると思っている　あばずれでは。

AI input:
安い小芝居しとけば 同情が買えると思っている あばずれでは
```

## AI Request Model

Each chunking action sends one new stateless request.

Rules:

- Do not include prior requests or responses as conversation history.
- Do not keep a long-running chat session.
- Use low temperature.
- Request JSON output.
- Keep thinking disabled for providers that support that setting.
- Treat invalid JSON, empty chunks, or non-matching chunks as an overlay error.

Initial provider:

- Provider: DeepSeek.
- Model: `deepseek-v4-flash` unless configuration changes later.
- Endpoint shape: OpenAI-compatible chat completions.

Provider boundary:

- The first implementation may only expose DeepSeek in Settings.
- Internal code should still model provider identity explicitly, such as
  `AIProvider.deepSeek`.
- Provider API keys should be stored separately, for example under Keychain
  service `CueSeekerAI` with account `deepseek`.
- Future OpenAI-compatible providers should be addable by providing provider
  metadata such as base URL, model, and Keychain account without changing Quick
  Search behavior.

## Prompt Scope

The first version implements only sentence chunking.

The AI should return JSON shaped like:

```json
{"items":["item1","item2"]}
```

Validation rules:

- `items` must not be empty.
- Each item must be a non-empty continuous substring of the normalized sentence
  sent to AI.
- Duplicate items should be ignored or treated as invalid according to the
  strictness chosen during implementation.
- Ordinary pronouns, ordinary particles, and meaningless half characters should
  not be accepted as useful chunks.

## Prompt2 Status

The earlier synonym/antonym prompt is deferred and should not be part of the
first implementation.

Reasoning:

- Synonyms may not exist in the indexed subtitles.
- Antonyms may not exist in the indexed subtitles.
- Mixing synonym and antonym search results creates ambiguous product behavior.
- The first AI value should be choosing a better local search unit, not
  expanding the query into uncertain semantic groups.

This proposal does not require prompt2 to be implemented later.

## Persistent Chunk Cache

AI chunking results should be cached because they are expected to be stable for
the same normalized sentence and prompt contract.

Cache key:

- Normalized sentence.
- Provider.
- Model.
- Prompt version.

Cache value:

- Validated chunk items.
- Cache date, recorded once when chunks are first cached for the same normalized
  subtitle line and cache key.
- Updated timestamp.
- Last-used timestamp.

Rules:

- Cache only validated chunk items.
- A cache hit must not send an AI provider request.
- A cache miss may show the fixed `current sentence / chunks` option and
  request chunks only after the user triggers that option.
- Manual chunk refresh bypasses cache lookup for that action.
- Successful refresh overwrites the cached chunk items for the same key.
- Successful refresh must not create a second cache date for the same normalized
  subtitle line and cache key.
- Failed refresh keeps the previous cached value intact and shows the error in
  the overlay.
- Prompt wording or validation changes that can affect chunk output must bump
  the prompt version so old cache entries are not reused accidentally.
- Logs may include a short text hash for debugging, but must not include API
  keys or authorization headers.

The current cache implementation only needs to record the cache date. It should
not implement date-based filtering, date-based UI hints, or a full per-query
usage history yet.

Future date metadata:

- If a cached chunk set is searched multiple times, future versions may record
  every search/use date as separate usage metadata.
- The cache date remains one record per normalized subtitle line and cache key.
- Future Search or Quick Search UI may use the cache date to filter cached
  chunks or show freshness hints near the search field.

## UI/UX Behavior

When the user opens Playback Quick Search:

- If AI chunking is disabled, show no AI option rows.
- If AI chunking is enabled but no API key is configured, show no AI option rows
  in the overlay.
- The Quick Search input opens empty. The current playback subtitle sentence is
  captured as transient overlay context, not inserted into the input.
- If AI chunking is enabled, an API key exists, and cached chunks exist for the
  current sentence, show a chunks option row immediately under the search field.
  The first chunk is selected by default, and the search input must not show a
  text caret while that option owns logical focus.
- The chunks option row must wrap as needed so every chunk is visible in the
  overlay; it must not force chunks into a single horizontally scrolling or
  clipped row.
- If AI chunking is enabled, an API key exists, and cached chunks exist for the
  current sentence, also show a fixed `current sentence / chunks` option row
  below the chunks row. Pressing Return on this fixed row sends a manual refresh
  request.
- If AI chunking is enabled, an API key exists, and no cached chunks exist for
  the current sentence, show only the fixed `current sentence / chunks` option
  row. It is selected by default, and the search input must not be the AppKit
  first responder.
- Manual edits to the input hide AI option rows and cached chunks for the
  current overlay interaction.
- Programmatic changes caused by chunk selection or restoring AI options after a
  chunk search do not count as manual edits.

Example display:

```text
Search subtitles

chunks: [tonight] [looks beautiful] [from here]
current sentence / chunks
```

The chunks row appears only after cached chunks are loaded or a chunking request
has completed successfully.

Keyboard behavior before a local search is submitted:

- Quick Search owns a logical focus target: input, AI option, or search result.
- Logical focus and real input focus must match visually: when an AI option is
  selected, the search input does not show a caret and is not the active AppKit
  text responder.
- Up and Down move between the input and visible option rows. They no longer
  select nearby subtitle lines.
- If the first visible option is selected, Up returns focus to the input.
- If the last visible option is selected, Down returns focus to the input.
- Pressing Return on `current sentence / chunks` sends one stateless chunking
  request for the captured current sentence.
- While loading, show a loading row below the search field.
- If the request fails, show an error row below the search field.
- If chunking succeeds, insert the chunks row above `current sentence / chunks`.
  The first chunk is selected by default.
- The selected chunk must have a visible selected background using the current
  Quick Search selected-row visual language.
- Left and Right move the selected chunk only while the chunks row is selected.
- Pressing Return on the chunks row searches the selected chunk through the
  existing Quick Search/Search flow.

AI options and search results are mutually exclusive:

- Before a search is submitted, the overlay may show AI option rows.
- After a chunk or direct query is submitted, the overlay shows search results
  instead of AI option rows.
- A chunk search stores a transient snapshot of the previous AI options and the
  selected chunk.
- Pressing Escape from search results reached through a chunk search returns to
  the previous AI options and restores the selected chunk.

Keyboard behavior after local search results are visible:

- Up and Down move between the input and visible search results.
- If the first search result is selected, Up returns focus to the input.
- If the last search result is selected, Down returns focus to the input.
- Return opens the selected result.
- If results were reached through a chunk search and focus is on a search
  result, Escape returns to the previous AI options and preserves the selected
  chunk.
- If results were reached through a chunk search and focus is in the input,
  Escape dismisses the overlay.
- If results were reached through direct search and focus is on a search result,
  Escape moves focus back to the input and keeps the result list visible.
- If results were reached through direct search and focus is in the input,
  Escape dismisses the overlay.
- Escape is consumed by the overlay before fullscreen Escape behavior.

## Settings Behavior

Settings should expose the first version under Experimental Features.

Required settings:

- Enable AI chunking.
- Configure DeepSeek API key.
- Clear DeepSeek API key.
- Indicate whether a key is currently configured without displaying the key.

Storage rules:

- The enable/disable flag may use `UserDefaults`.
- The API key must use Keychain.
- Logs must not include the API key or full authorization header.
- The UI should not display the stored key after saving.

## Logging Behavior

Chunking should be observable during local testing without exposing secrets.

Cache decision logs:

- Cache hit: log that the request was skipped.
- Cache miss: log that the next chunking action will require a request.
- Manual refresh: log that cache was bypassed for the request.

AI request completion logs:

- Provider.
- Model.
- Request reason, such as `cache_miss` or `manual_refresh`.
- Prompt token count.
- Completion token count.
- Total token count.
- Estimated cost in CNY.
- Returned item count.
- Whether the cache was written.

Failure logs:

- Provider.
- Model.
- Request reason.
- Error category or HTTP status when available.
- No API key, authorization header, or full subtitle text.

Rules:

- A cache hit should produce a cache-hit skip log and no AI request completion
  log.
- Every completed AI provider request should log token counts from provider
  usage when available.
- Estimated cost is a local debugging aid and should not be treated as billing
  authority.

## Implementation Stages

Stage 1: document product rules.

- Record punctuation normalization, stateless requests, no first-version
  persistence, and prompt2 deferral.

Stage 2: settings and secure storage.

- Add the disabled-by-default feature flag.
- Add DeepSeek API key configuration.
- Store the key in Keychain.

Stage 3: AI chunking client.

- Add provider-oriented chunking client boundaries.
- Implement DeepSeek single-request prompt1.
- Validate JSON and item substrings against the normalized sentence.

Stage 4: Quick Search AI entry.

- Open Quick Search with an empty input.
- Capture the current playback subtitle sentence as transient option context.
- Show fixed AI option rows below the Quick Search field when enabled and
  configured.
- Keep AI options and search results mutually exclusive.
- Use Up and Down for logical focus movement between input and option rows.
- Hide AI option rows after manual input edits.
- Start chunking from Return on the `current sentence / chunks` option.
- Show loading and error rows below the Quick Search field.

Stage 5: chunk selection and local search.

- Display validated chunks.
- Insert the chunks row above the fixed `current sentence / chunks` row.
- Select the first chunk by default.
- Support Left and Right selection.
- Use Return to search the selected chunk through the existing Quick Search
  flow.

Stage 6: persistent chunk cache and request logging.

- Add a persistent cache keyed by normalized sentence, provider, model, and
  prompt version.
- Record one cache date per cached normalized subtitle line and cache key.
- Load cached chunks when opening Quick Search for the current sentence.
- Show cached chunks immediately with the first chunk selected and keep the
  fixed `current sentence / chunks` row available as a manual refresh action.
- Log cache hits, misses, refreshes, request failures, and request usage token
  counts.

## Acceptance Criteria

- AI chunking is disabled by default.
- Settings can enable AI chunking.
- Settings can save and clear the DeepSeek API key without storing plaintext in
  `UserDefaults`.
- Opening Quick Search leaves the input empty.
- Opening Quick Search captures the current subtitle sentence as AI option
  context when the feature is enabled and a key exists.
- Opening Quick Search shows cached chunks immediately when the feature is
  enabled, a key exists, and the current sentence has a cache hit; the first
  cached chunk is selected by default.
- Cached chunks are all visible by wrapping within the overlay width.
- Opening Quick Search shows only `current sentence / chunks` when the feature
  is enabled, a key exists, and the current sentence has no cached chunks.
- When an AI option is selected by default, the search input has no caret and
  does not own AppKit text focus.
- The input becomes the real text responder only after the user moves logical
  focus back to the input or clicks/taps the input.
- When chunking succeeds, the chunks row appears above `current sentence /
  chunks` and the first chunk is selected.
- Manually editing the input hides AI option rows and cached chunks for
  the current overlay interaction.
- Up and Down navigation does not trigger AI chunking and does not select
  nearby subtitle lines.
- Pressing Return on `current sentence / chunks` sends one stateless request.
- Text sent to AI has punctuation and subtitle separators replaced with spaces.
- Invalid responses show an overlay error.
- Valid responses show chunks with the first chunk selected by default.
- Left and Right move chunk selection.
- With chunks visible, Return searches the selected chunk.
- If the first visible AI option is selected, Up returns focus to the input.
- If the last visible AI option is selected, Down returns focus to the input.
- From the `current sentence / chunks` option, Return sends one stateless
  refresh request.
- Manual chunk refresh bypasses the cache for that action and overwrites the
  cache only on success.
- Cache date is recorded once per normalized subtitle line and cache key; a
  refresh must not create duplicate cache dates.
- Cache hits log a skipped request and do not log an AI request completion.
- Every completed AI request logs token counts and estimated CNY cost.
- Return searches the selected chunk through the existing local Search flow.
- AI options and search results are not visible at the same time.
- From search results reached through a chunk search, Escape on a focused result
  returns to the previous chunks options and preserves the selected chunk.
- From search results reached through a chunk search, Escape in the input
  dismisses Quick Search.
- From search results reached through direct search, Escape on a focused result
  returns focus to the input.
- From search results reached through direct search, Escape in the input
  dismisses Quick Search.
- Prompt2, synonym search, and antonym search are not part of the first
  implementation.

## Decision

Pending.
