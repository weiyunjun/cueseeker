# Playback continues when content leaves the database

Human-owned documents:

- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md`
- `docs/human/design/Data.md` (补充说明 7, which the requirement replaces until the design is updated after acceptance)

## Step 1: one Debug delay for Add Folder, Index and Remove Folder

### What changed

- The Remove Folder delay moved out of the removal itself into the three task runners. In a Debug build, Add Folder, Index and Remove Folder each wait the seconds in `CUESEEKER_DEBUG_TASK_DELAY_SECONDS` before starting their work; the task shows as running meanwhile.
- The take-backs of an unfinished Add Folder (removed while running, or left by the previous launch) call the removal executor directly, so they never wait.
- `CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS` is gone. The switch stays for later acceptance work rather than being removed after this one.

Launch:

```bash
cd apps/macos-native && CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker
```

File: `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`

### Verification

- `swift build` compiles.
- No automated test sets the variable, for the reason the 2026-09-19 record gives: it is process-wide and would slow every other task test in the parallel run. The wait itself is left to the owner's in-App check.

## Step 2: which cues and Excerpts are still in the library

### What changed

- `CueContentDatabase.liveCueIDs(among:)` answers which of the given cues are still in the library: indexed, not in the tombstone, on a subtitle matched to a video.
- `ExcerptDatabase.validExcerptIDs(among:)` answers the same for Excerpts, with the test the resolved Excerpt's `isValid` makes, so a tombstoned cue counts as gone (requirement 2).
- Both read in batches of 500 ids, so a long playlist is checked in a few statements.

Files: `apps/macos-native/Sources/CueSeekerCore/CueContentDatabase.swift`, `apps/macos-native/Sources/CueSeekerCore/ExcerptDatabase.swift`, `apps/macos-native/Tests/CueSeekerCoreTests/ExcerptDatabaseTests.swift`

### Verification

- `cuesAndExcerptsLeaveTheLibraryWithTheTombstoneOrTheirFolder` saves three cues as Excerpts, then empties one subtitle (its cue goes to the tombstone) and removes another folder: only the cue and Excerpt that stayed are answered. Passes.

## Step 3: playback continues; previous, next and Auto Switch go to the first item still in the library

### Why it returned to Workbench

When a Remove Folder or Index finished, the page refresh checked whether the playing video had left the library and, if so, cleared the selection and stopped playback, which also closed the playback page. That followed `Data.md` 补充说明 7, which this requirement replaces.

### What changed

- The refresh no longer stops anything: the item playing plays on whether or not the library still holds it (requirement 3.1).
- Before the pages are brought up to a database change, the playback playlist holds the items it has, so the stores reloading underneath no longer reach it. Once the change is in, whether the item playing is still in the library is settled at once, and the playlist drops what left the library, or waits until the Playback Overlay and the Command Panel are both closed if one of them is open, since until then they keep showing what they had (requirement 4.1). An in-App rename does not go through this: it keeps every id, so nothing leaves the library.
- A video that left the library no longer writes its playback history or watch state: the history writer would otherwise add the video back as a bare row. Default Audio Track and Default Subtitle already write nothing for a video without a row.
- While the item playing is out of the library, previous, next, Auto Switch and the end of a Library video go to the first item of the playlist the library still holds: the first result or Excerpt left in the playlist, or the first video of the folder the video was in. With none, a Playback Feedback of one second says `No Available Results`, `No Available Excerpts` or `No Available Videos`. The previous and next buttons are enabled when there is somewhere to go (requirement 3.2, 3.3).
- The cue playing keeps its Auto Pause and Auto Switch when the playlist moves it to another place or drops it.

Files: `AppCoordinator+PlaybackLibraryChange.swift` (new), `AppCoordinator.swift`, `AppCoordinator+Indexing.swift`, `AppCoordinator+Library.swift`, `AppCoordinator+Excerpt.swift`, `AppCoordinator+Search.swift`, `AppCoordinator+Playback.swift`, `AppCoordinator+PlaybackPlaylist.swift`, `PlaybackStore.swift`, `PlaybackViewModel.swift`, `PlaybackPlaylistSource.swift`, the three `Localizable.strings`, under `apps/macos-native/Sources/CueSeekerApp/`.

### Known limit

- A held playlist keeps the text and times its items had when the change came. An item still in the library whose cue an Index moved plays from the old time; the search playlist already behaved this way before this change.

### Verification

- New `PlaybackLibraryChangeTests`: a held playlist ignores the stores and renumbers what it keeps; from a search result, an Excerpt whose cue went to the tombstone, and a Library video that left the library, previous and next go to the first item still in the library, and say `No Available …` when there is none; a playlist shown through a change drops what left only once the Command Panel closes. All pass.
- `removingAParentStopsOnlyTheVideosThatLeaveTheLibrary` and `indexStopsOnlyAVideoItTakesOutOfTheLibrary` asserted the old rule, playback stopping; they now assert the new one under new names: the video stays selected and is marked as out of the library only when it left. Both pass.
- `swift test` (full, parallel): 1281 tests, 12 failing, all in the environment-sensitive set earlier records name (the native playback timing tests including `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, `sceneUsesVisibleWindowUnionAndTopLeftCoordinates`, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`). No new failure.

## Step 4: the Playback Overlay through a database change

### What changed

- Opened on a subtitle that is no longer matched to the video playing, the overlay no longer fails to open. Current shows `This subtitle is no longer in the library.`; Playlist opens as usual (requirement 3.4).
- A playlist that kept nothing the library still holds still has its Playlist tab, which shows `No items in this playlist are in the library.`; a Library Playlist whose folder kept no video says the same. Both messages use the Empty Hint the Library Playlist already used, now shared as `PlaybackEmptyHint`. Its old text, `playback.episodes_empty`, only showed for a folder with no video, which now means the folder left the library, so it is gone.
- An open overlay keeps what it shows: the cue playlist is held by Step 3, the Library Playlist now keeps its folder too, and Current and Collage already held what they loaded (requirement 4.1, 4.2).
- In Current and Playlist, an item the library no longer holds, whether or not its file is still on disk, is refused (requirement 4.3–4.5, 4.7):
  - Play, from the key, the footer or an episode card, leaves the overlay open and shows a third line on the Player Error Banner, `This item is no longer in the library`, below the video and subtitle lines. It lasts 5 seconds and a new refusal replaces it.
  - Save to Excerpt List and Copy Deep Link show a one-second Playback Feedback with the warning icon, `Not in Library`. An item with no cue identity keeps its old answer, `No Subtitle`.
  - Copy Cue Text and Collage are unchanged.
- Opening an episode from a Library Playlist kept through a change leaves the videos that left out of previous and next.

Files: `AppCoordinator+PlaybackLibraryChange.swift`, `AppCoordinator+PlaybackSubtitleFocus.swift`, `AppTypes.swift`, `PlaybackErrorBanner.swift`, `PlaybackStore.swift`, `PlaybackViewModel.swift`, `PlaybackLibraryOverlay.swift`, `PlaybackLibrarySessionStore.swift`, `PlaybackSubtitleFocusOverlay.swift`, `PlaybackSubtitleFocusSessionStore.swift`, the three `Localizable.strings`.

### Open for the owner's in-App review

- Current with no subtitle still shows the Collage button, which does nothing there.
- The two new messages sit where the Library Playlist's message already sat, near the top, without a footer.

### Verification

- New tests in `PlaybackLibraryChangeTests`: the overlay opens on a subtitle that left the library with Current saying so and the Playlist still offered; an open overlay keeps its playlist through a change, refuses Copy Deep Link, Save to Excerpt List and Play on an item that left (the overlay stays, the banner line shows) and still plays one that stayed, after which the playlist drops the other; a held Library Playlist keeps its folder. All pass.
- Three tests played or linked items that were never in the database, which now counts as out of the library: `playbackPlaylistEnterDispatchesSelectedTargetAndDestroysOverlaySession` now plays an indexed cue, and `playbackLibraryEpisodeOpenUsesSharedFolderDetailOrder` indexes the clicked episode under a root; their assertions are unchanged. `playbackExcerptCopiesSettledPrimaryCueAsMarkdownLink` goes through the overlay's Excerpt module, which the playback page does not show, so the check does not apply to it and it passes unchanged.
- `swift test` (full, parallel): 1289 tests; the failures are the environment-sensitive set earlier records name (native playback timing, the two Debug E2E scene and width tests, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`). `addingEmptyFolderRestartsInvalidatedActiveSearch` failed once in one full run on a 10-second wait and passed three times out of three on its own.

## Step 5: the Command Panel through a database change

### What changed

- A Command Panel open on Recent Videos, Recent Excerpt Lists or Search Results when the database changes keeps the rows and the footer count it showed. Going back to the root clears that, and so does closing the panel; a new search starts from the root. Then the pages read the library again (requirement 4.1, 4.2).
- The Search Results actions act on the row the page shows, the preview's own copy of the results, instead of on the search results at the same place, which a change may have moved.
- A row the library no longer holds is refused the way the overlay refuses it, and the panel stays open: Play and a Recent Video's Open show the banner line; Save to Excerpt List and Copy Deep Link show `Not in Library` (requirement 4.3, 4.4, 4.7).
- Opening a Recent Excerpt List with no valid Excerpt says `No Available Excerpts`, with the warning icon, and leaves the panel open. Before, the panel closed and nothing played (requirement 4.6).
- A result played from a page that kept its rows lands on its own place in the new playlist: the place counted in the page's rows is used only when the playlist has the same result there. A held playlist is never refilled from the search results.

Files: `AppCoordinator+PlaybackCommandPanel.swift`, `AppCoordinator+PlaybackLibraryChange.swift`, `AppCoordinator+Playback.swift`, `AppCoordinator+PlaybackPlaylist.swift`, `PlaybackStore.swift`, `PlaybackViewModel.swift`, `PlaybackCommandPanel.swift`.

### Verification

- New tests in `PlaybackLibraryChangeTests`: an open Recent Videos page keeps what it listed and refuses a video that left, until it returns to the root; Search Results keep their rows through a change, refuse Copy Deep Link and Play on a result that left and stay open; a Recent Excerpt List whose only Excerpt left says `No Available Excerpts` and stays open. All pass.
- `swift test` (full, parallel): 1292 tests; the failures are the environment-sensitive set earlier records name (native playback timing, the two Debug E2E scene and width tests, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`, `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`). No new failure.
