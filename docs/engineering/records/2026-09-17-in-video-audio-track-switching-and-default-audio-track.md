# In-video audio track switching and default audio track

Human-owned documents:

- `docs/human/requirements/20260917-Feature-In-Video Audio Track Switching And Default Audio Track.md`
- `docs/human/design/UI Design System.md`, `docs/human/design/UI Application Rules.md`, `docs/human/design/Data.md` (cited by the requirement; they are updated by the owner after acceptance)

## Why

The player opened the first audio stream of a file and could not change it, and Anki export ran ffmpeg without naming a stream, so ffmpeg chose one itself: the stream flagged default, else the one with the most channels. Measured with two generated files, ffmpeg took the second stream both when it carried the default flag and when it was the only 5.1 stream, while the player would have played the first. A file whose first audio stream is neither could play one language and export another.

Classified as playback and data behaviour with a new player menu.

## What changed

- **Index records every audio stream.** Media inspection lists the audio streams in file order with their language (`und` dropped), title, codec name and channel count, and Index stores the list as JSON in `video_files.audio_tracks`. Schema 51 adds that column and `default_audio_track_index`. A video with no list (`NULL`) joins the videos whose metadata the next Index inspects again, so libraries indexed before schema 51 fill in on their next Index; an inspected video without audio stores an empty list.
- **The default audio track is user state on the video row.** `default_audio_track_index` counts from 0 among the audio streams, follows the video's identity (the path; an in-App rename keeps it) and is never written by Index, even when a later list is shorter. `VideoAudioTracks.effectiveDefaultIndex` gives the track that takes effect.
- **The player selects a track by its place among the audio streams.** `SFXNativePlaybackPlayer.audioTrackIndex` is read when a session opens; a file without that track plays its first one, and `currentAudioTrackIndex` reports the track in effect. `selectAudioTrackIndex:` reopens the session at the current position under the same presentation generation, the way the automatic software recycle does, keeping the segment end and staying paused when paused or finished. Every Library, Search and Excerpt open passes the video's default audio track in `PlaybackRequest.audioTrackIndex`; a seek within the open video keeps the track playing.
- **Anki export maps the default audio track.** Each item carries its video's default audio track, and the audio clip is cut with `-map 0:a:N`. A track past the first is checked against the file first, once per video, and falls back to the first when the file does not have it.
- **More button and menu.** The bottom bar ends with a More button (`dots-three-vertical`, the Phosphor regular master, which is drawn in fills), with the fullscreen button moved one place left. Its menu lists Audio Track and Default Audio Track as Submenu Triggers, disabled when the video has no recorded track. Each submenu lists the recorded tracks as `#N language, title, codec, Nch`, with the language named in the interface language (`AppLocalization.locale`), checks one track and tags the other: Audio Track checks the track playing and tags the default; Default Audio Track checks the default and tags the track playing. Picking a track closes both menus; picking the checked one changes nothing.
- **The menu reuses the shared menu machinery.** The table row menu's submenu state, safe area and geometry moved to `Shared/MenuSubmenu.swift` as generic types and serve both menus. `WorkbenchPopoverPanel` gained a Player Chrome surface with the speed menu's fill, border, radius and padding, so the submenu scrolls and widens by the scrollbar strip like every menu. The menu gate client takes a submenu frame and reports the pointer for the safe area. The menus are hosted over the whole playback stage, so a long list has the stage's height; they report their frames as clickable regions for the Player UI's idle hide, and they close when the Player UI hides, another video opens or the page goes away.
- Provisional values, pending acceptance: the More menu is as wide as the speed menu, the audio track submenus are 300pt wide, and the tag uses the Tag shape with `--color-player-control-bg-hover` and `--color-player-text-secondary`.

Files:

- `apps/macos-native/Sources/CNativePlayback/SFXMediaMetadataInspector.m`
- `apps/macos-native/Sources/CNativePlayback/SFXNativePlaybackPlayer.m`
- `apps/macos-native/Sources/CNativePlayback/include/SFXNativePlaybackPlayer.h`
- `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift`
- `apps/macos-native/Sources/CueSeekerCore/IndexingDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/LibraryDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseModels.swift`
- `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseProtocols.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackPlayer.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackTypes.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackVideoMetadataIndexer.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackAudioTrack.swift` (new)
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+AnkiExport.swift`, `AppCoordinator+Excerpt.swift`, `AppCoordinator+Library.swift`, `AppCoordinator+Playback.swift`, `AppLocalization.swift`
- `apps/macos-native/Sources/CueSeekerApp/Export/AnkiPackageExporter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeMoreMenu.swift` (new), `PlaybackChromeIconButton.swift`, `PlaybackChromeSpeedMenu.swift`, `PlaybackChromeView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`, `PlaybackTheme.swift`, `PlaybackVideoStage.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuSubmenu.swift` (new), `MenuGate.swift`, `AppIcon.swift`, `WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/dots-three-vertical.svg` (new), `Resources/*.lproj/Localizable.strings`
- `docs/product/05_data_model.md`
- Tests: `DatabaseBootstrapTests`, `LibraryDatabaseTests`, `SubtitleIndexerTests`, `PlaybackVideoMetadataIndexerTests`, `NativePlaybackMediaTimelineTests`, `AppIconAssetTests`, `SubtitleTableRowActionMenuTests`, `PlaybackMoreMenuTests` (new)

## Verification

- `ffprobe` on the sample `[Darkness] Fate Stay Night - S01E01`: three Opus stereo audio streams tagged `jpn`, `eng`, `fre`, none titled, the first flagged default.
- `swift build`: compiles.
- New tests: schema 50 migrates by adding the two columns and keeps the video; the track list and the default track round-trip, the default survives a shorter list and the first track takes effect; a video without a track list is inspected again on the next Index; names read `#1 日语, opus, 2ch` and `#2 Japanese, Commentary, aac, 2ch`; submenus check and tag the opposite tracks; the menu keys open a submenu on its first track, move inside it, close it with left and pick with Enter; a generated file with two audio streams inspects as `jpn`/`eng`, opens on the requested track, falls back to the first for a missing one, and switches while paused at 2s without moving or resuming. The table's submenu tests pass against the shared types, and the icon test accepts a fill-only master.
- `swift test` (parallel): 1245 tests, failures only in the environment-sensitive set of earlier records: native playback, `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, Debug E2E scene and width, Library folder removal, Excerpt remount and scoped invalidation, `progressiveSearchProjectionRefreshesOnlyMountedTable`, plus `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` and the new native audio track test. The playback test target run serially passes (80 tests), and the migration tests, the facet refresh test and the audio track test pass alone. The two Excerpt remount tests also fail serially, as recorded before this change.
- In-App: not driven here. The Debug build opens the real database and migrates it to schema 51, which older builds refuse to open, and the requirement leaves the menu and the audio to the owner's acceptance in the App.

## Known limits

- The menu's layout, the tag colours and the provisional widths have not been seen in the App.
- A software-decoded session reopens itself once after its first frame and does not keep a pause through that; a track switch made within that first moment inherits it.
