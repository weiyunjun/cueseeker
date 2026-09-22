# Display Title computed when Index publishes core data

Human-owned documents:

- `docs/human/requirements/20260923-Bug-Display Title Computed When Index Publishes Core Data.md`
- `docs/human/design/Data.md` (Index流程 第 4 步、第 7 步)
- `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing Database Records.md` (4.8 Display Title)

## Why

The previous requirement made Display Title belong to the video, but the only place that named a video was the Library rows, which Index rebuilds in its last step, after the video metadata and the covers. Search publishes its rows in step 4 and fell back to the video's name for any video the Library rows did not hold yet. So between step 4 and step 7, and for as long as a failed or unfinished step 7 left the library's retry mark set (until the next Index of that library), a new video, or one renamed or moved in Finder, read as its file name in Search, in an Excerpt saved then and in the player's title opened from Search, and Search sorted it by that name. Step 7 then changed the title and the order.

## What changed

- **The video holds its Display Title.** `video_files` has a `display_title` column (schema 54). `LibraryDatabase.refreshVideoDisplayTitles(inFolderPaths:)` names the matched videos of the given folders with the Library's rule and the Library's order: the folder's name and the video's place among the folder's videos, padded to the digits of the folder's video count and at least two.
- **Named when the Search rows are written.** Refreshing or rebuilding the Search order rows names the videos of those folders first, in the same transaction. That is Index step 4, the in-App rename and the stale-entry removal, so Search, Excerpt and the tombstone snapshot read the final title from the moment the core data is published, and a failed or unfinished step 7 no longer touches it.
- **Step 7 copies, it does not name.** The Library rows take the video's `display_title`; the numbering and the refresh of the Search titles after the rebuild are gone.
- **One source for every reader.** A subtitle's title SQL reads its matched video's `display_title` with no fallback to the video's name. The player's title reads it from `video_files` for a video a subtitle still matches.
- **Upgrade.** Schema 54 adds the column, names every video once, and brings the stored Search titles and the existing Library rows in line, including in a library whose retry mark is still set. Schema 53 only realigned the Search titles, which this does too, so a schema 52 database goes straight to 54.

Files:

- `apps/macos-native/Sources/CueSeekerCore/LibraryDatabase+Presentation.swift`, `IndexingDatabase.swift`, `SubtitleDisplayTitleResolver.swift`, `LibraryDatabase.swift`, `DatabaseBootstrap.swift`
- Tests: `SubtitleDisplayTitleResolverTests`, `SearchDatabaseTests`, `PlaybackEntryAndExcerptNavigationTests`, `PlaybackExcerptOverlayTests`

## Verification

- `swift build`: compiles.
- `SubtitleDisplayTitleResolverTests`: the title test now checks the Search titles right after the core data is published, while the Library rows are still empty, and again after they are rebuilt, where the Library rows carry the same titles. Before this change the first check would have read the videos' file names, the fallback the old title SQL took with no Library row. A new test takes a database back to schema 53 (no title on the video, a file name in Search for a video whose Library row was never rebuilt, a stale Library title) and expects the upgrade to realign all of them.
- Four fixtures leaned on the removed fallback, a video without a Library row titled by its file name, and now state the rule; no assertion was loosened. The two Search order tests put Alpha in `ZFolder` and Beta in `AFolder` and expected Alpha first only because the titles were the file names; the folders are swapped, so the product order still differs from the insertion order. The player title test expected the arbitrary title the entry passed, since the database had none; the video's own title in the database wins, as the previous requirement set, so it expects `Media - 02` and `Media - 04`. The Excerpt search test proved that search skips the title by probing the file name the row showed; it now probes the Display Title `Media - 01`.
- `swift test` (full, parallel): 1278 tests, 14 failing, none from this change: 13 of the environment-sensitive set earlier records name (the native playback tests, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, the two Debug E2E scene and width tests, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`), and `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`, a view refresh count that fails only under the full parallel run and passed four times out of four on its own. The failures are window sizes, scroll anchors, playback timing and refresh counts; none reads a title.
- In-App: not driven here. The requirement leaves its acceptance to the owner.

## Known limits

- The Debug build migrates the real database to schema 54, which older builds refuse to open.
- A library whose retry mark is set still misses the Library rows of its new videos until its next Index; only their titles are fixed, as the requirement keeps the rest of step 7 where it is.
- `docs/human/design/Data.md` still names Display Title in step 7; the owner updates it at acceptance.
