# Playback Multi-Module Overlay

## Human-Owned Source

- `docs/human/requirements/20260714-Feature-Playback Multi-Module Overlay.md`
- `docs/human/design/UI.md`

## Scope

Upgrade the playback Subtitle Focus surface into one temporary multi-module
overlay session. Preserve Current behavior while adding the shared shell,
strict session cleanup, shared virtual-reel infrastructure, Playlist, Search,
Recent, Library, and Shiori in independently verifiable implementation steps.

The repository does not currently contain a Playlist model or store. The shell
therefore accepts Playlist as an explicit session capability and does not infer
it from unrelated Search, Shiori, or Library previous/next navigation. The
capability will be enabled when the Playlist snapshot is implemented.

## Implementation Steps

### 1. Session Shell and Sidebar

- Added canonical Current, optional Playlist, Search, Recent, Library, and
  Shiori module identities with the documented labels and symbol assets.
- Made available modules and the selected module session-owned transient state.
  A new session starts on Current; Tab cycles only the available canonical
  order; direct selection supports sidebar clicks.
- Clear the selected module and available-module capability together with cue,
  action, navigation, scrollbar, and motion state when the session ends.
- Added the fixed 240-point sidebar using the existing app-sidebar size tokens
  and the existing Subtitle Focus selected/unselected color tokens. Current is
  still rendered by the existing reel without geometry changes.
- Routed unmodified Tab before editable-input focus handling so it always
  switches modules. Current now uses Enter for playback; Space is consumed
  without a playback action.
- Bound the mounted overlay view identity to the session generation so a
  destroyed session dismantles the previous native reel before a later session
  is mounted.

## Verification

### Step 1

- `swift test --filter playbackOverlay`
  - Passed 7 new module, lifecycle, keyboard, and token tests.
- `swift test --filter subtitleFocus`
  - Passed 61 existing Subtitle Focus regression tests.
- `swift test`
  - Passed 7 XCTest tests and 642 Swift Testing tests.
- `git diff --check`
  - Passed.

## Outcome

In progress.

## Follow-ups

- Implement strict five-point Visual Line Stack geometry before extracting the
  virtual reel, so typography and infrastructure regressions remain separable.
- Define and capture the real Playlist snapshot before enabling its sidebar
  capability in production.
