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

### 2. Strict Five-Point Visual Line Stack

- Added the documented five-point internal-line token without changing the
  eight-point gap between independent Current cue containers.
- Replaced Current's fixed per-line slot drawing with one Visual Line Stack
  planner shared by measurement and native drawing.
- Kept TextKit responsible for hard-line and soft-wrap fragmentation, then used
  CoreText run typographic bounds to resolve the actual fallback-font ascender
  and descender for every visual line. Ink bounds and fixed line-fragment
  heights do not participate in vertical placement.
- Placed every line from the second onward exactly five points below the prior
  line's typographic bottom. The complete stack is centered once inside
  `max(52 * line count, stack height)` so ordinary one-, two-, and three-line
  Current heights remain 76, 128, and 180 points.
- Normalized CRLF and CR for layout and used an invisible zero-width sentinel
  only when needed to retain empty text and a trailing empty source line.
- Kept the complete natural layout anchored at the top of oversized cue rows
  and clipped only the trailing overflow. No internal reading offset or
  ellipsis was introduced.
- Incremented the measurement style revision so pre-change cached geometry
  cannot be reused.

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

### Step 2

- `swift test --filter subtitleFocus`
  - Passed 64 tests, including strict hard/soft line gaps, CRLF/CR, empty and
    trailing lines, fallback-font metrics, oversized clipping, and existing
    50,000-cue virtualization coverage.
- `swift test`
  - Passed 7 XCTest tests and 645 Swift Testing tests.
- `swift test --filter subtitleFocusVisualLineStack`
  - Passed the 3 focused strict-gap and resolved-font-run tests after the final
    cross-version assertion hardening.
- `git diff --check`
  - Passed.

## Outcome

In progress.

## Follow-ups

- Extract the Current virtual reel into item-agnostic infrastructure while
  retaining this step's Visual Line Stack behavior unchanged.
- Define and capture the real Playlist snapshot before enabling its sidebar
  capability in production.
