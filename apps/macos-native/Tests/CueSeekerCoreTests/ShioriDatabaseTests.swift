import Foundation
import Testing
@testable import CueSeekerCore

@Test
func shioriListsSupportMetadataValidationSortingAndDeletion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try ShioriDatabase(path: databaseURL)
    let initial = try #require(try database.shioriLists().first)
    #expect(initial.id == ShioriListIdentity.defaultListID)
    #expect(initial.name == "Default")
    #expect(initial.description.isEmpty)
    #expect(initial.coverPath == nil)

    let simultaneousErrors = try database.validateShioriList(
        name: String(repeating: "N", count: 31),
        description: String(repeating: "D", count: 101)
    )
    #expect(simultaneousErrors.nameError == .nameTooLong(
        maximumCharacters: 30,
        currentCharacters: 31
    ))
    #expect(simultaneousErrors.descriptionError == .descriptionTooLong(
        maximumCharacters: 100,
        currentCharacters: 101
    ))

    let older = try database.createShioriList(
        name: "  Favorites  ",
        description: "First line\nSecond line",
        coverPath: "/tmp/favorites.jpg",
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let newer = try database.createShioriList(
        name: "Study",
        createdAt: Date(timeIntervalSince1970: 200)
    )
    #expect(older.name == "Favorites")
    #expect(older.description == "First line\nSecond line")
    #expect(older.coverPath == "/tmp/favorites.jpg")
    #expect(try database.shioriLists().map(\.id) == [initial.id, older.id, newer.id])

    let duplicate = try database.validateShioriList(
        name: "favorites",
        description: ""
    )
    #expect(duplicate.nameError == .duplicateName)
    #expect(throws: ShioriListValidationError.duplicateName) {
        _ = try database.createShioriList(name: "FAVORITES")
    }

    let updated = try database.updateShioriList(
        id: older.id,
        name: "Favorites Updated",
        description: "",
        coverPath: nil
    )
    #expect(updated.name == "Favorites Updated")
    #expect(updated.description.isEmpty)
    #expect(updated.coverPath == nil)
    #expect(updated.createdAt == older.createdAt)

    #expect(try database.deleteShioriList(id: newer.id) == newer)
    #expect(try database.deleteShioriList(id: older.id).id == older.id)
    #expect(throws: ShioriListMutationError.cannotDeleteOnlyList) {
        _ = try database.deleteShioriList(id: initial.id)
    }
}

@Test
func shioriListOverviewCountsPerListAndDeduplicatesCueIDs() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let shioriDatabase = try ShioriDatabase(path: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/List Overview.srt")
    try indexingDatabase.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/Show/List Overview.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Shared CueID"
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: databaseURL).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    _ = try shioriDatabase.upsertShiori(selection: selection)
    let secondList = try shioriDatabase.createShioriList(name: "Second")
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO excerpts(list_id, cue_id, created_at)
        VALUES (\(secondList.id), \(cueID), '2026-07-24T00:00:00Z');
        """
    )

    let overview = try shioriDatabase.shioriListOverview()
    #expect(overview.lists.map(\.cueCount) == [1, 1])
    #expect(overview.uniqueCueCount == 1)
}

@Test
func recentShioriPlaybackResumesAnchorAndFallsBackWithinOriginalList() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try ShioriDatabase(path: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Recent Shiori.srt")
    try indexingDatabase.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/Show/Recent Shiori.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Older cue"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Newer cue"
            ),
        ]
    )
    let playbackDatabase = try PlaybackSubtitleDatabase(path: databaseURL)
    let olderSelection = try #require(try playbackDatabase.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let newerSelection = try #require(try playbackDatabase.cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 3_500
    ))
    let older = try database.upsertShiori(
        selection: olderSelection,
        listID: ShioriListIdentity.defaultListID,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let newer = try database.upsertShiori(
        selection: newerSelection,
        listID: ShioriListIdentity.defaultListID,
        createdAt: Date(timeIntervalSince1970: 200)
    )

    try database.recordRecentShioriPlayback(
        shioriID: older.id,
        playedAt: Date(timeIntervalSince1970: 300)
    )

    var summary = try #require(try database.recentShioriListSummaries().first)
    #expect(summary.list.id == ShioriListIdentity.defaultListID)
    #expect(summary.list.recentSortOrder == "created_at_desc")
    #expect(summary.cueCount == 2)
    #expect(summary.resumeShiori?.id == older.id)
    #expect(summary.resumePosition == 1)

    _ = try database.removeShiori(id: older.id)
    summary = try #require(try database.recentShioriListSummaries().first)
    #expect(summary.cueCount == 1)
    #expect(summary.resumeShiori?.id == newer.id)
    #expect(summary.resumePosition == 1)

    _ = try database.removeShiori(id: newer.id)
    #expect(try database.recentShioriListSummaries().isEmpty)
    let list = try #require(try database.shioriList(id: ShioriListIdentity.defaultListID))
    #expect(list.recentCueID == nil)
    #expect(list.recentSortOrder == nil)
    #expect(list.recentPlayedAt == nil)
}

@Test
func shioriSaveMoveAndDuplicateUseListScopeAndPreserveMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try ShioriDatabase(path: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/List Transfer.srt")
    try indexingDatabase.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/Show/List Transfer.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Duplicate this Cue."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Move this Cue."
            ),
        ]
    )
    let defaultList = try #require(try database.shioriList(
        id: ShioriListIdentity.defaultListID
    ))
    let destinationList = try database.createShioriList(
        name: "Destination",
        createdAt: Date(timeIntervalSince1970: 200)
    )
    let firstSelection = try #require(
        try PlaybackSubtitleDatabase(path: databaseURL).cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 1_500
        )
    )
    let secondSelection = try #require(
        try PlaybackSubtitleDatabase(path: databaseURL).cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 3_500
        )
    )
    let firstCueID = try #require(firstSelection.cueLineID)

    let transitionalSave = try database.upsertShiori(selection: firstSelection)
    #expect(try database.shioriRelation(id: transitionalSave.id)?.listID == defaultList.id)
    #expect(try database.shiori(cueID: firstCueID)?.id == transitionalSave.id)
    #expect(try database.shiori(
        cueID: firstCueID,
        listID: destinationList.id
    ) == nil)
    _ = try database.removeShiori(id: transitionalSave.id)

    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let sourceToDuplicate = try database.upsertShiori(
        selection: firstSelection,
        listID: defaultList.id,
        createdAt: createdAt
    )
    let duplicate = try database.duplicateShiori(
        id: sourceToDuplicate.id,
        toListID: destinationList.id
    )
    #expect(duplicate.id != sourceToDuplicate.id)
    #expect(duplicate.listID == destinationList.id)
    #expect(duplicate.createdAt == sourceToDuplicate.createdAt)
    #expect(try database.shioriRelation(id: sourceToDuplicate.id) != nil)
    #expect(throws: ShioriTransferError.destinationAlreadyContainsCue(
        listID: destinationList.id
    )) {
        _ = try database.duplicateShiori(
            id: sourceToDuplicate.id,
            toListID: destinationList.id
        )
    }

    let sourceToMove = try database.upsertShiori(
        selection: secondSelection,
        listID: defaultList.id,
        createdAt: createdAt
    )
    #expect(throws: ShioriTransferError.destinationUnavailable) {
        _ = try database.moveShiori(id: sourceToMove.id, toListID: 99_999)
    }
    #expect(try database.shioriRelation(id: sourceToMove.id) != nil)

    let moved = try database.moveShiori(
        id: sourceToMove.id,
        toListID: destinationList.id
    )
    #expect(moved.id != sourceToMove.id)
    #expect(moved.createdAt == sourceToMove.createdAt)
    #expect(try database.shioriRelation(id: sourceToMove.id) == nil)
    #expect(try database.shioriRelations(listID: defaultList.id).map(\.id) == [
        sourceToDuplicate.id
    ])
    #expect(Set(try database.shioriRelations(listID: destinationList.id).map(\.id)) == Set([
        duplicate.id, moved.id
    ]))
}

@Test
func shioriPersistsCueIdentityAndCreatedAt() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Episode 1.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "First saved line.\nSecond saved line."
            )
        ]
    )

    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    let shiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: createdAt
    )
    let duplicate = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    #expect(shiori.id == duplicate.id)
    #expect(shiori.subtitlePath == subtitleFile.path)
    #expect(shiori.subtitleFormat == .srt)
    #expect(shiori.videoPath == videoFile.path)
    #expect(shiori.videoName == "Episode 1.mkv")
    #expect(shiori.startMilliseconds == 1_000)
    #expect(shiori.endMilliseconds == 3_000)
    #expect(shiori.cueLines == ["First saved line.", "Second saved line."])
    #expect(shiori.isValid)
    #expect(shiori.createdAt == ISO8601DateFormatter().string(from: createdAt))
    #expect(duplicate.createdAt == shiori.createdAt)
    #expect(try ShioriDatabase(path: database.path).shioris().count == 1)
}

@Test
func cueContentsResolveCurrentCueDataInRequestedOrder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Cue Contents.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Cue Contents.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "First canonical Cue."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Second canonical Cue."
            ),
        ]
    )
    let firstID = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    )?.cueLineID)
    let secondID = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 3_500
    )?.cueLineID)

    let contents = try CueContentDatabase(path: database.path).cueContents(
        forCueIDs: [secondID, firstID, secondID, -1]
    )
    #expect(contents.map(\.cueID) == [secondID, firstID])
    #expect(contents.map(\.content) == [
        "Second canonical Cue.",
        "First canonical Cue.",
    ])
    #expect(contents.allSatisfy { $0.videoPath == videoFile.path })
}

@Test
func shioriResidentSnapshotLoadsRelationsCurrentCueContentAndFacetsTogether() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Resident Shiori.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Resident Shiori.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Resident Cue"
            ),
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let saved = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: videoFile,
        duration: nil,
        state: .finished
    )

    let snapshot = try ShioriDatabase(path: database.path).shioriResidentSnapshot()

    #expect(snapshot.relations.map(\.id) == [saved.id])
    #expect(snapshot.relations.map(\.cueID) == snapshot.cueContents.map(\.cueID))
    #expect(snapshot.cueContents.map(\.content) == ["Resident Cue"])
    #expect(snapshot.facetSnapshot.cueIDs == [cueID])
    #expect(snapshot.facetSnapshot.distribution.totalCount == 1)
    #expect(snapshot.facetSnapshot.distribution.durationCounts[.oneToUnderThreeSeconds] == 1)
    #expect(snapshot.facetSnapshot.distribution.characterCounts[.elevenToTwenty] == 1)
    #expect(snapshot.facetSnapshot.distribution.watchStateCounts[.finished] == 1)
    #expect(snapshot.facetSnapshot.filteredCueIDs(
        using: CueFacetFilter(watchStates: [.finished]),
        limit: 1
    ).cueIDs == [cueID])
    #expect(snapshot.facetSnapshot.filteredCueIDs(
        using: CueFacetFilter(watchStates: [.unwatched]),
        limit: 1
    ).cueIDs.isEmpty)
}

@Test
func shioriResidentSnapshotKeepsAvailableCueContentBesideUnavailableCue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let availableFolder = URL(fileURLWithPath: "/Media/Available")
    let availableSubtitle = availableFolder.appendingPathComponent("Episode 1.srt")
    let availableVideo = availableFolder.appendingPathComponent("Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: availableSubtitle,
        videoFile: availableVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Available Cue"
            ),
        ]
    )

    let unavailableFolder = URL(fileURLWithPath: "/Media/Unavailable")
    let unavailableSubtitle = unavailableFolder.appendingPathComponent("Episode 2.srt")
    let unavailableVideo = unavailableFolder.appendingPathComponent("Episode 2.mkv")
    try database.replaceEntries(
        subtitleFile: unavailableSubtitle,
        videoFile: unavailableVideo,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Unavailable Cue"
            ),
        ]
    )

    let playbackDatabase = try PlaybackSubtitleDatabase(path: database.path)
    let availableSelection = try #require(
        try playbackDatabase.cueTextSelection(
            forSubtitleFile: availableSubtitle,
            atMilliseconds: 1_500
        )
    )
    let unavailableSelection = try #require(
        try playbackDatabase.cueTextSelection(
            forSubtitleFile: unavailableSubtitle,
            atMilliseconds: 3_500
        )
    )
    let availableCueID = try #require(availableSelection.cueLineID)
    let shioriDatabase = try ShioriDatabase(path: database.path)
    let availableShiori = try shioriDatabase.upsertShiori(
        selection: availableSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let unavailableShiori = try shioriDatabase.upsertShiori(
        selection: unavailableSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    try database.replaceEntries(
        subtitleFile: unavailableSubtitle,
        videoFile: unavailableVideo,
        entries: []
    )

    let snapshot = try shioriDatabase.shioriResidentSnapshot()
    let resolvedByID = Dictionary(
        uniqueKeysWithValues: snapshot.resolvedShioris.map { ($0.id, $0) }
    )
    let resolvedAvailable = try #require(resolvedByID[availableShiori.id])
    let resolvedUnavailable = try #require(resolvedByID[unavailableShiori.id])

    #expect(snapshot.relations.count == 2)
    #expect(snapshot.cueContents.map(\.cueID) == [availableCueID])
    #expect(snapshot.cueContents.map(\.content) == ["Available Cue"])
    #expect(resolvedAvailable.subtitleFileID != nil)
    #expect(resolvedAvailable.isValid)
    #expect(resolvedAvailable.displayTitle == "Episode 1.srt")
    #expect(!resolvedUnavailable.isValid)
    #expect(resolvedUnavailable.unavailableReason == .cueMissing)
    #expect(resolvedUnavailable.displayTitle == "Episode 2.srt")
    #expect(resolvedUnavailable.displayTitle != resolvedUnavailable.videoName)
}

@Test
func shioriRelationSchemaAllowsOneCueInDifferentListsOnly() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Relation Lists.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Relation Lists.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "One Cue, two relation lists."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:07,000",
                startMilliseconds: 3_000,
                endMilliseconds: 7_000,
                text: "Default list only."
            ),
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let defaultShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let defaultOnlySelection = try #require(
        try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 3_500
        )
    )
    let defaultOnlyCueID = try #require(defaultOnlySelection.cueLineID)
    let defaultOnlyShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: defaultOnlySelection,
        createdAt: Date(timeIntervalSince1970: 200)
    )

    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO excerpt_lists(
            id,
            name,
            normalized_name,
            description,
            cover_path,
            created_at
        )
        VALUES (
            2,
            'Future List',
            'future list',
            '',
            NULL,
            '2026-07-21T00:00:00Z'
        );
        INSERT INTO excerpts(list_id, cue_id, created_at)
        VALUES (2, \(cueID), '2026-07-21T00:00:01Z');
        """
    )

    #expect(
        try ShioriDatabase(path: database.path).shioriRelations(
            listID: ShioriListIdentity.defaultListID
        ).map(\.id) == [defaultShiori.id, defaultOnlyShiori.id]
    )
    let futureRelation = try #require(try ShioriDatabase(path: database.path).shioriRelations(listID: 2).first)
    #expect(futureRelation.cueID == cueID)
    #expect(futureRelation.listID == 2)

    let defaultSnapshot = try ShioriDatabase(path: database.path)
        .shioriResidentSnapshot(listID: ShioriListIdentity.defaultListID)
    let futureSnapshot = try ShioriDatabase(path: database.path)
        .shioriResidentSnapshot(listID: 2)
    #expect(defaultSnapshot.facetSnapshot.distribution.totalCount == 2)
    #expect(Set(defaultSnapshot.facetSnapshot.cueIDs) == [cueID, defaultOnlyCueID])
    #expect(futureSnapshot.facetSnapshot.distribution.totalCount == 1)
    #expect(futureSnapshot.facetSnapshot.cueIDs == [cueID])

    do {
        try executeDatabaseTestSQLite(
            at: databaseURL,
            """
            INSERT INTO excerpts(list_id, cue_id, created_at)
            VALUES (2, \(cueID), '2026-07-21T00:00:02Z');
            """
        )
        Issue.record("Expected one Shiori relation per Cue inside one list")
    } catch {
        // Expected unique(list_id, cue_id) enforcement.
    }
}

@Test
func shioriPersistsAndResolvesCueID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Permanent Identity.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Permanent Identity.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "CueID is the Shiori relationship."
            )
        ]
    )

    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let shiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection
    )

    let relation = try #require(try ShioriDatabase(path: database.path).shioriRelation(id: shiori.id))
    #expect(relation.cueID == cueID)
    #expect(relation.listID == ShioriListIdentity.defaultListID)
    #expect(try ShioriDatabase(path: database.path).shioriLists().map(\.id) == [ShioriListIdentity.defaultListID])

    let cueContent = try CueContentDatabase(path: database.path).cueContents(forCueIDs: [cueID])
    #expect(cueContent.first?.cueID == cueID)

}

@Test
func rebuildingSubtitlePreservesCueIDAndShioriWhenContentChanges() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Reindexed Shiori.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Reindexed Shiori.mkv")
    let originalEntry = SubtitleEntry(
        sequenceNumber: 1,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:03,000",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        text: "Original saved cue."
    )
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [originalEntry]
    )

    let originalCue = try #require(
        try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile).first
    )
    let originalShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: shioriSelection(originalCue),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Updated saved cue."
            ),
        ]
    )

    let rebuiltCue = try #require(
        try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile).first
    )
    let rebuiltRelation = try #require(
        try ShioriDatabase(path: database.path).shioriRelation(id: originalShiori.id)
    )
    let rebuiltShiori = try #require(try ShioriDatabase(path: database.path).shiori(id: originalShiori.id))

    #expect(rebuiltCue.id == originalCue.id)
    #expect(rebuiltRelation.id == originalShiori.id)
    #expect(rebuiltRelation.cueID == rebuiltCue.id)
    #expect(rebuiltShiori.content == "Updated saved cue.")
    #expect(
        rebuiltShiori.contentChange == ShioriCueContentChange(
            previousContent: "Original saved cue.",
            currentContent: "Updated saved cue."
        )
    )
    #expect(rebuiltShiori.createdAt == originalShiori.createdAt)
}

@Test
func shioriStoresSameTimeSiblingCuesSeparatelyAndDeduplicatesOneIdentity() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Same Time.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Same Time.mkv")
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
                searchContent: "Chinese upper cue\nJapanese lower cue",
                cueLines: [
                    testCueLine(
                        eventIndex: 10,
                        startMilliseconds: 1_000,
                        endMilliseconds: 3_000,
                        content: "Chinese upper cue",
                        displayOrder: 0
                    ),
                    testCueLine(
                        eventIndex: 11,
                        startMilliseconds: 1_000,
                        endMilliseconds: 3_000,
                        content: "Japanese lower cue",
                        displayOrder: 1
                    ),
                ]
            )
        ]
    )
    let cueRecords = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let topSelection = shioriSelection(cueRecords[0])
    let bottomSelection = shioriSelection(cueRecords[1])

    let top = try ShioriDatabase(path: database.path).upsertShiori(
        selection: topSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let bottom = try ShioriDatabase(path: database.path).upsertShiori(
        selection: bottomSelection,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let duplicateBottom = try ShioriDatabase(path: database.path).upsertShiori(
        selection: bottomSelection,
        createdAt: Date(timeIntervalSince1970: 1_900_000_000)
    )

    #expect(top.id != bottom.id)
    #expect(bottom.id == duplicateBottom.id)
    #expect(top.cueIdentity == topSelection.cueIdentity)
    #expect(bottom.cueIdentity == bottomSelection.cueIdentity)
    #expect(duplicateBottom.createdAt == bottom.createdAt)
    #expect(try ShioriDatabase(path: database.path).shioriCount() == 2)
    #expect(try ShioriDatabase(path: database.path).removeShiori(id: bottom.id))
    #expect(try ShioriDatabase(path: database.path).shiori(id: top.id) != nil)
    #expect(try ShioriDatabase(path: database.path).shiori(id: bottom.id) == nil)
}

@Test
func removingIndexedFolderPreservesCueBoundShioriRelation() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let folder = URL(fileURLWithPath: "/Media/Show")
    let subtitleFile = folder.appendingPathComponent("Episode 1.srt")
    let videoFile = folder.appendingPathComponent("Episode 1.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:03,000",
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                text: "Shiori should survive index removal."
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let savedShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection
    )

    try database.removeIndexedFolder(folder)

    #expect(try SearchDatabase(path: database.path).search("Shiori").isEmpty)
    let unavailableShiori = try #require(
        try ShioriDatabase(path: database.path).shioris().first
    )
    #expect(unavailableShiori.id == savedShiori.id)
    #expect(!unavailableShiori.isValid)
    #expect(unavailableShiori.unavailableReason == .libraryUnavailable)
    #expect(unavailableShiori.content == "Shiori should survive index removal.")
    #expect(unavailableShiori.cueGroupContent == "Shiori should survive index removal.")
    #expect(
        try ShioriDatabase(path: database.path).shioriRelations()
            .map(\.id) == [savedShiori.id]
    )
}

@Test
func shioriSavesByCueIDIntoEachListWithoutDuplicatingWithinOne() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let shioriDatabase = try ShioriDatabase(path: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Save By CueID.srt")
    try indexingDatabase.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/Show/Save By CueID.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "Saved from the Search table"
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: databaseURL).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let defaultListID = try #require(try shioriDatabase.firstShioriListID())
    let secondList = try shioriDatabase.createShioriList(name: "Second")

    // The Search table has only the Cue, so the save goes in by CueID.
    let saved = try shioriDatabase.upsertShiori(
        cueID: cueID,
        listID: defaultListID
    )
    #expect(try shioriDatabase.shiori(cueID: cueID, listID: defaultListID)?.id == saved.id)

    // The same Cue still reaches another list.
    _ = try shioriDatabase.upsertShiori(cueID: cueID, listID: secondList.id)
    #expect(try shioriDatabase.shioriCount(listID: secondList.id) == 1)

    // Saving again into a list that already holds the Cue adds nothing.
    let repeated = try shioriDatabase.upsertShiori(
        cueID: cueID,
        listID: defaultListID
    )
    #expect(repeated.id == saved.id)
    #expect(try shioriDatabase.shioriCount(listID: defaultListID) == 1)
    #expect(try shioriDatabase.uniqueShioriCueCount() == 1)
}
