# Playback Overlay Initial View by Playlist Type

## Requirement

- `docs/human/requirements/20260801-Feature-Playback Overlay Initial View by Playlist Type.md`
- `docs/human/design/UI.md`, Playback Overlay opening and Session rules

## Scope

Classify the change as platform UI/UX and keep the policy at the existing
Playback Overlay Session creation boundary. Cue Playlists open on Playlist;
video Playlists and playback without an available Playlist open on Current.

## Steps

1. Added a failing Cue Playlist expectation before changing production code.
2. Reused the existing opening-phase `presentModule` path in `PlaybackStore`
   so a resident Cue Playlist selects Playlist without adding a new state owner
   or type.
3. Preserved Current for Library-backed video Playlists and for sessions with
   no available Playlist.
4. Updated affected tests that previously pressed Tab or selected Playlist
   manually to reach the old non-default View.
5. Aligned derived product, architecture, end-to-end testing, and changelog
   documentation with the committed human-owned behavior.

## Verification

- Before implementation, the focused Cue Playlist test failed because the
  Session selected Current instead of Playlist; the video Playlist expectation
  passed.
- `swift test --jobs 1 --no-parallel --filter 'playbackStoreCreatesSubtitleFocusSessionOnlyAfterOpen|playbackStoreOpensPlaylistOverlayAtLogicalPlayingItem|playbackStoreUsesTheLibrarySessionStoreAsTheMediaPlaylistSource|playbackCommandPanelDatabaseSearchOpensCompletePlaylistOverlay|playbackCommandPanelPrefillsFocusedPlaylistCue|playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue|playbackPlaylistShioriItemReportsAlreadySavedWithoutCreatingAnotherRow|playbackPlaylistEnterDispatchesSelectedTargetAndDestroysOverlaySession'`
  passed all 8 focused tests.
- `swift test --jobs 1` built successfully and ran 949 tests, reporting 23
  issues in unrelated native-playback, Library-removal, and UI-invalidation
  tests. No initial-View or affected Playlist test failed after the test
  alignment.

## Outcome

The implementation matches the accepted rule with one centralized conditional
and no new abstraction, cache, lifecycle, or duplicated state.

## Follow-ups

None for this requirement.
