# In-video subtitle switching and default subtitle

Human-owned documents:

- `docs/human/requirements/20260918-Feature-In-Video Subtitle Switching And Default Subtitle.md`
- `docs/human/design/UI Design System.md`, `docs/human/design/Data.md`

## Why

A video can match several subtitle files, but a Library open always played the one whose path sorted first, so `a.en.ass` beat `a.srt`, and nothing on the playback page could change it. The requirement orders a video's subtitles, keeps a per-video default subtitle for the opens that start from the video, and lets the More menu switch the subtitle of the playback in progress.

Classified as data behaviour (ordering and the default subtitle, in `CueSeekerCore`) with playback coordination and a player menu change in the App.

## What changed

- **Ordering lives in Core.** `VideoSubtitles` orders a video's subtitles: those whose name without its last extension equals the video's (compared after Unicode precomposition, as matching compares names) come first, ass before srt; the rest follow in Finder file name order (`localizedStandardCompare`). `effectiveDefault` is the default subtitle when it is still among them, else the first.
- **The default subtitle is user state on the video row.** Schema 52 adds `video_files.default_subtitle_file_id`. It holds a SubtitleID, which `AUTOINCREMENT` never reuses and an in-App rename keeps; Index never writes it. `LibraryDatabase.videoSubtitles(forVideoFile:)` reads the video's matched subtitles with it, and `setDefaultSubtitleFileID(_:forVideoFile:)` saves it.
- **One piece of playback state for the subtitle playing.** `AppCoordinator.playbackSubtitle` holds the subtitle when it is not the one the opened item names. A Library open (Library, Recent Videos, the Videos Playlist and its previous and next, the automatic next video, all through `play(_ video:)`) sets it to the video's default subtitle and plays that; a Search or Excerpt open clears it, so those keep the subtitle their cue belongs to. Repeat does not open anything and leaves it. The current subtitle accessors read it first, so the Playback Overlay's Current, Collage Editor and Save to Excerpt List, which take their source from them when the overlay opens, follow the subtitle playing.
- **Switching keeps the time, the pause and the Playlist.** Picking a subtitle calls the player's `loadSubtitleSource`, which replaces only the subtitle overlay's source at the current time and does not touch the native session. Search previous and next anchor on the opened result's own subtitle instead of the current one, so a switch does not move them.
- **More menu.** The menu lists Audio Track, Subtitle, Default Audio Track, Default Subtitle. `PlaybackMoreMenu` carries one list for the audio tracks and one for the subtitles; a trigger is disabled when its list is empty, and the menu opens highlighting the first enabled trigger. Subtitle checks the subtitle playing and tags the default; Default Subtitle checks the default and tags the one playing. Subtitle items are named by at most the last two extensions of the file name (`.sc.ass`, `.srt`). The subtitle submenus are the audio track submenu's component with its width cap, direction, bounds and scrolling unchanged.

Files:

- `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift`, `LibraryDatabase.swift`, `LibraryDatabaseModels.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackSubtitle.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`, `AppCoordinator+Excerpt.swift`, `AppCoordinator+Library.swift`, `AppCoordinator+Playback.swift`, `AppCoordinator+PlaybackAudioTrack.swift`, `AppCoordinator+Search.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeMoreMenu.swift`, `Playback/PlaybackStore.swift`, `Playback/PlaybackVideoStage.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/*.lproj/Localizable.strings`
- `docs/product/05_data_model.md`
- Tests: `LibraryDatabaseTests`, `DatabaseBootstrapTests`, `LibraryRenameTests`, `PlaybackMoreMenuTests`

## Verification

- `swift build`: compiles.
- New and changed tests pass: the example order `a.ass`, `a.srt`, `a.en.ass`, `a.EN.srt`, `a.jp.ass`, `a.sc.ass`, `a.tc.ass`, with the first subtitle taking effect when no default is set or the one set is gone; a default set on a video indexed for real with `Episode.srt`, `Episode.en.srt`, `Episode.jp.srt` round-trips and survives an Index that changes another subtitle; a folder rename keeps it; schema 51 migrates by adding the column and keeps the video; names read `.sc.ass`, `.srt`, `.1080p.ass`; Subtitle and Default Subtitle check and tag the opposite subtitles; the menu keys reach Subtitle second, move inside its own list and reach Default Audio Track third; a menu with subtitles and no audio track highlights Subtitle and skips the audio track triggers; all four submenus stay in their room at the narrowest window.
- `swift test` (parallel): 1258 tests, failures only in the environment-sensitive set of earlier records: native playback, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, Debug E2E scene and width, Library folder removal, Excerpt remount and scoped invalidation, `progressiveSearchProjectionRefreshesOnlyMountedTable`. Run serially, the playback test target passes (80 tests) and the folder removal, Debug E2E, auto-pause and search projection tests pass (5 tests); the two Excerpt remount tests fail serially as well, as recorded before this change.
- In-App: not driven here. The Debug build migrates the real database to schema 52, which older builds refuse to open, and the requirement leaves the menu and the subtitles on screen to the owner's acceptance in the App.

## Known limits

- Found while testing, not changed here: deleting one of several subtitle files of a video and indexing removes the video row, so its other subtitles have no video until the next Index, which creates the video again under a new VideoID. Measured with the real indexer on `Episode.mkv` with `Episode.srt`, `Episode.en.srt` and `Episode.jp.srt`: after deleting `Episode.jp.srt`, one Index left both remaining subtitles unmatched and no video row, and the next Index matched them to video 2 instead of 1. Everything bound to the VideoID goes with it, the default subtitle included, so requirement acceptance item 4 cannot be met as intended until this is fixed under its own requirement. The tests here cover the fallback on the ordering model and the default surviving an Index that changes another subtitle, not that deletion.
- The menu, the subtitle switch on screen and the provisional names have not been seen in the App; the requirement leaves them to the owner's acceptance.
