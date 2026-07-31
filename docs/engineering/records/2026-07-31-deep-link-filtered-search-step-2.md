# Deep Link Filtered Search — Step 2

## Requirement

- `docs/human/requirements/20260731-Feature-Command Panel Search Integration And Recent Videos Refresh.md`
- `docs/human/design/Command Panel.md`

## Classification

- Deep Link Search Filter and first-result selection: product semantics.
- Workbench versus Command Panel routing: existing platform UI/UX.
- Native media execution: unchanged.

## Cause

Deep Link Search cleared the internal Search Filter context and direct play
resolved from the unfiltered first visible page. The persisted Workbench facet
Filter survived in Settings, but it did not participate in choosing the first
result to play.

## Implementation

- Synchronized the persisted Workbench facet Filter into `SearchStore` before
  every Deep Link Search without changing its saved value.
- Preserved the existing first-visible-page direct-play path when the facet
  Filter is empty.
- Reused the existing exact-completion task when a facet Filter is active, then
  resolved direct play from the first formal filtered result.
- Reused the formal filtered Search Playlist and existing generation-bound URL
  intent; no database query, task, state source, or result collection was
  added.
- Routed an empty filtered projection to the existing Workbench or Command
  Panel Search fallback according to active Playback state.

## Verification

- `swift test --filter urlScheme`: 13 tests passed.
- `swift test --filter 'urlScheme|playbackCommandPanel'`: 21 tests passed.
- `git diff --check`: passed.

## Outcome

Deep Link Search now preserves and applies the current Workbench facet Filter.
`Play First Search Result` selects the first filtered result, and an empty
filtered projection follows the existing Search fallback behavior.
