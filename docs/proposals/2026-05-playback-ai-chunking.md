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

## Non-goals

- Do not implement synonym or antonym expansion in the first version.
- Do not implement the previous prompt2 flow in the first version.
- Do not combine synonym and antonym result sets.
- Do not add persistent AI chunking cache in the first version.
- Do not change local search ranking, query semantics, or database schema for
  the first version.
- Do not create an AI-owned search result list or playback playlist.
- Do not run a long conversation or retain chat history across requests.

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

## UI/UX Behavior

When the user opens Playback Quick Search:

- If AI chunking is disabled, show no AI chunking hint.
- If AI chunking is enabled but no API key is configured, show no AI chunking
  hint in the overlay.
- If AI chunking is enabled and an API key exists, show a low-emphasis inline
  ghost suffix `/chunks` immediately after the seeded query text.
- The text insertion point remains at the end of the real query text, before the
  ghost suffix.
- The ghost suffix is an action hint, not part of the query text.
- Manual edits to the input hide the AI chunking hint for the current overlay
  interaction.
- Programmatic changes caused by subtitle line navigation or chunk selection do
  not count as manual edits.

Example display:

```text
今天天气真不错 /chunks
```

In this example, `今天天气真不错` is the actual query text and `/chunks` is a
dimmed hint.

Keyboard behavior before a local search is submitted:

- Up and Down keep their existing subtitle-line navigation behavior.
- Right accepts the `/chunks` hint and starts the chunking request when the hint
  is visible and the insertion point is at the end of the real query text.
- While loading, show a loading row below the search field.
- If the request fails, show an error row below the search field.
- If chunking succeeds, show the returned chunks below the search field.
- The first chunk is selected by default.
- The selected chunk must have a visible selected background using the current
  Quick Search selected-row visual language.
- Left and Right move the selected chunk.
- Return searches the selected chunk through the existing Quick Search/Search
  flow.

Keyboard behavior after local search results are visible remains unchanged:

- Up and Down select search results.
- Return opens the selected result.
- Escape dismisses the overlay before fullscreen Escape behavior.

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

## Future Persistence

The first version should not persist chunking results.

Future versions should add persistence because chunking results are expected to
be stable for the same normalized sentence, provider, model, and prompt
version.

Future cache key candidates:

- Normalized sentence hash.
- Provider.
- Model.
- Prompt version.

Future cache values:

- Validated chunk items.
- Response metadata useful for debugging, excluding API keys and sensitive
  headers.
- Created/updated timestamps.

Persistent caching should be documented separately before implementation because
it may require database schema changes and migration tests.

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

- Show the inline `/chunks` ghost suffix in the Quick Search field when enabled
  and configured.
- Keep Up and Down reserved for existing subtitle-line and result-list
  navigation.
- Hide the hint after manual input edits.
- Start chunking from Right accepting the hint.
- Show loading and error rows below the Quick Search field.

Stage 5: chunk selection and local search.

- Display validated chunks.
- Select the first chunk by default.
- Support Left and Right selection.
- Use Return to search the selected chunk through the existing Quick Search
  flow.

## Acceptance Criteria

- AI chunking is disabled by default.
- Settings can enable AI chunking.
- Settings can save and clear the DeepSeek API key without storing plaintext in
  `UserDefaults`.
- Opening Quick Search shows the `/chunks` ghost hint only when the feature is
  enabled and a key exists.
- The insertion point starts at the end of the real query text, before the
  ghost hint.
- Manually editing the input hides the AI chunking hint for the current
  overlay interaction.
- Up and Down navigation does not trigger AI chunking.
- Pressing Right while the `/chunks` hint is visible sends one stateless
  request.
- Text sent to AI has punctuation and subtitle separators replaced with spaces.
- Invalid responses show an overlay error.
- Valid responses show chunks with the first chunk selected by default.
- Left and Right move chunk selection.
- Return searches the selected chunk through the existing local Search flow.
- Prompt2, synonym search, antonym search, and persistent cache are not part of
  the first implementation.

## Decision

Pending.
