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
func subtitleFocusPrefetchUsesTwoCueThresholdAndTenCueBatches() {
    let policy = SubtitleFocusWindowPolicy.standard

    #expect(!policy.shouldPrefetch(
        selectedOrdinal: 6,
        loadedRange: 0..<10,
        direction: .forward
    ))
    #expect(policy.shouldPrefetch(
        selectedOrdinal: 7,
        loadedRange: 0..<10,
        direction: .forward
    ))
    #expect(policy.prefetchRange(
        totalCount: 35,
        loadedRange: 0..<10,
        direction: .forward
    ) == 10..<20)
    #expect(policy.prefetchRange(
        totalCount: 35,
        loadedRange: 10..<20,
        direction: .backward
    ) == 0..<10)
    #expect(policy.shouldPrefetch(
        selectedOrdinal: 12,
        loadedRange: 10..<20,
        direction: .backward
    ))
    #expect(!policy.shouldPrefetch(
        selectedOrdinal: 13,
        loadedRange: 10..<20,
        direction: .backward
    ))
    #expect(policy.prefetchRange(
        totalCount: 35,
        loadedRange: 0..<10,
        direction: .backward
    ) == nil)
    #expect(policy.prefetchRange(
        totalCount: 35,
        loadedRange: 30..<35,
        direction: .forward
    ) == nil)
}

@Test
func subtitleFocusCacheRetainsThirtyAndEvictsOppositeBatch() {
    var cache = SubtitleFocusCueCache()

    cache.replace(with: focusBatch(0..<10, totalCount: 40))
    #expect(cache.count == 10)

    #expect(cache.merge(focusBatch(10..<20, totalCount: 40), direction: .forward).isEmpty)
    #expect(cache.merge(focusBatch(20..<30, totalCount: 40), direction: .forward).isEmpty)
    #expect(cache.count == 30)

    let forwardEviction = cache.merge(
        focusBatch(30..<40, totalCount: 40),
        direction: .forward
    )
    #expect(forwardEviction == Array(0..<10))
    #expect(cache.cues.map(\.ordinal) == Array(10..<40))

    let backwardEviction = cache.merge(
        focusBatch(0..<10, totalCount: 40),
        direction: .backward
    )
    #expect(backwardEviction == Array((30..<40).reversed()))
    #expect(cache.cues.map(\.ordinal) == Array(0..<30))

    cache.replace(with: focusBatch(15..<25, totalCount: 40))
    #expect(cache.cues.map(\.ordinal) == Array(15..<25))

    cache.removeAll()
    #expect(cache.count == 0)
    #expect(cache.ordinalRange == nil)
}

@Test
func subtitleFocusRequestGateAcceptsOnlyLatestActiveSessionRequest() throws {
    let source = SubtitleFocusSourceIdentity(
        videoPath: "/Media/Episode.mkv",
        subtitlePath: "/Media/Episode.ass",
        subtitleFormat: .ass
    )
    var gate = SubtitleFocusRequestGate(source: source, sessionGeneration: 7)
    let issuedFirst = gate.issueRequest(targetOrdinal: 10)
    let first = try #require(issuedFirst)
    let issuedSecond = gate.issueRequest(targetOrdinal: 20)
    let second = try #require(issuedSecond)

    #expect(!gate.accepts(first))
    #expect(gate.accepts(second))

    gate.invalidate()
    #expect(!gate.accepts(second))

    var reopened = SubtitleFocusRequestGate(source: source, sessionGeneration: 8)
    let issuedReopenedRequest = reopened.issueRequest(targetOrdinal: 20)
    let reopenedRequest = try #require(issuedReopenedRequest)
    #expect(reopened.accepts(reopenedRequest))
    #expect(!reopened.accepts(second))

    let otherSource = SubtitleFocusSourceIdentity(
        videoPath: "/Media/Other.mkv",
        subtitlePath: "/Media/Other.ass",
        subtitleFormat: .ass
    )
    var otherGate = SubtitleFocusRequestGate(source: otherSource, sessionGeneration: 8)
    let issuedOtherRequest = otherGate.issueRequest(targetOrdinal: 20)
    let otherRequest = try #require(issuedOtherRequest)
    #expect(!otherGate.accepts(reopenedRequest))
    #expect(!reopened.accepts(otherRequest))
}

@Test
func subtitleFocusDatabaseBootstrapLoadsSixBeforeAndThreeAfter() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
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

    let snapshot = try #require(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 12_500
    ))
    #expect(snapshot.totalCount == 20)
    #expect(snapshot.selectedOrdinal == 12)
    #expect(snapshot.cues.map(\.ordinal) == Array(6..<16))
    #expect(snapshot.cues[6].text == "cue 12")
    #expect(snapshot.selectedCue == snapshot.cues[6])
}

@Test
func subtitleFocusDatabaseBootstrapFillsInitialWindowAtDocumentBoundaries() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    let subtitleFile = URL(fileURLWithPath: "/Media/Focus-Boundaries.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Focus-Boundaries.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: focusEntries(count: 20)
    )

    let firstSnapshot = try #require(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 100
    ))
    #expect(firstSnapshot.selectedOrdinal == 0)
    #expect(firstSnapshot.cues.map(\.ordinal) == Array(0..<10))

    let lastSnapshot = try #require(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 19_500
    ))
    #expect(lastSnapshot.selectedOrdinal == 19)
    #expect(lastSnapshot.cues.map(\.ordinal) == Array(10..<20))

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: focusEntries(count: 7)
    )
    let shortSnapshot = try #require(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 3_500
    ))
    #expect(shortSnapshot.totalCount == 7)
    #expect(shortSnapshot.cues.map(\.ordinal) == Array(0..<7))
}

@Test
func subtitleFocusDatabaseBootstrapUsesPreviousStartAndReturnsNilBeforeFirstCue() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
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

    let gapSnapshot = try #require(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 7_900
    ))
    #expect(gapSnapshot.selectedOrdinal == 6)
    #expect(gapSnapshot.selectedCue?.text == "gap cue 6")
    #expect(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 500
    ) == nil)
}

@Test
func subtitleFocusDatabaseBatchUsesCueLineDisplayOrder() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
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
                endTimecode: "0:00:02.00",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                searchContent: "search projection",
                cueLines: [
                    focusLine(eventIndex: 9, content: "\tsecond", displayOrder: 1),
                    focusLine(eventIndex: 2, content: "  first  ", displayOrder: 0),
                ]
            )
        ]
    )

    let batch = try database.subtitleFocusCueBatch(
        forSubtitleFile: subtitleFile,
        totalCount: 1,
        startingAtOrdinal: 0,
        limit: 10
    )
    #expect(batch.totalCount == 1)
    #expect(batch.cues.first?.lines == ["  first  ", "\tsecond"])
    #expect(batch.cues.first?.text == "  first  \n\tsecond")
}

@Test
func subtitleFocusDatabaseUsesOneStableOrderForSelectionAndWindow() throws {
    let databaseURL = subtitleFocusTemporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: databaseURL) }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
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

    let snapshot = try #require(try database.subtitleFocusInitialSnapshot(
        forSubtitleFile: subtitleFile,
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
                ordinal: ordinal,
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 900,
                lines: ["cue \(ordinal)"]
            )
        }
    )
}

private func subtitleFocusTemporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSubtitleFocusTests-\(UUID().uuidString).sqlite")
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
    displayOrder: Int
) -> SubtitleCueLine {
    SubtitleCueLine(
        eventIndex: eventIndex,
        sourceFormat: .ass,
        sourceStyle: "Default",
        sourceLayer: 0,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:02.00",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        displayX: nil,
        displayY: nil,
        displayOrder: displayOrder
    )
}
