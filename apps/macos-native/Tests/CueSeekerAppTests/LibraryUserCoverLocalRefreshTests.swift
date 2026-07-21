import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@Test
@MainActor
func libraryUserVideoCoverRefreshUpdatesOnlyMatchingCoverSnapshots() {
    let store = LibraryStore()
    let firstRecent = localRefreshRecentPresentation(index: 1)
    let secondRecent = localRefreshRecentPresentation(index: 2)
    let firstVideo = localRefreshVideoPresentation(index: 1)
    let secondVideo = localRefreshVideoPresentation(index: 2)
    let detail = CompleteLibraryFolderDetailPresentation(
        folderPath: "/Media/Show",
        folderTitle: "Show",
        videos: [firstVideo, secondVideo]
    )
    let summary = localRefreshFolderSummary(index: 1)
    store.recentWatchingItems = [firstRecent, secondRecent]
    store.testRecentWatchingItems = [firstRecent, secondRecent]
    store.completeLibraryFolderDetailsByPath = [detail.folderPath: detail]
    store.completeLibraryFolderSummaries = [summary]
    store.recentWatchingRevision = 7
    store.testRecentWatchingRevision = 8
    store.completeLibraryRevision = 9

    let result = LibraryUserCoverSaveResult(
        displayCoverPath: "/Covers/User/Display/v1/new-video.jpg",
        coverRevision: "new-video-revision",
        replacedDisplayCoverPath: "/Covers/User/Display/v1/old-video.jpg"
    )
    store.applyUserCoverSave(result, target: .video(path: firstVideo.videoPath))

    #expect(store.recentWatchingItems[0].coverPath == result.displayCoverPath)
    #expect(store.recentWatchingItems[0].coverRevision == result.coverRevision)
    #expect(store.recentWatchingItems[1] == secondRecent)
    #expect(store.testRecentWatchingItems[0].coverPath == result.displayCoverPath)
    #expect(store.testRecentWatchingItems[1] == secondRecent)
    #expect(
        store.completeLibraryFolderDetailsByPath[detail.folderPath]?.videos[0].coverPath
            == result.displayCoverPath
    )
    #expect(
        store.completeLibraryFolderDetailsByPath[detail.folderPath]?.videos[1]
            == secondVideo
    )
    #expect(store.completeLibraryFolderSummaries == [summary])
    #expect(store.recentWatchingRevision == 7)
    #expect(store.testRecentWatchingRevision == 8)
    #expect(store.completeLibraryRevision == 9)
}

@Test
@MainActor
func libraryUserFolderCoverRefreshUpdatesOnlyMatchingFolderSnapshot() {
    let store = LibraryStore()
    let first = localRefreshFolderSummary(index: 1)
    let second = localRefreshFolderSummary(index: 2)
    store.completeLibraryFolderSummaries = [first, second]
    store.completeLibraryRevision = 4

    let result = LibraryUserCoverSaveResult(
        displayCoverPath: "/Covers/User/Display/v1/new-folder.jpg",
        coverRevision: "new-folder-revision",
        replacedDisplayCoverPath: nil
    )
    store.applyUserCoverSave(result, target: .folder(path: first.folderPath))

    #expect(store.completeLibraryFolderSummaries[0].coverPath == result.displayCoverPath)
    #expect(store.completeLibraryFolderSummaries[0].coverRevision == result.coverRevision)
    #expect(store.completeLibraryFolderSummaries[1] == second)
    #expect(store.completeLibraryRevision == 4)
}

private func localRefreshRecentPresentation(
    index: Int
) -> RecentLibraryWatchingPresentation {
    RecentLibraryWatchingPresentation(
        videoPath: "/Media/Show/Episode \(index).mkv",
        videoName: "Episode \(index).mkv",
        duration: 100,
        subtitlePath: "/Media/Show/Episode \(index).srt",
        subtitleFormat: .srt,
        displayTitle: "Episode \(index)",
        fileExtension: "mkv",
        folderPath: "/Media/Show",
        folderTitle: "Show",
        episodeNumber: index,
        positionMilliseconds: 1_000,
        playbackDuration: 100,
        startedAt: "2026-07-22T00:00:00Z",
        completedAt: nil,
        updatedAt: "2026-07-22T00:00:00Z",
        coverPath: "/Covers/Display/v1/old-\(index).jpg",
        coverRevision: "old-\(index)"
    )
}

private func localRefreshVideoPresentation(
    index: Int
) -> CompleteLibraryVideoPresentation {
    CompleteLibraryVideoPresentation(
        videoPath: "/Media/Show/Episode \(index).mkv",
        videoName: "Episode \(index).mkv",
        fileSize: 1_024,
        videoCodec: "h264",
        videoWidth: 1_920,
        videoHeight: 1_080,
        frameRate: 24,
        duration: 100,
        subtitlePath: "/Media/Show/Episode \(index).srt",
        subtitleFormat: .srt,
        displayTitle: "Episode \(index)",
        fileExtension: "mkv",
        episodeNumber: index,
        positionMilliseconds: 1_000,
        playbackDuration: 100,
        startedAt: "2026-07-22T00:00:00Z",
        completedAt: nil,
        historyUpdatedAt: "2026-07-22T00:00:00Z",
        coverPath: "/Covers/Display/v1/old-\(index).jpg",
        coverRevision: "old-\(index)"
    )
}

private func localRefreshFolderSummary(
    index: Int
) -> CompleteLibraryFolderSummaryPresentation {
    CompleteLibraryFolderSummaryPresentation(
        folderPath: "/Media/Show \(index)",
        folderTitle: "Show \(index)",
        coverPath: "/Covers/Display/v1/folder-\(index).jpg",
        coverRevision: "folder-\(index)",
        episodeCount: 12
    )
}
