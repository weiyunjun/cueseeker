import Combine
import CueSeekerCore
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
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
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
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
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
    #expect(librarySession.availableModules == [.current, .playlist])
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
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    body(userDefaults)
}
