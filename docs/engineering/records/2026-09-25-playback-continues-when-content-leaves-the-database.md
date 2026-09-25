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
