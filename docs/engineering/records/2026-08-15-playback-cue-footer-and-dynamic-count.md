# Playback Cue Footer And Dynamic Count

## Requirement

- `docs/human/requirements/20260815-Feature-Playback Cue Footer And Dynamic Count.md`

## Implementation

- Added one shared Playback Cue Footer and shared Keycap tokens for Current,
  Cue Playlist, Command Panel Search, and the Collage subtitle pane.
- Bound Footer status text to each surface's existing complete-count source.
  Command Panel Search retains its 50-result preview while the same search task
  continues publishing its total into the resident Cue Playlist snapshot.
- Used the native SF Symbols `return` glyph and kept Root, Recent, and video
  Playlist outside the change.
- Left `docs/human/design/UI Design System.md` unchanged for human update after
  visual acceptance, as required.

## Verification

- Relevant Footer formatting, progressive search, resident Playlist refresh,
  selection preservation, Command Panel handoff, and pointer-shield tests pass.
- Debug E2E screenshots verified Current, Collage, and the unchanged video
  Playlist in the real AppKit window; no additional E2E capability was needed.
- `swift test --quiet` was also run as a repository-wide diagnostic. The 1,003
  test run still reports 23 issues in unrelated media-timing,
  database-concurrency, window-coordinate, and UI-isolation tests; the seven
  requirement-focused tests pass together.

## Outcome

- The four requested Cue surfaces now share one Footer implementation and one
  live-count rule without adding a second search or Playlist lifecycle.
