import Foundation
import Testing
@testable import CueSeekerCore

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
func shioriResidentSnapshotLoadsRelationsCurrentCueContentAndTagsTogether() throws {
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
    let saved = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let tag = try ShioriDatabase(path: databaseURL).assignShioriTag(
        named: "Review",
        toShioriID: saved.id
    )

    let snapshot = try ShioriDatabase(path: database.path).shioriResidentSnapshot()

    #expect(snapshot.relations.map(\.id) == [saved.id])
    #expect(snapshot.relations.map(\.cueID) == snapshot.cueContents.map(\.cueID))
    #expect(snapshot.cueContents.map(\.content) == ["Resident Cue"])
    #expect(snapshot.tagsByShioriID[saved.id] == [tag])
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
            )
        ]
    )
    let selection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let cueID = try #require(selection.cueLineID)
    let defaultShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection
    )

    try executeDatabaseTestSQLite(
        at: databaseURL,
        """
        INSERT INTO shiori_lists(id, name, created_at)
        VALUES (2, 'Future List', '2026-07-21T00:00:00Z');
        INSERT INTO shioris(list_id, cue_id, created_at)
        VALUES (2, \(cueID), '2026-07-21T00:00:01Z');
        """
    )

    #expect(try ShioriDatabase(path: database.path).shioriRelations().map(\.id) == [defaultShiori.id])
    let futureRelation = try #require(try ShioriDatabase(path: database.path).shioriRelations(listID: 2).first)
    #expect(futureRelation.cueID == cueID)
    #expect(futureRelation.listID == 2)

    do {
        try executeDatabaseTestSQLite(
            at: databaseURL,
            """
            INSERT INTO shioris(list_id, cue_id, created_at)
            VALUES (2, \(cueID), '2026-07-21T00:00:02Z');
            """
        )
        Issue.record("Expected one Shiori relation per Cue inside one list")
    } catch {
        // Expected unique(list_id, cue_id) enforcement.
    }
}

@Test
func shioriPersistsAndResolvesCueIDWhileTagsReferenceShioriID() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let shioriDatabase = try ShioriDatabase(path: databaseURL)

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

    let tag = try shioriDatabase.assignShioriTag(named: "CueID", toShioriID: shiori.id)
    #expect(try shioriDatabase.shioriTags(forShioriID: shiori.id) == [tag])
}

@Test
func rebuildingSubtitleRemapsShioriAndPreservesTagsWhenCueContentChanges() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let shioriDatabase = try ShioriDatabase(path: databaseURL)

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
    let tag = try shioriDatabase.assignShioriTag(
        named: "Keep after reindex",
        toShioriID: originalShiori.id
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

    #expect(rebuiltCue.id != originalCue.id)
    #expect(rebuiltRelation.id == originalShiori.id)
    #expect(rebuiltRelation.cueID == rebuiltCue.id)
    #expect(rebuiltShiori.content == "Updated saved cue.")
    #expect(rebuiltShiori.createdAt == originalShiori.createdAt)
    #expect(try shioriDatabase.shioriTags(forShioriID: originalShiori.id) == [tag])
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
func shioriTagAPIsValidatePersistAndDeleteAssignments() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)
    let shioriDatabase = try ShioriDatabase(path: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Tags.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Tags.mkv")
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
                text: "First tagged shiori."
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:03,000",
                endTimecode: "00:00:04,000",
                startMilliseconds: 3_000,
                endMilliseconds: 4_000,
                text: "Second tagged shiori."
            ),
        ]
    )

    let firstSelection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 1_500
    ))
    let secondSelection = try #require(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(
        forSubtitleFile: subtitleFile,
        atMilliseconds: 3_500
    ))
    let firstShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: firstSelection
    )
    let secondShiori = try ShioriDatabase(path: database.path).upsertShiori(
        selection: secondSelection
    )

    let createdAt = try #require(ISO8601DateFormatter().date(from: "2026-07-08T00:00:00Z"))
    let tag = try shioriDatabase.createShioriTag(named: "  Tag  ", createdAt: createdAt)
    let duplicate = try shioriDatabase.createShioriTag(named: "Tag")
    let lowerCaseTag = try shioriDatabase.createShioriTag(named: "tag")

    #expect(tag.name == "Tag")
    #expect(duplicate.id == tag.id)
    #expect(lowerCaseTag.id != tag.id)
    #expect(try shioriDatabase.shioriTag(named: " Tag ")?.id == tag.id)

    #expect(try shioriDatabase.assignShioriTag(tagID: tag.id, toShioriID: firstShiori.id))
    #expect(try !shioriDatabase.assignShioriTag(tagID: tag.id, toShioriID: firstShiori.id))
    let secondTag = try shioriDatabase.assignShioriTag(named: "復習", toShioriID: secondShiori.id)

    var tagsByShioriID = try shioriDatabase.shioriTagsByShioriID(
        forShioriIDs: [firstShiori.id, secondShiori.id]
    )
    #expect(tagsByShioriID[firstShiori.id]?.map(\.name) == ["Tag"])
    #expect(tagsByShioriID[secondShiori.id]?.map(\.name) == ["復習"])

    #expect(try shioriDatabase.removeShioriTagAssignment(tagID: tag.id, fromShioriID: firstShiori.id))
    #expect(try !shioriDatabase.removeShioriTagAssignment(tagID: tag.id, fromShioriID: firstShiori.id))
    #expect(try shioriDatabase.shioriTags(forShioriID: firstShiori.id).isEmpty)

    #expect(try shioriDatabase.assignShioriTag(tagID: tag.id, toShioriID: firstShiori.id))
    #expect(try shioriDatabase.assignShioriTag(tagID: tag.id, toShioriID: secondShiori.id))
    let deletion = try shioriDatabase.deleteShioriTag(tagID: tag.id)
    #expect(deletion.didDelete)
    #expect(deletion.affectedShioriIDs == [firstShiori.id, secondShiori.id].sorted())
    #expect(try shioriDatabase.shioriTag(id: tag.id) == nil)
    tagsByShioriID = try shioriDatabase.shioriTagsByShioriID(
        forShioriIDs: [firstShiori.id, secondShiori.id]
    )
    #expect(tagsByShioriID[firstShiori.id]?.isEmpty == true)
    #expect(tagsByShioriID[secondShiori.id]?.map(\.id) == [secondTag.id])

    let missingDeletion = try shioriDatabase.deleteShioriTag(tagID: -1)
    #expect(!missingDeletion.didDelete)
    #expect(missingDeletion.affectedShioriIDs.isEmpty)

    do {
        _ = try shioriDatabase.assignShioriTag(named: "Orphan", toShioriID: -1)
        Issue.record("Expected missing Shiori assignment to fail")
    } catch {
        #expect(try shioriDatabase.shioriTag(named: "Orphan") == nil)
    }
}

@Test
func shioriTagValidationRejectsInvalidNames() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    try DatabaseBootstrap.prepare(at: databaseURL)
    let shioriDatabase = try ShioriDatabase(path: databaseURL)

    expectShioriTagValidationError(.emptyName) {
        _ = try shioriDatabase.createShioriTag(named: "   ")
    }
    expectShioriTagValidationError(.nameTooLong(maximumCharacters: 20)) {
        _ = try shioriDatabase.createShioriTag(named: "123456789012345678901")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try shioriDatabase.createShioriTag(named: "hello\nworld")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try shioriDatabase.createShioriTag(named: "\nhello")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try shioriDatabase.createShioriTag(named: "hello\tworld")
    }
    expectShioriTagValidationError(.invalidCharacters) {
        _ = try shioriDatabase.createShioriTag(named: "hello\u{200B}world")
    }

    let allowed = try shioriDatabase.createShioriTag(named: #" C++ "Q" / \ & 😀 "#)
    #expect(allowed.name == #"C++ "Q" / \ & 😀"#)
}

@Test
func removingIndexedFolderRemovesCueBoundShioriRelation() throws {
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
    _ = try ShioriDatabase(path: database.path).upsertShiori(
        selection: selection
    )

    try database.removeIndexedFolder(folder)

    #expect(try SearchDatabase(path: database.path).search("Shiori").isEmpty)
    #expect(try ShioriDatabase(path: database.path).shioris().isEmpty)
    #expect(try ShioriDatabase(path: database.path).shioriRelations().isEmpty)
}
