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
5. Added `Copy Deep Link` immediately below `Copy Cue Text` in the shared
   Search and Shiori row menu.
6. Reused the Settings link symbol for Deep Link and changed the three Cue copy
   actions to the existing Copy Table symbol.
7. Added the ordered `Copy Deep Link(s)` selection action to Search and Shiori.
8. Removed the table-selection Screenshot and Collage buttons, handlers,
   eligibility state, and refresh paths without changing Playback screenshot or
   Collage code.

## Verification

- Passed 5 focused formatter, pasteboard, Playback Overlay, and Playlist tests:
  `swift test --package-path apps/macos-native --filter
  'cueDeepLink|subtitleFocusClipboard|subtitleFocusCopyKey|playbackPlaylistCopy|playbackShioriCopy'`.
- Passed the focused Command Panel and Shiori Overlay tests:
  `swift test --package-path apps/macos-native --filter
  'playbackCommandPanelSearchSupportsCueShortcutsAndFullPlaylist|playbackShioriCopiesSettledPrimaryCueAsMarkdownLink'`.
- Passed 8 focused row-menu ordering, icon, target-retention, and clipboard
  tests: `swift test --package-path apps/macos-native --filter
  'subtitleTableSearchRowActionMenu|subtitleTableRowActionMenuHides|subtitleTableShioriRowActionMenu|subtitleTableUnavailableShioriActions|subtitleTableRowActionMetadata|subtitleTableViewUnifiedRowMenu|subtitleTableViewRowMenuActionsKeep|subtitleTableViewUnifiedRowMenuDispatches'`.
- Passed 9 focused batch Deep Link and selection tests:
  `swift test --package-path apps/macos-native --filter
  'cueDeepLinks|subtitleTableClipboardCopiesPrimaryCueDeepLinks|tableSandboxRowSelection'`.
- Confirmed by source inspection that Search and Shiori no longer expose or
  retain table-selection Screenshot/Collage paths, while Playback screenshot
  and Collage paths remain.
- The full 921-test run hit unrelated parallel database I/O and media timing
  failures. All 10 reported failing tests passed when isolated; 9 passed in the
  grouped rerun and the remaining UI refresh-count test passed alone.

## Outcome

- Step 1 passed focused verification. Playback Overlay and Command Panel keep
  their existing Deep Link payload while publishing the accepted feedback
  wording.
- Step 2 passed focused verification. Search and Shiori row actions copy the
  exact Primary Cue Deep Link and retain the triggering row target.
- Step 3 passed focused verification. Search and Shiori selection mode now
  orders actions as Anki, Copy Deep Link(s), and Copy Table, and copies Primary
  Cue Deep Links in selected-row order.

## Follow-ups

- Synchronize `docs/human/design/UI.md` after human acceptance.
