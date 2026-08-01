# Playback Command Panel Focused Cue Prefill

## Requirement

- `docs/human/requirements/20260801-Feature-Playback Command Panel Focused Cue Prefill.md`

## Scope

Add the default-Off `Prefill with Focused Cue` preference under Settings >
Search. When enabled, opening Command Panel from Playback Overlay Current or
Cue Playlist preloads the focused Primary Cue without starting Search and
places the insertion point after the complete normalized text. Preserve
Collage exclusivity and the empty-query behavior outside the two covered
Overlay modules.

## Steps

1. Added the persisted preference to `SettingsStore` and its native Settings
   switch with the accepted label and description.
2. Derived the eligible focused Cue from the existing Overlay Session Current
   or Cue Playlist selection without adding another selection owner.
3. Initialized the existing Command Panel root query from that Cue through the
   shared single-line Search normalization path without publishing Search
   state.
4. Extended the shared Search field autofocus path with an opt-in insertion-end
   placement used only by Command Panel.
5. Added preference, Current, Cue Playlist, normalization, no-search, disabled,
   non-Overlay, Collage, and insertion-range coverage.
6. Synchronized the derived product documents and changelog.

## Verification

- `swift test --jobs 1 --filter 'workbenchSearchFieldPlacesInsertionPointAfterCompleteText|SettingsStore|playbackCommandPanel|playbackOverlayPControlsExclusiveEditingCollageMode'`
  passed 36 tests.
- `swift build --jobs 1` passed.
- `swift test --jobs 1` completed 949 Swift Testing tests with 21 issues in
  existing native-playback timing, table-menu geometry, database-concurrency,
  and refresh-scope tests. The feature tests passed in that run. Isolated
  reruns passed for the Overlay Shiori identity, Search refresh scope, native
  seek presentation, native common timeline, and Library removal failures. The
  unrelated existing
  `subtitleTableViewDisplayTitleContentRightClickOpensMenuBelowClickPosition`
  geometry assertion remained failing; this change does not modify its table or
  menu path.
- Manual visual confirmation of autofocus and insertion placement remains an
  owner acceptance check.

## Outcome

The persisted default-Off preference now preloads only Current and Cue Playlist
focused Primary Cue text into Command Panel. It reuses the existing Overlay
selection and Search field, does not start Search, keeps Collage exclusive, and
places the insertion point after normalized text. Feature verification and the
debug build passed; one unrelated pre-existing table-menu geometry test remains
red as recorded above.
