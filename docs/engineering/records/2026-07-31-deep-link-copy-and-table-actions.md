# Deep Link Copy and Table Actions

## Requirement

- `docs/human/requirements/20260731-Feature-Deep Link Copy and Table Actions.md`

## Scope

Implement Deep Link terminology and copy actions across Settings, Playback,
Search, and Shiori without changing the `cueseeker://` protocol or adding a
parallel state source.

Architecture classification:

- Deep Link serialization is product semantics owned by `CueSeekerCore`.
- Settings, menus, buttons, and feedback text are platform UI and UX.
- System pasteboard writes are macOS platform integration.

## Steps

1. Added one pure Cue Deep Link Markdown formatter to `CueSeekerCore`.
2. Moved pasteboard coordination out of the Playback-specific action file into
   a shared App-layer Cue clipboard helper.
3. Renamed the Settings category and page copy to Deep Link.
4. Updated the shared Playback Overlay and Command Panel Cue copy feedback.

## Verification

- Passed 5 focused formatter, pasteboard, Playback Overlay, and Playlist tests:
  `swift test --package-path apps/macos-native --filter
  'cueDeepLink|subtitleFocusClipboard|subtitleFocusCopyKey|playbackPlaylistCopy|playbackShioriCopy'`.
- Passed the focused Command Panel and Shiori Overlay tests:
  `swift test --package-path apps/macos-native --filter
  'playbackCommandPanelSearchSupportsCueShortcutsAndFullPlaylist|playbackShioriCopiesSettledPrimaryCueAsMarkdownLink'`.

## Outcome

- Step 1 passed focused verification. Playback Overlay and Command Panel keep
  their existing Deep Link payload while publishing the accepted feedback
  wording.

## Follow-ups

- Add single-row Search and Shiori `Copy Deep Link` actions.
- Add batch `Copy Deep Link(s)` and remove table-selection Screenshot and
  Collage actions.
- Synchronize `docs/human/design/UI.md` after human acceptance.
