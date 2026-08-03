import Foundation
import Testing
@testable import CueSeekerCore

@Test
func subtitleFocusStandardWindowPlacesSelectionSeventhWhenBoundariesAllow() {
    let policy = SubtitleFocusWindowPolicy.standard

    #expect(policy.windowRange(totalCount: 20, selectedOrdinal: 12) == 6..<16)
    #expect(policy.windowRange(totalCount: 20, selectedOrdinal: 2) == 0..<10)
    #expect(policy.windowRange(totalCount: 20, selectedOrdinal: 19) == 10..<20)
    #expect(policy.windowRange(totalCount: 7, selectedOrdinal: 3) == 0..<7)
}

@Test
func subtitleFocusDatabaseBootstrapLoadsSixBeforeAndThreeAfter() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Focus.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Focus.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: (0..<20).map { index in
            SubtitleEntry(
                sequenceNumber: index + 1,
                startTimecode: String(format: "00:00:%02d,000", index),
                endTimecode: String(format: "00:00:%02d,900", index),
                startMilliseconds: index * 1_000,
                endMilliseconds: index * 1_000 + 900,
                text: "cue \(index)"
            )
        }
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let snapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 12_500
    ))
    #expect(snapshot.totalCount == 20)
    #expect(snapshot.selectedOrdinal == 12)
    #expect(snapshot.cues.map(\.ordinal) == Array(6..<16))
    #expect(snapshot.cues[6].text == "cue 12")
    #expect(snapshot.selectedCue == snapshot.cues[6])
}

@Test
func subtitleFocusDatabaseUsesPermanentIDAcrossUnicodeNormalizationForms() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let fixtures = [
        (label: "Japanese", composed: "ゼ", decomposed: "セ\u{3099}"),
        (label: "Latin", composed: "é", decomposed: "e\u{0301}"),
        (label: "Hangul", composed: "가", decomposed: "\u{1100}\u{1161}"),
    ]

    for fixture in fixtures {
        let storedSubtitlePath = "/Media/\(fixture.label)-\(fixture.composed).srt"
        let alternateSubtitlePath = "/Media/\(fixture.label)-\(fixture.decomposed).srt"
        #expect(storedSubtitlePath == alternateSubtitlePath)
        #expect(Array(storedSubtitlePath.utf8) != Array(alternateSubtitlePath.utf8))

        let videoFile = URL(fileURLWithPath: "/Media/\(fixture.label).mkv")
        try database.replaceEntries(
            subtitleFile: URL(fileURLWithPath: storedSubtitlePath),
            videoFile: videoFile,
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:02,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 2_000,
                    text: fixture.label
                )
            ]
        )

        let libraryVideo = try #require(
            try LibraryDatabase(path: databaseURL)
                .libraryVideos(under: [URL(fileURLWithPath: "/Media")])
                .first { $0.videoPath == videoFile.path }
        )
        let subtitleFileID = try #require(libraryVideo.subtitleFileID)
        let playbackDatabase = try PlaybackSubtitleDatabase(path: databaseURL)
        let snapshot = try #require(
            try playbackDatabase.subtitleFocusInitialSnapshot(
                forSubtitleFileID: subtitleFileID,
                atMilliseconds: 1_500
            )
        )
        #expect(snapshot.selectedCue?.text == fixture.label)

        let batch = try playbackDatabase.subtitleFocusCueBatch(
            forSubtitleFileID: subtitleFileID,
            totalCount: snapshot.totalCount,
            startingAtOrdinal: 0,
            limit: snapshot.totalCount
        )
        #expect(batch.cues.map(\.text) == [fixture.label])
    }
}

@Test
func subtitleFocusDatabaseBootstrapFillsInitialWindowAtDocumentBoundaries() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Focus-Boundaries.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Focus-Boundaries.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: focusEntries(count: 20)
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let firstSnapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 100
    ))
    #expect(firstSnapshot.selectedOrdinal == 0)
    #expect(firstSnapshot.cues.map(\.ordinal) == Array(0..<10))

    let lastSnapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 19_500
    ))
    #expect(lastSnapshot.selectedOrdinal == 19)
    #expect(lastSnapshot.cues.map(\.ordinal) == Array(10..<20))

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: focusEntries(count: 7)
    )
    let shortSnapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 3_500
    ))
    #expect(shortSnapshot.totalCount == 7)
    #expect(shortSnapshot.cues.map(\.ordinal) == Array(0..<7))
}

@Test
func subtitleFocusDatabaseBootstrapUsesPreviousCueAndFallsBackToFirstCue() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Gaps.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Gaps.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: (0..<12).map { index in
            SubtitleEntry(
                sequenceNumber: index + 1,
                startTimecode: String(format: "00:00:%02d,000", index + 1),
                endTimecode: String(format: "00:00:%02d,250", index + 1),
                startMilliseconds: (index + 1) * 1_000,
                endMilliseconds: (index + 1) * 1_000 + 250,
                text: "gap cue \(index)"
            )
        }
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let gapSnapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 7_900
    ))
    #expect(gapSnapshot.selectedOrdinal == 6)
    #expect(gapSnapshot.selectedCue?.text == "gap cue 6")
    let beforeFirstSnapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 500
    ))
    #expect(beforeFirstSnapshot.selectedOrdinal == 0)
    #expect(beforeFirstSnapshot.selectedCue?.text == "gap cue 0")
}

@Test
func subtitleFocusDatabaseBatchUsesCueLineDisplayOrder() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Focus.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Focus.mkv")
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            SubtitleCueGroup(
                sequenceNumber: nil,
                startTimecode: "0:00:01.00",
                endTimecode: "0:00:03.00",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                searchContent: "search projection",
                cueLines: [
                    focusLine(
                        eventIndex: 9,
                        content: "\tsecond",
                        displayOrder: 1,
                        startMilliseconds: 1_250,
                        endMilliseconds: 2_750
                    ),
                    focusLine(eventIndex: 2, content: "  first  ", displayOrder: 0),
                ]
            )
        ]
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let batch = try PlaybackSubtitleDatabase(path: database.path).subtitleFocusCueBatch(
        forSubtitleFileID: subtitleFileID,
        totalCount: 2,
        startingAtOrdinal: 0,
        limit: 10
    )
    #expect(batch.totalCount == 2)
    #expect(batch.cues.map(\.ordinal) == [0, 1])
    #expect(batch.cues.map(\.text) == ["  first  ", "\tsecond"])
    #expect(batch.cues.map(\.eventIndex) == [2, 9])
    #expect(batch.cues.map(\.displayOrder) == [0, 1])
    #expect(batch.cues.map(\.startMilliseconds) == [1_000, 1_250])
    #expect(batch.cues.map(\.endMilliseconds) == [2_000, 2_750])
    #expect(Set(batch.cues.map(\.cueGroupID)).count == 1)
    #expect(batch.cues[0].id != batch.cues[1].id)

    let snapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 1_500
    ))
    #expect(snapshot.totalCount == 2)
    #expect(snapshot.selectedOrdinal == 1)
    #expect(snapshot.selectedCue?.id == batch.cues[1].id)
    #expect(snapshot.selectedCue?.text == "\tsecond")
}

@Test
func subtitleFocusDatabaseBatchReadsCompleteCurrentVideoCollection() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Complete-Focus.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Complete-Focus.mkv")
    let cueCount = 2_500
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: focusEntries(count: cueCount)
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let batch = try PlaybackSubtitleDatabase(path: database.path).subtitleFocusCueBatch(
        forSubtitleFileID: subtitleFileID,
        totalCount: cueCount,
        startingAtOrdinal: 0,
        limit: cueCount
    )

    #expect(batch.totalCount == cueCount)
    #expect(batch.cues.count == cueCount)
    #expect(batch.cues.map(\.ordinal) == Array(0..<cueCount))
    #expect(batch.cues.first?.text == "cue 0")
    #expect(batch.cues.last?.text == "cue 2499")
}

@Test
func subtitleFocusDatabaseBatchRejectsPreCancelledTasks() async throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let task = Task.detached { () throws -> SubtitleFocusCueBatch in
        let database = try IndexingDatabase(path: databaseURL)
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return try PlaybackSubtitleDatabase(path: database.path).subtitleFocusCueBatch(
            forSubtitleFileID: 1,
            totalCount: 1,
            startingAtOrdinal: 0,
            limit: 1
        )
    }

    do {
        _ = try await task.value
        Issue.record("Expected cancelled Subtitle Focus batch to stop")
    } catch is CancellationError {
        // Expected.
    }
}

@Test
func subtitleFocusDatabaseBatchStopsAfterCancellationDuringRowIteration() async throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let subtitleFile = URL(fileURLWithPath: "/Media/Cancellation-Iteration.srt")
    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/Cancellation-Iteration.mkv"),
        entries: focusEntries(count: 2_500)
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let rowReadProbe = SubtitleFocusCancellationRowReadProbe()
    let task = Task.detached { () throws -> SubtitleFocusCueBatch in
        let database = try IndexingDatabase(path: databaseURL)
        return try PlaybackSubtitleDatabase(path: database.path).subtitleFocusCueBatch(
            forSubtitleFileID: subtitleFileID,
            totalCount: 2_500,
            startingAtOrdinal: 0,
            limit: 2_500,
            didReadCue: { readCount in
                rowReadProbe.record(readCount)
                guard readCount == 32 else {
                    return
                }
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
            }
        )
    }

    do {
        _ = try await task.value
        Issue.record("Expected Subtitle Focus batch to stop during row iteration")
    } catch is CancellationError {
        // Expected.
    }
    #expect(rowReadProbe.maximumReadCount == 32)
}

@Test
func subtitleFocusDatabaseUsesOneStableOrderForSelectionAndWindow() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Focus-Ordering.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Focus-Ordering.mkv")
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            focusGroup(start: 1_000, end: 3_000, content: "long"),
            focusGroup(start: 1_000, end: 2_000, content: "short"),
            focusGroup(start: 1_000, end: 2_000, content: "short peer"),
            focusGroup(start: 3_000, end: 4_000, content: "later"),
        ]
    )
    let subtitleFileID = try subtitleFocusFileID(
        for: subtitleFile,
        databaseURL: databaseURL
    )

    let snapshot = try #require(try PlaybackSubtitleDatabase(path: database.path).subtitleFocusInitialSnapshot(
        forSubtitleFileID: subtitleFileID,
        atMilliseconds: 1_500
    ))
    #expect(snapshot.selectedOrdinal == 0)
    #expect(snapshot.selectedCue?.text == "short")
    #expect(snapshot.cues.map(\.text) == ["short", "short peer", "long", "later"])
}

private func focusBatch(_ ordinals: Range<Int>, totalCount: Int) -> SubtitleFocusCueBatch {
    SubtitleFocusCueBatch(
        totalCount: totalCount,
        cues: ordinals.map { ordinal in
            SubtitleFocusCue(
                id: Int64(ordinal + 1),
                cueGroupID: Int64(ordinal + 10_001),
                ordinal: ordinal,
                eventIndex: ordinal,
                displayOrder: 0,
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 900,
                content: "cue \(ordinal)"
            )
        }
    )
}

private func subtitleFocusTemporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSubtitleFocusTests-\(UUID().uuidString).sqlite")
}

private func subtitleFocusFileID(
    for subtitleFile: URL,
    databaseURL: URL
) throws -> Int64 {
    let video = try #require(
        try LibraryDatabase(path: databaseURL)
            .libraryVideos(under: [subtitleFile.deletingLastPathComponent()])
            .first { $0.subtitlePath == subtitleFile.path }
    )
    return try #require(video.subtitleFileID)
}

private final class SubtitleFocusCancellationRowReadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var storedMaximumReadCount = 0

    var maximumReadCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedMaximumReadCount
    }

    func record(_ readCount: Int) {
        lock.lock()
        storedMaximumReadCount = max(storedMaximumReadCount, readCount)
        lock.unlock()
    }
}

private func focusEntries(count: Int) -> [SubtitleEntry] {
    (0..<count).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index),
            endTimecode: String(format: "00:00:%02d,900", index),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 900,
            text: "cue \(index)"
        )
    }
}

private func focusGroup(
    start: Int,
    end: Int,
    content: String
) -> SubtitleCueGroup {
    SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:02.00",
        startMilliseconds: start,
        endMilliseconds: end,
        searchContent: content,
        cueLines: [focusLine(eventIndex: start + end, content: content, displayOrder: 0)]
    )
}

private func focusLine(
    eventIndex: Int,
    content: String,
    displayOrder: Int,
    startMilliseconds: Int = 1_000,
    endMilliseconds: Int = 2_000
) -> SubtitleCueLine {
    SubtitleCueLine(
        eventIndex: eventIndex,
        sourceFormat: .ass,
        sourceStyle: "Default",
        sourceLayer: 0,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:02.00",
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        content: content,
        displayX: nil,
        displayY: nil,
        displayOrder: displayOrder
    )
}
