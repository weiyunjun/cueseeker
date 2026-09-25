import Foundation
import AppKit
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

/// Playback when an Add Folder, Index or Remove Folder changes the database
/// under it. See `docs/human/requirements/20260925-Feature-Playback Continues
/// When Content Leaves The Database.md`.

@MainActor
@Test
func aHeldPlaylistKeepsItsItemsRenumberedAndNoLongerFollowsTheStores() {
    let results = (1...3).map { libraryChangeSearchResult(entryID: Int64($0)) }
    let source = PlaybackPlaylistSource(
        origin: .search(resultListGeneration: 1),
        totalCount: results.count
    ) { ordinal in
        PlaybackPlaylistItem(searchResult: results[ordinal], ordinal: ordinal)
    }

    source.holdItems([
        try! #require(source.item(at: 0)),
        try! #require(source.item(at: 2)),
    ])

    #expect(source.isHeld)
    #expect(source.boundary.totalCount == 2)
    #expect(source.item(at: 1)?.identity == .search(3))
    #expect(source.item(at: 1)?.ordinal == 1)
    #expect(!source.replaceResidentItems(totalCount: 3) { _ in nil })
    #expect(!source.updateBoundary(totalCount: 5))
    #expect(source.boundary.totalCount == 2)
}

@MainActor
@Test
func previousAndNextFromASearchResultTheLibraryDroppedGoToTheFirstResultStillInIt() async throws {
    try await withLibraryChangeApp { app, database in
        app.ensurePlayerInitialized()
        for name in ["A", "B", "C"] {
            try indexLibraryChangeVideo(name, in: database)
        }
        let results = try SearchDatabase(path: database.path)
            .search("placeholder")
            .sorted { $0.videoPath < $1.videoPath }
        #expect(results.map(\.videoName) == ["A.mkv", "B.mkv", "C.mkv"])
        app.search.replaceResultState(
            results: results,
            status: app.search.searchStatus,
            totalCount: results.count,
            fileSummaries: [],
            countState: .exact,
            knownResultCount: results.count,
            knownFileCount: results.count,
            hasMore: false
        )
        app.openSearchResult(
            results[1],
            playbackSearchPromotion: PlaybackSearchPromotion(
                query: "placeholder",
                scopePaths: [],
                selectedOrdinal: 1
            )
        )
        #expect(app.playback.playlistSource?.boundary.totalCount == 3)

        // A and B leave the library; B plays on.
        app.holdPlaybackBeforeIndexedContentChange()
        try emptyLibraryChangeSubtitle("A", in: database)
        try emptyLibraryChangeSubtitle("B", in: database)
        app.reconcilePlaybackAfterIndexedContentChange()

        #expect(app.currentPlaybackItemLeftLibrary)
        #expect(app.search.selectedSearchResult?.entryID == results[1].entryID)
        #expect(app.playback.playlistSource?.boundary.totalCount == 1)
        #expect(app.playback.chromeSnapshot.canGoPrevious)
        #expect(app.playback.chromeSnapshot.canGoNext)

        // Previous goes to the first result still in the library, C.
        app.goPrevious()
        #expect(app.search.selectedSearchResult?.entryID == results[2].entryID)
        #expect(!app.currentPlaybackItemLeftLibrary)
        #expect(app.playback.playlistPosition?.ordinal == 0)

        // C leaves too: there is nowhere to go.
        app.holdPlaybackBeforeIndexedContentChange()
        try emptyLibraryChangeSubtitle("C", in: database)
        app.reconcilePlaybackAfterIndexedContentChange()

        #expect(app.currentPlaybackItemLeftLibrary)
        #expect(app.playback.playlistSource?.boundary.totalCount == 0)
        #expect(!app.playback.chromeSnapshot.canGoNext)
        app.goNext()
        #expect(app.search.selectedSearchResult?.entryID == results[2].entryID)
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "No Available Results"
        )
    }
}

@MainActor
@Test
func aPlaylistShownThroughADatabaseChangeDropsWhatLeftOnlyOnceTheOverlayCloses() async throws {
    try await withLibraryChangeApp { app, database in
        app.ensurePlayerInitialized()
        for name in ["A", "B"] {
            try indexLibraryChangeVideo(name, in: database)
        }
        let results = try SearchDatabase(path: database.path)
            .search("placeholder")
            .sorted { $0.videoPath < $1.videoPath }
        app.search.replaceResultState(
            results: results,
            status: app.search.searchStatus,
            totalCount: results.count,
            fileSummaries: [],
            countState: .exact,
            knownResultCount: results.count,
            knownFileCount: results.count,
            hasMore: false
        )
        app.openSearchResult(
            results[0],
            playbackSearchPromotion: PlaybackSearchPromotion(
                query: "placeholder",
                scopePaths: [],
                selectedOrdinal: 0
            )
        )
        app.playback.presentCommandPanel(
            PlaybackCommandPanelPresentation(
                page: .root,
                query: "",
                selectedOrdinal: nil,
                resumesPlaybackOnDismiss: false
            )
        )

        app.holdPlaybackBeforeIndexedContentChange()
        try emptyLibraryChangeSubtitle("B", in: database)
        app.reconcilePlaybackAfterIndexedContentChange()

        #expect(!app.currentPlaybackItemLeftLibrary)
        #expect(app.playbackAwaitsLibraryReconcile)
        #expect(app.playback.playlistSource?.boundary.totalCount == 2)

        app.playback.dismissCommandPanel()
        app.reconcilePlaybackPlaylistIfAwaiting()

        #expect(!app.playbackAwaitsLibraryReconcile)
        #expect(app.playback.playlistSource?.boundary.totalCount == 1)
        #expect(app.playback.playlistPosition?.ordinal == 0)
        #expect(!app.playback.chromeSnapshot.canGoNext)
    }
}

@MainActor
@Test
func nextFromATombstonedExcerptGoesToTheFirstExcerptStillInTheLibrary() async throws {
    try await withLibraryChangeApp { app, database in
        app.ensurePlayerInitialized()
        var excerpts: [Excerpt] = []
        for name in ["A", "B", "C"] {
            try indexLibraryChangeVideo(name, in: database)
            let selection = try #require(
                try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
                    forSubtitleFile: URL(fileURLWithPath: "/Media/\(name).srt"),
                    atMilliseconds: 1_500
                )
            )
            excerpts.append(
                try ExcerptDatabase(path: database.path).upsertExcerpt(
                    selection: selection
                )
            )
        }
        let excerptIDs = excerpts.map(\.id)
        app.openExcerpt(
            excerpts[1],
            navigationScopeIDs: excerptIDs,
            playlistScope: .explicitIDs(excerptIDs),
            playlistSelectedOrdinal: 1
        )
        #expect(app.playback.playlistSource?.boundary.totalCount == 3)

        // The cues of A and B go to the tombstone; B plays on.
        app.holdPlaybackBeforeIndexedContentChange()
        try emptyLibraryChangeSubtitle("A", in: database)
        try emptyLibraryChangeSubtitle("B", in: database)
        app.reconcilePlaybackAfterIndexedContentChange()

        #expect(app.currentPlaybackItemLeftLibrary)
        #expect(app.excerpt.selectedExcerpt?.id == excerpts[1].id)
        #expect(app.playback.playlistSource?.boundary.totalCount == 1)

        app.goNext()
        #expect(app.excerpt.selectedExcerpt?.id == excerpts[2].id)
        #expect(!app.currentPlaybackItemLeftLibrary)
        #expect(app.playback.playlistPosition?.ordinal == 0)
    }
}

@MainActor
@Test
func nextFromALibraryVideoTheLibraryDroppedGoesToTheFirstVideoOfItsFolder() async throws {
    try await withLibraryChangeApp { app, database in
        app.ensurePlayerInitialized()
        for name in ["A", "B"] {
            try indexLibraryChangeVideo(name, in: database)
        }
        try LibraryDatabase(path: database.path)
            .refreshPresentationAfterIndexedContentChange()
        let media = URL(fileURLWithPath: "/Media")
        app.indexing.appendFolder(media)
        let videos = try #require(app.libraryDatabase).libraryVideos(under: [media])
        let videoA = try #require(videos.first { $0.videoPath == "/Media/A.mkv" })
        let videoB = try #require(videos.first { $0.videoPath == "/Media/B.mkv" })
        app.library.libraryVideos = videos
        app.openLibraryVideo(videoB)
        // What the play step that follows the open sets, on a later turn.
        app.activePlaybackSource = .library(videoPath: videoB.videoPath)

        // B leaves the library with its only subtitle and plays on.
        try database.removeStaleEntries(under: media, keeping: ["/Media/A.srt"])
        try LibraryDatabase(path: database.path)
            .refreshPresentationAfterIndexedContentChange()
        app.reconcilePlaybackAfterIndexedContentChange()

        #expect(app.currentPlaybackItemLeftLibrary)
        #expect(app.library.selectedLibraryVideo == videoB)
        #expect(app.playback.chromeSnapshot.canGoNext)

        app.goNext()
        #expect(app.library.selectedLibraryVideo?.videoPath == videoA.videoPath)
        #expect(!app.currentPlaybackItemLeftLibrary)

        // A leaves too: there is no video left in the folder.
        try database.removeStaleEntries(under: media, keeping: [])
        try LibraryDatabase(path: database.path)
            .refreshPresentationAfterIndexedContentChange()
        app.reconcilePlaybackAfterIndexedContentChange()

        #expect(!app.playback.chromeSnapshot.canGoPrevious)
        app.goPrevious()
        #expect(app.library.selectedLibraryVideo?.videoPath == videoA.videoPath)
        #expect(
            app.playback.playbackViewModel?.feedback?.text
                == "No Available Videos"
        )
    }
}

private func libraryChangeSearchResult(entryID: Int64) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: entryID,
        subtitlePath: "/Media/\(entryID).srt",
        subtitleFormat: .srt,
        videoPath: "/Media/\(entryID).mkv",
        videoName: "\(entryID).mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "cue \(entryID)",
        cueLines: ["cue \(entryID)"]
    )
}

private func indexLibraryChangeVideo(
    _ basename: String,
    in database: IndexingDatabase
) throws {
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/\(basename).srt"),
        videoFile: URL(fileURLWithPath: "/Media/\(basename).mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "placeholder \(basename)"
            )
        ]
    )
}

/// The subtitle stays matched to its video but no longer has the cue.
private func emptyLibraryChangeSubtitle(
    _ basename: String,
    in database: IndexingDatabase
) throws {
    try database.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/\(basename).srt"),
        videoFile: URL(fileURLWithPath: "/Media/\(basename).mkv"),
        entries: []
    )
}

@MainActor
private func withLibraryChangeApp(
    _ body: @MainActor (AppCoordinator, IndexingDatabase) throws -> Void
) async throws {
    let suiteName = "CueSeekerLibraryChangeTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerLibraryChangeTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    let database = try #require(app.indexingDatabase)
    try body(app, database)
}
