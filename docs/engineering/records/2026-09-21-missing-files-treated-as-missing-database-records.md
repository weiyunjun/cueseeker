# Missing files treated as missing database records

Human-owned documents:

- `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing Database Records.md`
- `docs/human/design/Data.md` (Index 第 7 步; 永久身份与路径分离 补充说明 7)
- `docs/human/design/UI Design System.md`, `docs/human/design/UI Application Rules.md`

## Why

A video or subtitle renamed or moved in Finder leaves the database unchanged, since only Index, Add Folder, Remove Folder and in-App renames write it. Several parts of the App did not take their answer from the database, though, so a file missing on disk behaved like a record missing from the database:

- Entry points asked the disk. The Library video card (also used by Recent Videos, the Videos Playlist and the Command Panel's Recent Videos), the Library folder page's Resume/Play and the Videos Playlist's Return and Play checked that the file existed, and greyed out or refused anything that did not.
- Titles asked the disk. The player's title fell back to listing the subtitle's folder on disk whenever the caller passed no title (Library previous and next, the automatic next video, Excerpt previous and next), and returned the subtitle's file name when the file was not there. Search and Excerpt stored a second Display Title, computed at Index time by ranking the subtitle among the same-extension files on disk, so a video with two subtitles, or a folder mixing extensions, read differently in Search, Excerpt and the Library.
- Current state asked the player. A failed open set a failed status that play and pause and the Playback Overlay refused; the More menu read the video from the player's open file; a Library video only became the Library's after it opened, so its previous and next and its Playlist went dead; Repeat lost its settings. The native player was never told, so the previous video played on.
- The subtitle loaded only after the video had opened, and the ASS renderer painted its own red failure text on the picture, which the App could neither place nor clear.

## What changed

- **Entries follow the database.** The three disk checks are gone. A card, Resume/Play and the Videos Playlist open any video the database holds; the player reports the file.
- **Display Title belongs to the video.** A subtitle's title is its matched video's Library title (`SubtitleDisplayTitleResolver.matchedVideoDisplayTitleSQL`), used when the search order rows are written, refreshed for every subtitle whenever the Library rows are rebuilt, and used for an Excerpt's tombstone. Schema 53 recomputes the stored search titles once. The player's title reads the video's title from the database by path (`LibraryDatabase.displayTitle(forVideoFile:)`), then any title the caller or the model carries, then the video's name. The disk-reading resolver and the fallbacks to it (Anki export, screenshot export, the table rows, the Excerpt file groups, the search log) are removed.
- **A failed open empties the player and nothing else.** One handler serves the Search, Library and Excerpt opens: it stops the player, zeroes the chrome and marks the status `loadFailed`, keeping the page, the selection, the title, the Playlist and the playback source (a Library video stays the Library's). The Playback Overlay opens in this state; the More menu lists the current video's tracks and subtitles from the database and saves both defaults; play, pause, seeking, cue jumps, Repeat and audio track switching do nothing and show no Playback Feedback; volume and speed keep their settings without feedback. Library history is not written for a video that never loaded, including while the next one opens. The failed status is replaced by `loadFailed`, which carries no message: other player failures (player unavailable, pause, resume, audio track switch, stop) show on the banner's video line and block nothing.
- **The subtitle loads on its own.** Every open and every subtitle switch checks that the subtitle file can be read before handing it to the player, whether or not the video opens; a file that cannot be read is not shown, and the ASS segment cache does not stand in for it. A failure the renderer meets afterwards reaches the App through a new delegate call and shows on the same line if it is still the current subtitle. The ASS view no longer draws failure text.
- **One banner.** `PlaybackErrorBanner` sits on the playback page above the Playback Overlay and the Command Panel, anchored to the window at the top bar's height plus `--spacing-3` and `--spacing-6` from the left, as wide as its text up to the window less `--spacing-6` on each side, and never hidden with the Player UI or hit-tested. The video line sits above the subtitle line in one box. Each line stays 5 seconds, or until its source is replaced (a new open clears the video line; a new subtitle load clears the subtitle line), and fades with Toast Motion. The requirement's tokens are in `PlaybackTheme` and `PlaybackChromeMetrics`; the line height is drawn as CSS does, the extra leading set half above and half below each line.

Files:

- `apps/macos-native/Sources/CueSeekerCore/SubtitleDisplayTitleResolver.swift`, `IndexingDatabase.swift`, `LibraryDatabase.swift`, `LibraryDatabase+Presentation.swift`, `DatabaseBootstrap.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackPlayer.swift`, `SRTSubtitleRenderer.swift`, `SourceFaithfulASSSubtitleOverlayView.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppTypes.swift`, `AppCoordinator.swift`, `AppCoordinator+Playback.swift`, `AppCoordinator+Library.swift`, `AppCoordinator+Excerpt.swift`, `AppCoordinator+PlaybackAudioTrack.swift`, `AppCoordinator+PlaybackSubtitle.swift`, `AppCoordinator+PlaybackSubtitleFocus.swift`, `AppCoordinator+AnkiExport.swift`, `AppCoordinator+SubtitleScreenshotExport.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackErrorBanner.swift` (new), `PlaybackPage.swift`, `PlaybackVideoStage.swift`, `PlaybackStore.swift`, `PlaybackTheme.swift`, `PlaybackViewModel.swift`, `SubtitleFocus/PlaybackLibrarySessionStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`, `TableSandbox/TableSandboxRowModelStore.swift`, `Search/SearchPerformanceLogger.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/*.lproj/Localizable.strings`
- Tests: `SubtitleDisplayTitleResolverTests` (rewritten for the new rule), `TableSandboxRowModelStoreTests`, `PlaybackLibraryOverlayTests`, `PlaybackMultiModuleOverlayIntegrationTests`, `PlaybackStoreTests`

## Verification

- `swift build`: compiles.
- `swift test` (full, parallel): 1277 tests, 14 failing, all in the environment-sensitive set earlier records name: seven native playback tests, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, the two Debug E2E scene and width tests, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt` and `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`. Run on their own, those 14 failed 6 times on `f036aa84` without this change and 4 times with it, the 4 among the 6. No new failure.
- Tests that stated the old title rule now state the new one. The disk resolver's tests are replaced by one that indexes `EP01.mkv` with `EP01.sc.srt` and `EP01.tc.srt` and `EP02.mkv` with `EP02.srt`, and expects `Show - 01`, `Show - 01`, `Show - 02` where the disk ranking gave 01, 02, 03. The Search and Excerpt title tests build the Library rows as Index does and expect the video's title; the friendly-title test keeps removing the folder before searching and now also shows that `aa1.ass`, which has no video, no longer shifts the numbers. The table row store tests drop the removed resolver seam and its call counts; the overlay Library tests drop the removed availability seam. The old-schema migration tests build partial databases, so schema 53 refreshes the titles only when the tables it reads are there.
- In-App: not driven here. The requirement leaves the entries, the banner and the renamed-file cases to the owner's acceptance in the App.

## Known limits

- The Debug build migrates the real database to schema 53, which older builds refuse to open.
- `docs/product/03_ui_design.md` and `docs/product/12_liquid_glass_ux_mapping.md` still describe the subtitle-ranked friendly title; they were not changed here.
- The banner, the entries and the renamed-file cases are the owner's acceptance in the App, as the requirement sets out; no E2E capability was added.
