import Combine
@testable import CueSeekerCore
@testable import CueSeekerPlayback
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func timelineInteractionStateDoesNotInvalidatePlaybackStore() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        var playbackStoreInvalidations = 0
        var timelineInvalidations = 0
        var scrubTimeInvalidations = 0

        let playbackStoreCancellable = store.objectWillChange.sink {
            playbackStoreInvalidations += 1
        }
        let timelineCancellable = store.timeline.objectWillChange.sink {
            timelineInvalidations += 1
        }
        let scrubTimeCancellable = store.timeline.scrubTimeStore.objectWillChange.sink {
            scrubTimeInvalidations += 1
        }

        store.isTimelineScrubbing = true
        store.timelineScrubTime = 12.5

        #expect(playbackStoreInvalidations == 0)
        #expect(timelineInvalidations == 1)
        #expect(scrubTimeInvalidations == 1)
        #expect(store.isTimelineScrubbing)
        #expect(store.timelineScrubTime == 12.5)

        withExtendedLifetime(playbackStoreCancellable) {}
        withExtendedLifetime(timelineCancellable) {}
        withExtendedLifetime(scrubTimeCancellable) {}
    }
}

@MainActor
@Test
func playbackStoreOpensPlaylistOverlayAtLogicalPlayingItem() throws {
    let suiteName = "CueSeekerPlaylistPositionTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }
    let targetOrdinal = 73
    var requestedOrdinals: [Int] = []
    let source = PlaybackPlaylistSource(kind: .search, totalCount: 100) {
        ordinal in
        requestedOrdinals.append(ordinal)
        guard ordinal >= 0, ordinal < 100 else {
            return nil
        }
        return PlaybackPlaylistItem(
            searchResult: SubtitleSearchResult(
                entryID: Int64(1_000 + ordinal),
                subtitlePath: "/subtitle/\(ordinal).srt",
                subtitleFormat: .srt,
                videoPath: "/video/\(ordinal).mkv",
                videoName: "\(ordinal).mkv",
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 500,
                content: "cue-\(ordinal)",
                cueLines: ["cue-\(ordinal)"]
            ),
            ordinal: ordinal
        )
    }
    let store = PlaybackStore(userDefaults: userDefaults)
    store.setPlaylistSource(source)
    #expect(store.setPlaylistPosition(
        itemIdentity: .search(Int64(1_000 + targetOrdinal)),
        ordinal: targetOrdinal
    ))

    let session = try #require(store.beginSubtitleFocusSession(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot(
            source: SubtitleFocusSourceIdentity(
                videoPath: "/video/\(targetOrdinal).mkv",
                subtitlePath: "/subtitle/\(targetOrdinal).srt",
                subtitleFormat: .srt
            ),
            timestampMilliseconds: targetOrdinal * 1_000,
            wasPlaying: false
        )
    ))

    #expect(session.playlistWindow?.selectedOrdinal == targetOrdinal)
    #expect(session.playlistWindow?.selectedItemIdentity
        == .search(Int64(1_000 + targetOrdinal)))
    #expect(session.selectedModule == .playlist)
    #expect(requestedOrdinals == [targetOrdinal, targetOrdinal])
    store.releaseSubtitleFocusSession(session)
}

@MainActor
@Test
func playbackStoreUsesTheLibrarySessionStoreAsTheMediaPlaylistSource() throws {
    let suiteName = "CueSeekerMediaPlaylistTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }
    let store = PlaybackStore(userDefaults: userDefaults)
    let library = LibraryStore()
    let openSnapshot = PlaybackSubtitleFocusOpenSnapshot(
        source: SubtitleFocusSourceIdentity(
            videoPath: "/video/current.mkv",
            subtitlePath: "/subtitle/current.srt",
            subtitleFormat: .srt
        ),
        timestampMilliseconds: 1_000,
        wasPlaying: false
    )

    let libraryStore = PlaybackLibrarySessionStore(
        libraryStore: library,
        folderPath: "/video"
    )
    let librarySession = try #require(store.beginSubtitleFocusSession(
        openSnapshot: openSnapshot,
        libraryStore: libraryStore
    ))
    #expect(librarySession.availableModules == [.current, .playlist, .collage])
    #expect(librarySession.selectedModule == .current)
    #expect(librarySession.libraryStore === libraryStore)
    store.releaseSubtitleFocusSession(librarySession)
}

@MainActor
@Test
func playbackStoreErrorBannerLifecycleUpdatesImmediately() {
    withTemporaryUserDefaults { userDefaults in
        let store = PlaybackStore(userDefaults: userDefaults)
        #expect(store.errorMessages.isEmpty)

        store.showError("Not in library", on: .notInLibrary)
        #expect(store.errorMessages[.notInLibrary] == "Not in library")

        store.showError("Video load failed", on: .video)
        #expect(store.errorMessages[.video] == "Video load failed")
        #expect(store.errorMessages[.notInLibrary] == "Not in library")

        store.clearError(on: .notInLibrary)
        #expect(store.errorMessages[.notInLibrary] == nil)
        #expect(store.errorMessages[.video] == "Video load failed")

        store.clearAllErrors()
        #expect(store.errorMessages.isEmpty)
    }
}

private func withTemporaryUserDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "CueSeekerAppTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    body(userDefaults)
}


@MainActor
@Test
func appCoordinatorSubtitleAvailabilityAndErrorBannerDistinguishReadableCachedRemoteAndStaleFailures() throws {
    let suiteName = "CueSeekerSubtitleErrorBannerTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(suiteName, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let databaseURL = tempDir.appendingPathComponent("CueSeeker.sqlite")
    let remoteCachedURL = try #require(URL(string: "http://nas.local:5244/dav/\(suiteName)/Episode01.ass"))
    defer {
        WebDAVSubtitleCache.shared.removeCachedSubtitle(for: remoteCachedURL)
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(at: tempDir)
    }

    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let videoURL = tempDir.appendingPathComponent("Episode01.mkv")
    let missingSubtitleURL = tempDir.appendingPathComponent("MissingEpisode01.ass")

    // 1. Missing local subtitle immediately shows top-left subtitle error banner and returns nil.
    let missingResolved = app.loadablePlaybackSubtitleSource(
        PlaybackSubtitleSource(url: missingSubtitleURL, format: .ass, matchedVideoURL: videoURL)
    )
    #expect(missingResolved == nil)
    #expect(app.playback.errorMessages[.subtitle]?.contains(missingSubtitleURL.mediaPath) == true)

    // 2. Cached remote WebDAV subtitle passes ensureSubtitleAvailable, clears previous subtitle error, and returns source.
    _ = try WebDAVSubtitleCache.shared.storeSubtitleData(Data("[Script Info]\n".utf8), for: remoteCachedURL)
    #expect(WebDAVSubtitleCache.shared.ensureSubtitleAvailable(for: remoteCachedURL))
    let cachedRemoteSource = PlaybackSubtitleSource(url: remoteCachedURL, format: .ass, matchedVideoURL: videoURL)
    let remoteResolved = app.loadablePlaybackSubtitleSource(cachedRemoteSource)
    #expect(remoteResolved?.url == remoteCachedURL)
    #expect(app.playback.errorMessages[.subtitle] == nil)

    // 3. Renderer source-load failure shows error only when URL matches currentPlaybackSubtitlePath (stale failures ignored).
    let activePath = tempDir.appendingPathComponent("ActiveCorrupt.ass").path
    let staleURL = tempDir.appendingPathComponent("StaleReplaced.ass")
    app.playbackSubtitle = VideoSubtitle(
        subtitleFileID: 1,
        subtitlePath: activePath,
        format: .ass
    )
    app.handleSubtitleSourceLoadFailure(staleURL)
    #expect(app.playback.errorMessages[.subtitle] == nil)

    app.handleSubtitleSourceLoadFailure(URL(fileURLWithPath: activePath))
    #expect(app.playback.errorMessages[.subtitle]?.contains(activePath) == true)
}

@MainActor
@Test
func appCoordinatorReusesSingleSubtitleRenderCacheReaderAcrossEpisodesAndResolvesExpectedVideoSize() async throws {
    let suiteName = "CueSeekerAppRenderCacheReuseTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(suiteName, isDirectory: true)
    let mediaDir = tempDir.appendingPathComponent("Season1", isDirectory: true)
    try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
    let databaseURL = tempDir.appendingPathComponent("CueSeeker.sqlite")
    defer {
        ASSIndexedPartialLoadDiagnostics.resetForTesting()
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
        try? FileManager.default.removeItem(at: tempDir)
    }

    let episodeSpecs: [(name: String, width: Int, height: Int, codec: String)] = [
        ("Episode01", 1920, 1080, "h264"),
        ("Episode02", 1920, 800, "hevc"),
        ("Episode03", 1280, 720, "av1")
    ]
    var episodePairs: [(videoURL: URL, subtitleURL: URL, width: Int, height: Int, codec: String)] = []
    for (idx, spec) in episodeSpecs.enumerated() {
        let videoURL = mediaDir.appendingPathComponent("\(spec.name).mkv")
        let subtitleURL = mediaDir.appendingPathComponent("\(spec.name).ass")
        try Data("video-\(idx)".utf8).write(to: videoURL)
        let assScript = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: \(spec.width)
        PlayResY: \(spec.height)

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Helvetica,38,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,2,1,2,20,20,24,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:00.20,0:00:03.50,Default,,0,0,0,,Episode \(idx + 1) Opening Cue
        """
        try Data(assScript.utf8).write(to: subtitleURL)
        episodePairs.append((videoURL, subtitleURL, spec.width, spec.height, spec.codec))
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    do {
        let indexingDB = try IndexingDatabase(path: databaseURL)
        let indexResult = try SubtitleIndexer().index(folder: mediaDir, into: indexingDB)
        #expect(indexResult.indexedSubtitleFiles == 3)
        #expect(indexResult.failedFiles.isEmpty)

        let libraryDB = try LibraryDatabase(path: databaseURL)
        for pair in episodePairs {
            try libraryDB.updateVideoMetadata(
                videoFile: pair.videoURL,
                duration: 120.0,
                videoWidth: pair.width,
                videoHeight: pair.height,
                frameRate: 24.0,
                videoCodec: pair.codec,
                audioTracks: []
            )
        }
    }

    ASSIndexedPartialLoadDiagnostics.resetForTesting()
    ASSIndexedPartialLoadDiagnostics.scopedPathSubstringForTesting = suiteName
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    #expect(app.playbackSubtitleRenderCacheReader.openedDatabaseConnectionCountForTesting == 0)

    let renderContainer = PlaybackRenderContainerView()
    renderContainer.frame = CGRect(x: 0, y: 0, width: 640, height: 360)

    for (idx, pair) in episodePairs.enumerated() {
        let openMetadata = app.resolvedOpenVideoPlaybackMetadata(forVideoPath: pair.videoURL.path)
        #expect(openMetadata.codec == pair.codec)
        #expect(openMetadata.expectedVideoSize == CGSize(width: pair.width, height: pair.height))

        let source = try #require(
            app.playbackSubtitleSource(
                forSubtitleFile: pair.subtitleURL,
                format: .ass,
                videoPath: pair.videoURL.path,
                startingAtMilliseconds: 500,
                fallbackEndMilliseconds: 3_500
            )
        )
        let provider = try #require(source.renderCacheProvider)
        let reader = try #require(provider as? PlaybackSubtitleRenderCacheReader)
        #expect(provider.cacheScopeID == app.playbackSubtitleRenderCacheReader.cacheScopeID)
        #expect(reader.cacheScopeID == app.playbackSubtitleRenderCacheReader.cacheScopeID)

        _ = renderContainer.commitSubtitlePresentation(
            source: source,
            videoSize: CGSize(width: pair.width, height: pair.height),
            milliseconds: 500,
            isVisible: true
        )
        let deadline = Date().addingTimeInterval(3.0)
        while ASSIndexedPartialLoadDiagnostics.snapshot.indexedSessionLoadCount < idx + 1 && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(ASSIndexedPartialLoadDiagnostics.snapshot.indexedSessionLoadCount == idx + 1)
    }

    #expect(app.playbackSubtitleRenderCacheReader.openedDatabaseConnectionCountForTesting == 1)
}
