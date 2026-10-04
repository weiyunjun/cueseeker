import Foundation
import Testing
@testable import CueSeekerCore

@Test
func librarySortOrderDefaultSortsByFolderTitleCaseInsensitive() {
    let folders = [
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/zeta",
            folderTitle: "zeta",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-05T10:00:00Z"
        ),
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/Alpha",
            folderTitle: "Alpha",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-01T10:00:00Z"
        ),
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/beta",
            folderTitle: "beta",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-03T10:00:00Z"
        )
    ]

    let sorted = folders.sorted(by: .default)
    #expect(sorted.map(\.folderTitle) == ["Alpha", "beta", "zeta"])
}

@Test
func librarySortOrderLatestAddedSortsByIndexedAtDescWithTitleTieBreaker() {
    let folders = [
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/old",
            folderTitle: "Old Show",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-01T10:00:00Z"
        ),
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/same_b",
            folderTitle: "Bravo",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-05T12:00:00Z"
        ),
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/same_a",
            folderTitle: "Alpha",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-05T12:00:00Z"
        )
    ]

    let sorted = folders.sorted(by: .latestAdded)
    // Alpha and Bravo share the same latest timestamp, so tie-breaker orders Alpha then Bravo.
    #expect(sorted.map(\.folderTitle) == ["Alpha", "Bravo", "Old Show"])
}

@Test
func librarySortOrderOldestAddedSortsByIndexedAtAscWithTitleTieBreaker() {
    let folders = [
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/latest",
            folderTitle: "New Show",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-05T12:00:00Z"
        ),
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/same_b",
            folderTitle: "Bravo",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-01T10:00:00Z"
        ),
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/same_a",
            folderTitle: "Alpha",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1,
            indexedAt: "2026-10-01T10:00:00Z"
        )
    ]

    let sorted = folders.sorted(by: .oldestAdded)
    // Alpha and Bravo share the oldest timestamp, tie-breaker orders Alpha then Bravo, followed by New Show.
    #expect(sorted.map(\.folderTitle) == ["Alpha", "Bravo", "New Show"])
}
