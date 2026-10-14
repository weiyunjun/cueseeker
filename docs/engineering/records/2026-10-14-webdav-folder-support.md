# WebDAV Folder Support And Single-Open Cover Generation

Human-owned documents:

- `docs/human/requirements/20261014-Feature-WebDAV Folder Support.md`
- `docs/human/design/Data.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **WebDAV Folder Support (including AList + 115 302 Redirects)**:
   - macOS Finder's `webdavfs` hangs when streaming video over WebDAV roots backed by 302 redirects (such as AList mounting 115 cloud drive), because `webdavfs` treats remote files as block devices and issues unthrottled concurrent chunk requests.
   - Supporting WebDAV natively in CueSeeker—via `PROPFIND` directory scanning, local subtitle caching, and HTTP streaming with 302 redirect resolution that strips WebDAV Basic Auth headers before following cross-origin CDN links—enables smooth indexing and playback on AList + cloud storage setups.
2. **Single-Open In-Process Cover Generation & Concurrency Control**:
   - Previously, `LibraryCoverIndexer` spawned 6 separate `ffmpeg` CLI processes per video (5 for candidate scoring frames at `20%–60%` and a 6th for full-resolution Master cover encoding), multiplying HTTP connection handshakes and risking cloud provider rate-limiting.
   - Sampling all 5 candidate timestamps in a single `AVFormatContext` / decoder session (`+[SFXMediaMetadataInspector sampleCoverFramesAtMediaPath:httpHeaders:timestampsMilliseconds:scoringWidth:scoringHeight:error:]`), keeping the decoded candidate frames in memory during scoring, and encoding the winning frame directly to both Master and Display JPEGs reduces per-video media opens from 6 to 1 while capping WebDAV concurrency (`1` for `Reading video info`, `2` for `Generating covers`).

## What changed

1. **Core WebDAV Infrastructure (`CueSeekerCore`)**:
   - Added `WebDAVSupport.swift` (`WebDAVAddress`, `WebDAVRootConfig`, `WebDAVConfigurationStore`, `WebDAVSubtitleCache`, `WebDAVClient`, `URL.isWebDAVURL`, `URL.mediaPath`, `URL.fromMediaPath(_:)`).
   - Updated `LibraryRootGroups`, `SubtitleIndexer`, `VideoMatcher`, `SubtitleTextDecoder`, `PlaybackSubtitleDatabase`, `IndexingDatabase`, `LibraryDatabase`, `LibraryDatabase+Presentation`, `LibraryDatabase+FileDetail`, `LibraryCoverDatabase`, `IndexedContentDatabase`, and `SearchDatabase` to support canonical `http/https` WebDAV media paths alongside local filesystem paths.
2. **Native Media Inspection, Single-Open Cover Sampling & Streaming (`CNativePlayback` & `CueSeekerPlayback`)**:
   - Added `httpHeaders` and HTTP reconnect options (`reconnect`, `reconnect_streamed`, `reconnect_at_eof`) to `SFXMediaMetadataInspector` and `SFXNativePlaybackPlayer`.
   - Added `+[SFXMediaMetadataInspector sampleCoverFramesAtMediaPath:httpHeaders:timestampsMilliseconds:scoringWidth:scoringHeight:error:]` to decode all 5 candidate frames (`320x180` RGB24 scoring buffer + full-resolution JPEG data) within a single opened media session.
   - Updated `LibraryCoverIndexer`, `PlaybackVideoMetadataIndexer`, `PlaybackPlayer`, `SubtitleScreenshotExporter`, `SourceFaithfulASSSubtitleOverlayView`, `SRTSubtitleRenderer`, and `ASSPlaybackFontIntentProvider` to resolve WebDAV playable inputs and apply per-folder concurrency limits.
3. **File Page `Add Folder` Menu & `WebDav Folder` Dialog (`CueSeekerApp`)**:
   - Added `cloud.svg` Phosphor icon (`AppIcon.cloud`).
   - Changed the File Level 1 `Add Folder` button in `WorkbenchFileView.swift` into a dropdown menu trigger with `Local Folder` (`folder`) and `WebDav Folder` (`cloud`) items.
   - Added `WebDAVFolderDialog.swift` and `WorkbenchFormSecureInputField` in `WorkbenchFormControls.swift` (with `--spacing-4` vertical field spacing, unfocused initial state, disabled inputs and `Add` button spinner while validating, immediate cancellation via `Cancel` / Close / `Esc`, and `Toast` error presentation above the dialog layer).
   - Updated `ContentView.swift` so the `Toast` overlay renders above the modal dialog layer.
4. **Shared Preferences Suite for WebDAV Configs & Dialog Field Editor Focus Isolation**:
   - Updated `WebDAVConfigurationStore` in `WebDAVSupport.swift` to persist `webdavRootConfigs` in `UserDefaults(suiteName: ApplicationInfo.preferencesSuiteIdentifier)` (`"com.cueseeker.shared"`, matching `SettingsStore` and `IndexingStore`) with one-time migration from legacy `com.cueseeker.app` / `CueSeeker` domains, ensuring packaged `/Applications/CueSeeker.app` (e.g. launched via `cueseeker://` Deep Link) and CLI builds share WebDAV credentials and custom names.
   - Updated `CueSeekerMainWindow.swift` (`focusTargetView(for:)`) so that when `responder` is an `NSTextView` (such as AppKit's shared window field editor `_SystemTextFieldFieldEditor`), `isBehindDialog` and `isUncovered` inspect the hosting `NSControl` / `enclosingScrollView` bounds rather than the expanded text container bounds, preventing long URL pastes in `WebDAVFolderDialog` from permanently blocking focus transitions across inputs.

## Verification

- `swift test --filter "WebDAVSupportTests|WebDAVFolderDialogTests|PlaybackPageFocusIsolationTests"`: passed (16 tests).

