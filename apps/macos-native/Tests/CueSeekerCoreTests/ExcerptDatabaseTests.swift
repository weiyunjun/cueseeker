import Foundation
import Testing
@testable import CueSeekerCore

@Test
func excerptListsSupportMetadataValidationSortingAndDeletion() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try ExcerptDatabase(path: databaseURL)
    let initial = try #require(try database.excerptLists().first)
    #expect(initial.id == ExcerptListIdentity.defaultListID)
    #expect(initial.name == "Default")
    #expect(initial.description.isEmpty)
    #expect(initial.coverPath == nil)

    let simultaneousErrors = try database.validateExcerptList(
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

    let older = try database.createExcerptList(
        name: "  Favorites  ",
        description: "First line\nSecond line",
        coverPath: "/tmp/favorites.jpg",
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let newer = try database.createExcerptList(
        name: "Study",
        createdAt: Date(timeIntervalSince1970: 200)
    )
    #expect(older.name == "Favorites")
    #expect(older.description == "First line\nSecond line")
    #expect(older.coverPath == "/tmp/favorites.jpg")
    #expect(try database.excerptLists().map(\.id) == [initial.id, older.id, newer.id])

    let duplicate = try database.validateExcerptList(
        name: "favorites",
        description: ""
    )
    #expect(duplicate.nameError == .duplicateName)
    #expect(throws: ExcerptListValidationError.duplicateName) {
        _ = try database.createExcerptList(name: "FAVORITES")
    }

    let updated = try database.updateExcerptList(
        id: older.id,
        name: "Favorites Updated",
        description: "",
        coverPath: nil
    )
    #expect(updated.name == "Favorites Updated")
    #expect(updated.description.isEmpty)
    #expect(updated.coverPath == nil)
    #expect(updated.createdAt == older.createdAt)

    #expect(try database.deleteExcerptList(id: newer.id) == newer)
    #expect(try database.deleteExcerptList(id: older.id).id == older.id)
    #expect(throws: ExcerptListMutationError.cannotDeleteOnlyList) {
        _ = try database.deleteExcerptList(id: initial.id)
    }
}

@Test
func excerptListOverviewCountsPerListAndDeduplicatesCueIDs() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let excerptDatabase = try ExcerptDatabase(path: databaseURL)
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
    _ = try excerptDatabase.upsertExcerpt(selection: selection)
    let secondList = try excerptDatabase.createExcerptList(name: "Second")
    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO excerpts(list_id, cue_id, created_at)
        VALUES (\(secondList.id), \(cueID), '2026-07-24T00:00:00Z');
        """
    )

    let overview = try excerptDatabase.excerptListOverview()
    #expect(overview.lists.map(\.cueCount) == [1, 1])
    #expect(overview.uniqueCueCount == 1)
}

@Test
func recentExcerptPlaybackResumesAnchorAndFallsBackWithinOriginalList() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try ExcerptDatabase(path: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Recent Excerpt.srt")
    try indexingDatabase.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: URL(fileURLWithPath: "/Media/Show/Recent Excerpt.mkv"),
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
    let older = try database.upsertExcerpt(
        selection: olderSelection,
        listID: ExcerptListIdentity.defaultListID,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    let newer = try database.upsertExcerpt(
        selection: newerSelection,
        listID: ExcerptListIdentity.defaultListID,
        createdAt: Date(timeIntervalSince1970: 200)
    )

    try database.recordRecentExcerptPlayback(
        excerptID: older.id,
        playedAt: Date(timeIntervalSince1970: 300)
    )

    var summary = try #require(try database.recentExcerptListSummaries().first)
    #expect(summary.list.id == ExcerptListIdentity.defaultListID)
    #expect(summary.list.recentSortOrder == "created_at_desc")
    #expect(summary.cueCount == 2)
    #expect(summary.resumeExcerpt?.id == older.id)
    #expect(summary.resumePosition == 1)

    _ = try database.removeExcerpt(id: older.id)
    summary = try #require(try database.recentExcerptListSummaries().first)
    #expect(summary.cueCount == 1)
    #expect(summary.resumeExcerpt?.id == newer.id)
    #expect(summary.resumePosition == 1)

    _ = try database.removeExcerpt(id: newer.id)
    #expect(try database.recentExcerptListSummaries().isEmpty)
    let list = try #require(try database.excerptList(id: ExcerptListIdentity.defaultListID))
    #expect(list.recentCueID == nil)
    #expect(list.recentSortOrder == nil)
    #expect(list.recentPlayedAt == nil)
}

@Test
func excerptSaveMoveAndDuplicateUseListScopeAndPreserveMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try ExcerptDatabase(path: databaseURL)
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
    let defaultList = try #require(try database.excerptList(
        id: ExcerptListIdentity.defaultListID
    ))
    let destinationList = try database.createExcerptList(
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

    let transitionalSave = try database.upsertExcerpt(selection: firstSelection)
    #expect(try database.excerptRelation(id: transitionalSave.id)?.listID == defaultList.id)
    #expect(try database.excerpt(cueID: firstCueID)?.id == transitionalSave.id)
    #expect(try database.excerpt(
        cueID: firstCueID,
        listID: destinationList.id
    ) == nil)
    _ = try database.removeExcerpt(id: transitionalSave.id)

    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let sourceToDuplicate = try database.upsertExcerpt(
        selection: firstSelection,
        listID: defaultList.id,
        createdAt: createdAt
    )
    let duplicate = try database.duplicateExcerpt(
        id: sourceToDuplicate.id,
        toListID: destinationList.id
    )
    #expect(duplicate.id != sourceToDuplicate.id)
    #expect(duplicate.listID == destinationList.id)
    #expect(duplicate.createdAt == sourceToDuplicate.createdAt)
    #expect(try database.excerptRelation(id: sourceToDuplicate.id) != nil)
    #expect(throws: ExcerptTransferError.destinationAlreadyContainsCue(
        listID: destinationList.id
    )) {
        _ = try database.duplicateExcerpt(
            id: sourceToDuplicate.id,
            toListID: destinationList.id
        )
    }

    let sourceToMove = try database.upsertExcerpt(
        selection: secondSelection,
        listID: defaultList.id,
        createdAt: createdAt
    )
    #expect(throws: ExcerptTransferError.destinationUnavailable) {
        _ = try database.moveExcerpt(id: sourceToMove.id, toListID: 99_999)
    }
    #expect(try database.excerptRelation(id: sourceToMove.id) != nil)

    let moved = try database.moveExcerpt(
        id: sourceToMove.id,
        toListID: destinationList.id
    )
    #expect(moved.id != sourceToMove.id)
    #expect(moved.createdAt == sourceToMove.createdAt)
    #expect(try database.excerptRelation(id: sourceToMove.id) == nil)
    #expect(try database.excerptRelations(listID: defaultList.id).map(\.id) == [
        sourceToDuplicate.id
    ])
    #expect(Set(try database.excerptRelations(listID: destinationList.id).map(\.id)) == Set([
        duplicate.id, moved.id
    ]))
}

@Test
func excerptPersistsCueIdentityAndCreatedAt() throws {
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

    let excerpt = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection,
        createdAt: createdAt
    )
    let duplicate = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    #expect(excerpt.id == duplicate.id)
    #expect(excerpt.subtitlePath == subtitleFile.path)
    #expect(excerpt.subtitleFormat == .srt)
    #expect(excerpt.videoPath == videoFile.path)
    #expect(excerpt.videoName == "Episode 1.mkv")
    #expect(excerpt.startMilliseconds == 1_000)
    #expect(excerpt.endMilliseconds == 3_000)
    #expect(excerpt.cueLines == ["First saved line.", "Second saved line."])
    #expect(excerpt.isValid)
    #expect(excerpt.createdAt == ISO8601DateFormatter().string(from: createdAt))
    #expect(duplicate.createdAt == excerpt.createdAt)
    #expect(try ExcerptDatabase(path: database.path).excerpts().count == 1)
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
func excerptResidentSnapshotLoadsRelationsCurrentCueContentAndFacetsTogether() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Resident Excerpt.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Resident Excerpt.mkv")
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
    let saved = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: videoFile,
        duration: nil,
        state: .finished
    )

    let snapshot = try ExcerptDatabase(path: database.path).excerptResidentSnapshot()

    #expect(snapshot.relations.map(\.id) == [saved.id])
    #expect(snapshot.relations.map(\.cueID) == snapshot.cueContents.map(\.cueID))
    #expect(snapshot.cueContents.map(\.content) == ["Resident Cue"])
    #expect(snapshot.facetSnapshot.cueIDs == [cueID])
    #expect(snapshot.facetSnapshot.distribution.totalCount == 1)
    #expect(snapshot.facetSnapshot.distribution.durationCounts[.oneToUnderThreeSeconds] == 1)
    #expect(snapshot.facetSnapshot.distribution.characterCounts[.elevenToTwenty] == 1)
    #expect(snapshot.facetSnapshot.distribution.watchStateCounts[.finished] == 1)
    #expect(snapshot.facetSnapshot.distribution.folderCounts == ["/Media/Show": 1])
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
func excerptResidentSnapshotKeepsAvailableCueContentBesideUnavailableCue() throws {
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
    // Display Title is the video's, so the Library rows name both excerpts.
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

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
    let excerptDatabase = try ExcerptDatabase(path: database.path)
    let availableExcerpt = try excerptDatabase.upsertExcerpt(
        selection: availableSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let unavailableExcerpt = try excerptDatabase.upsertExcerpt(
        selection: unavailableSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    try database.replaceEntries(
        subtitleFile: unavailableSubtitle,
        videoFile: unavailableVideo,
        entries: []
    )
    try LibraryDatabase(path: database.path).refreshPresentationAfterIndexedContentChange()

    let snapshot = try excerptDatabase.excerptResidentSnapshot()
    let resolvedByID = Dictionary(
        uniqueKeysWithValues: snapshot.resolvedExcerpts.map { ($0.id, $0) }
    )
    let resolvedAvailable = try #require(resolvedByID[availableExcerpt.id])
    let resolvedUnavailable = try #require(resolvedByID[unavailableExcerpt.id])

    #expect(snapshot.relations.count == 2)
    #expect(snapshot.cueContents.map(\.cueID) == [availableCueID])
    #expect(snapshot.cueContents.map(\.content) == ["Available Cue"])
    #expect(resolvedAvailable.subtitleFileID != nil)
    #expect(resolvedAvailable.isValid)
    #expect(resolvedAvailable.displayTitle == "Available - 01")
    #expect(!resolvedUnavailable.isValid)
    #expect(resolvedUnavailable.unavailableReason == .cueMissing)
    #expect(resolvedUnavailable.displayTitle == "Unavailable - 01")
    #expect(resolvedUnavailable.displayTitle != resolvedUnavailable.videoName)
}

@Test
func excerptRelationSchemaAllowsOneCueInDifferentListsOnly() throws {
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
    let defaultExcerpt = try ExcerptDatabase(path: database.path).upsertExcerpt(
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
    let defaultOnlyExcerpt = try ExcerptDatabase(path: database.path).upsertExcerpt(
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
        try ExcerptDatabase(path: database.path).excerptRelations(
            listID: ExcerptListIdentity.defaultListID
        ).map(\.id) == [defaultExcerpt.id, defaultOnlyExcerpt.id]
    )
    let futureRelation = try #require(try ExcerptDatabase(path: database.path).excerptRelations(listID: 2).first)
    #expect(futureRelation.cueID == cueID)
    #expect(futureRelation.listID == 2)

    let defaultSnapshot = try ExcerptDatabase(path: database.path)
        .excerptResidentSnapshot(listID: ExcerptListIdentity.defaultListID)
    let futureSnapshot = try ExcerptDatabase(path: database.path)
        .excerptResidentSnapshot(listID: 2)
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
        Issue.record("Expected one Excerpt relation per Cue inside one list")
    } catch {
        // Expected unique(list_id, cue_id) enforcement.
    }
}

@Test
func excerptPersistsAndResolvesCueID() throws {
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
                text: "CueID is the Excerpt relationship."
            )
        ]
    )

    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let excerpt = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection
    )

    let relation = try #require(try ExcerptDatabase(path: database.path).excerptRelation(id: excerpt.id))
    #expect(relation.cueID == cueID)
    #expect(relation.listID == ExcerptListIdentity.defaultListID)
    #expect(try ExcerptDatabase(path: database.path).excerptLists().map(\.id) == [ExcerptListIdentity.defaultListID])

    let cueContent = try CueContentDatabase(path: database.path).cueContents(forCueIDs: [cueID])
    #expect(cueContent.first?.cueID == cueID)

}

@Test
func rebuildingSubtitlePreservesCueIDAndExcerptWhenContentChanges() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Show/Reindexed Excerpt.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Show/Reindexed Excerpt.mkv")
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
    let originalExcerpt = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: excerptSelection(originalCue),
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
        try ExcerptDatabase(path: database.path).excerptRelation(id: originalExcerpt.id)
    )
    let rebuiltExcerpt = try #require(try ExcerptDatabase(path: database.path).excerpt(id: originalExcerpt.id))

    #expect(rebuiltCue.id == originalCue.id)
    #expect(rebuiltRelation.id == originalExcerpt.id)
    #expect(rebuiltRelation.cueID == rebuiltCue.id)
    #expect(rebuiltExcerpt.content == "Updated saved cue.")
    #expect(
        rebuiltExcerpt.contentChange == ExcerptCueContentChange(
            previousContent: "Original saved cue.",
            currentContent: "Updated saved cue."
        )
    )
    #expect(rebuiltExcerpt.createdAt == originalExcerpt.createdAt)
}

@Test
func excerptStoresSameTimeSiblingCuesSeparatelyAndDeduplicatesOneIdentity() throws {
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
    let topSelection = excerptSelection(cueRecords[0])
    let bottomSelection = excerptSelection(cueRecords[1])

    let top = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: topSelection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let bottom = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: bottomSelection,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let duplicateBottom = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: bottomSelection,
        createdAt: Date(timeIntervalSince1970: 1_900_000_000)
    )

    #expect(top.id != bottom.id)
    #expect(bottom.id == duplicateBottom.id)
    #expect(top.cueIdentity == topSelection.cueIdentity)
    #expect(bottom.cueIdentity == bottomSelection.cueIdentity)
    #expect(duplicateBottom.createdAt == bottom.createdAt)
    #expect(try ExcerptDatabase(path: database.path).excerptCount() == 2)
    #expect(try ExcerptDatabase(path: database.path).removeExcerpt(id: bottom.id))
    #expect(try ExcerptDatabase(path: database.path).excerpt(id: top.id) != nil)
    #expect(try ExcerptDatabase(path: database.path).excerpt(id: bottom.id) == nil)
}

@Test
func removingIndexedFolderPreservesCueBoundExcerptRelation() throws {
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
                text: "Excerpt should survive index removal."
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let savedExcerpt = try ExcerptDatabase(path: database.path).upsertExcerpt(
        selection: selection
    )

    try database.removeIndexedFolder(folder)

    #expect(try SearchDatabase(path: database.path).search("Excerpt").isEmpty)
    let unavailableExcerpt = try #require(
        try ExcerptDatabase(path: database.path).excerpts().first
    )
    #expect(unavailableExcerpt.id == savedExcerpt.id)
    #expect(!unavailableExcerpt.isValid)
    #expect(unavailableExcerpt.unavailableReason == .libraryUnavailable)
    #expect(unavailableExcerpt.content == "Excerpt should survive index removal.")
    #expect(unavailableExcerpt.cueGroupContent == "Excerpt should survive index removal.")
    #expect(
        try ExcerptDatabase(path: database.path).excerptRelations()
            .map(\.id) == [savedExcerpt.id]
    )
}

@Test
func excerptSavesByCueIDIntoEachListWithoutDuplicatingWithinOne() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let indexingDatabase = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let excerptDatabase = try ExcerptDatabase(path: databaseURL)
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
    let defaultListID = try #require(try excerptDatabase.firstExcerptListID())
    let secondList = try excerptDatabase.createExcerptList(name: "Second")

    // The Search table has only the Cue, so the save goes in by CueID.
    let saved = try excerptDatabase.upsertExcerpt(
        cueID: cueID,
        listID: defaultListID
    )
    #expect(try excerptDatabase.excerpt(cueID: cueID, listID: defaultListID)?.id == saved.id)

    // The same Cue still reaches another list.
    _ = try excerptDatabase.upsertExcerpt(cueID: cueID, listID: secondList.id)
    #expect(try excerptDatabase.excerptCount(listID: secondList.id) == 1)

    // Saving again into a list that already holds the Cue adds nothing.
    let repeated = try excerptDatabase.upsertExcerpt(
        cueID: cueID,
        listID: defaultListID
    )
    #expect(repeated.id == saved.id)
    #expect(try excerptDatabase.excerptCount(listID: defaultListID) == 1)
    #expect(try excerptDatabase.uniqueExcerptCueCount() == 1)
}

@Test
func cuesAndExcerptsLeaveTheLibraryWithTheTombstoneOrTheirFolder() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let staying = URL(fileURLWithPath: "/Media/Stays/Episode 1.srt")
    let tombstoned = URL(fileURLWithPath: "/Media/Stays/Episode 2.srt")
    let removed = URL(fileURLWithPath: "/Media/Goes/Episode 1.srt")
    for (subtitleFile, text) in [
        (staying, "Stays in the library"),
        (tombstoned, "Goes to the tombstone"),
        (removed, "Leaves with its folder"),
    ] {
        try database.replaceEntries(
            subtitleFile: subtitleFile,
            videoFile: subtitleFile.deletingPathExtension().appendingPathExtension("mkv"),
            entries: [
                SubtitleEntry(
                    sequenceNumber: 1,
                    startTimecode: "00:00:01,000",
                    endTimecode: "00:00:03,000",
                    startMilliseconds: 1_000,
                    endMilliseconds: 3_000,
                    text: text
                )
            ]
        )
    }
    let playbackDatabase = try PlaybackSubtitleDatabase(path: databaseURL)
    let excerptDatabase = try ExcerptDatabase(path: databaseURL)
    var cueIDs: [Int64] = []
    var excerptIDs: [Int64] = []
    for subtitleFile in [staying, tombstoned, removed] {
        let selection = try #require(try playbackDatabase.cueTextSelection(
            forSubtitleFile: subtitleFile,
            atMilliseconds: 1_500
        ))
        cueIDs.append(try #require(selection.cueLineID))
        excerptIDs.append(try excerptDatabase.upsertExcerpt(selection: selection).id)
    }
    let cueContentDatabase = try CueContentDatabase(path: databaseURL)
    #expect(try cueContentDatabase.liveCueIDs(among: cueIDs) == Set(cueIDs))
    #expect(try excerptDatabase.validExcerptIDs(among: excerptIDs) == Set(excerptIDs))

    try database.replaceEntries(
        subtitleFile: tombstoned,
        videoFile: tombstoned.deletingPathExtension().appendingPathExtension("mkv"),
        entries: []
    )
    try database.removeIndexedFolder(URL(fileURLWithPath: "/Media/Goes"))

    #expect(try cueContentDatabase.liveCueIDs(among: cueIDs + [9_999]) == [cueIDs[0]])
    #expect(try excerptDatabase.validExcerptIDs(among: excerptIDs + [9_999]) == [excerptIDs[0]])
}
