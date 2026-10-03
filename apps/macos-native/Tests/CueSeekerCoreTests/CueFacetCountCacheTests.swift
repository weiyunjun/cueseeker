import Foundation
import Testing
@testable import CueSeekerCore

private func facetCueGroup(
    startMilliseconds: Int,
    durationMilliseconds: Int,
    characterCount: Int,
    eventIndex: Int,
    style: String
) -> SubtitleCueGroup {
    testCueGroup(
        startMilliseconds: startMilliseconds,
        endMilliseconds: startMilliseconds + durationMilliseconds,
        content: String(repeating: "a", count: characterCount),
        eventIndex: eventIndex,
        sourceStyle: style
    )
}

private func facetLanguageDetection(
    _ languages: Set<SubtitleLanguageCode>
) -> SubtitleLanguageDetectionResult {
    SubtitleLanguageDetectionResult(
        languages: languages,
        confidence: 1,
        segmentCount: 1,
        effectiveCharacterCount: 10,
        distribution: []
    )
}

private func indexFacetFixture(at databaseURL: URL) throws -> (IndexingDatabase, URL, URL) {
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    let subtitleFile = URL(fileURLWithPath: "/Media/Facets.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Facets.mkv")
    let cueGroups = [
        facetCueGroup(
            startMilliseconds: 0,
            durationMilliseconds: 999,
            characterCount: 10,
            eventIndex: 0,
            style: "JP"
        ),
        facetCueGroup(
            startMilliseconds: 2_000,
            durationMilliseconds: 1_000,
            characterCount: 11,
            eventIndex: 1,
            style: "ZH"
        ),
        facetCueGroup(
            startMilliseconds: 4_000,
            durationMilliseconds: 3_000,
            characterCount: 21,
            eventIndex: 2,
            style: "MULTI"
        ),
        facetCueGroup(
            startMilliseconds: 8_000,
            durationMilliseconds: 5_000,
            characterCount: 31,
            eventIndex: 3,
            style: "UNKNOWN"
        ),
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .ass,
        fileDetection: nil,
        styleDetections: [
            "JP": facetLanguageDetection([.japanese]),
            "ZH": facetLanguageDetection([.simplifiedChinese]),
            "MULTI": facetLanguageDetection([.japanese, .english]),
        ],
        cueGroupLanguages: [
            [.japanese],
            [.simplifiedChinese],
            [.japanese, .english],
            [.unknown],
        ]
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups,
        languageAnalysis: analysis
    )
    return (database, subtitleFile, videoFile)
}

@Test
func cueFacetCountsTrackIndexedDataAndLanguageMembership() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    let (database, subtitleFile, videoFile) = try indexFacetFixture(at: databaseURL)

    let initial = try SearchDatabase(path: databaseURL).cueFacetDistribution()
    #expect(initial.totalCount == 4)
    #expect(initial.durationCounts == [
        .underOneSecond: 1,
        .oneToUnderThreeSeconds: 1,
        .threeToUnderFiveSeconds: 1,
        .fiveSecondsOrMore: 1,
    ])
    #expect(initial.characterCounts == [
        .oneToTen: 1,
        .elevenToTwenty: 1,
        .twentyOneToThirty: 1,
        .thirtyOneOrMore: 1,
    ])
    #expect(initial.languageCounts == [
        .english: 1,
        .japanese: 2,
        .simplifiedChinese: 1,
        .unknown: 1,
    ])
    #expect(initial.watchStateCounts == [.unwatched: 4])

    let remainingGroup = facetCueGroup(
        startMilliseconds: 0,
        durationMilliseconds: 999,
        characterCount: 10,
        eventIndex: 0,
        style: "JP"
    )
    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [remainingGroup],
        languageAnalysis: SubtitleLanguageAnalysis(
            format: .ass,
            fileDetection: nil,
            styleDetections: ["JP": facetLanguageDetection([.japanese])],
            cueGroupLanguages: [[.japanese]]
        )
    )
    #expect(try SearchDatabase(path: databaseURL).cueFacetDistribution().totalCount == 1)

    try database.removeStaleEntries(under: URL(fileURLWithPath: "/Media"), keeping: [])
    #expect(try SearchDatabase(path: databaseURL).cueFacetDistribution().totalCount == 0)
}

@Test
func watchStateChangesUpdateOnlyWatchFacetCounts() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    let (_, _, videoFile) = try indexFacetFixture(at: databaseURL)
    let durationValue = CueDurationFacet.underOneSecond.rawValue

    try executeDatabaseTestSQLite(
        at: databaseURL,
        "UPDATE cue_facet_counts SET cue_count = 99 WHERE facet = 'duration' AND value = '\(durationValue)';"
    )
    let library = try LibraryDatabase(path: databaseURL)
    try library.setLibraryWatchState(videoFile: videoFile, duration: nil, state: .finished)

    var distribution = try SearchDatabase(path: databaseURL).cueFacetDistribution()
    #expect(distribution.durationCounts[.underOneSecond] == 99)
    #expect(distribution.watchStateCounts == [.finished: 4])

    try executeDatabaseTestSQLite(
        at: databaseURL,
        "UPDATE cue_facet_counts SET cue_count = 77 WHERE facet = 'watchStatus' AND value = 'finished';"
    )
    try library.setLibraryWatchState(videoFile: videoFile, duration: nil, state: .finished)
    distribution = try SearchDatabase(path: databaseURL).cueFacetDistribution()
    #expect(distribution.watchStateCounts[.finished] == 77)

    try library.setLibraryWatchState(videoFile: videoFile, duration: nil, state: .watching)
    distribution = try SearchDatabase(path: databaseURL).cueFacetDistribution()
    #expect(distribution.watchStateCounts == [.watching: 4])
}

@Test
func schema39MigrationBackfillsFacetCountsWithoutStartupRebuilds() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    _ = try indexFacetFixture(at: databaseURL)

    try executeDatabaseTestSQLite(
        at: databaseURL,
        "DROP TABLE cue_facet_counts; \(preSchema47ExcerptTablesSQL) PRAGMA user_version = 39;"
    )
    try DatabaseBootstrap.prepare(at: databaseURL)
    #expect(try SearchDatabase(path: databaseURL).cueFacetDistribution().totalCount == 4)

    let durationValue = CueDurationFacet.underOneSecond.rawValue
    try executeDatabaseTestSQLite(
        at: databaseURL,
        "UPDATE cue_facet_counts SET cue_count = 55 WHERE facet = 'duration' AND value = '\(durationValue)';"
    )
    try DatabaseBootstrap.prepare(at: databaseURL)
    #expect(
        try SearchDatabase(path: databaseURL)
            .cueFacetDistribution()
            .durationCounts[.underOneSecond] == 55
    )
}

@Test
func exactSearchBuildsCompleteFacetSnapshotWithItsResultIDs() throws {
    let databaseURL = temporaryDatabaseURL()
    defer { removeTemporaryDatabase(at: databaseURL) }
    let (_, _, videoFile) = try indexFacetFixture(at: databaseURL)
    try LibraryDatabase(path: databaseURL).setLibraryWatchState(
        videoFile: videoFile,
        duration: nil,
        state: .finished
    )

    let search = try SearchDatabase(path: databaseURL)
    let page = try search.searchPage("a", limit: 1, cursor: .start)
    let snapshot = try #require(page.facetSnapshot)

    #expect(page.results.count == 1)
    #expect(page.totalCount == 4)
    #expect(page.cueIDs == snapshot.cueIDs)
    #expect(snapshot.durationFacets == [
        .underOneSecond,
        .oneToUnderThreeSeconds,
        .threeToUnderFiveSeconds,
        .fiveSecondsOrMore,
    ])
    #expect(snapshot.characterFacets == [
        .oneToTen,
        .elevenToTwenty,
        .twentyOneToThirty,
        .thirtyOneOrMore,
    ])
    #expect(snapshot.languageFacets == [
        [.japanese],
        [.simplifiedChinese],
        [.english, .japanese],
        [.unknown],
    ])
    #expect(snapshot.watchStateFacets == Array(repeating: .finished, count: 4))
    #expect(snapshot.distribution.totalCount == page.totalCount)
    #expect(snapshot.distribution.durationCounts.values.reduce(0, +) == page.totalCount)
    #expect(snapshot.distribution.characterCounts.values.reduce(0, +) == page.totalCount)
    #expect(snapshot.distribution.languageCounts == [
        .english: 1,
        .japanese: 2,
        .simplifiedChinese: 1,
        .unknown: 1,
    ])
    #expect(snapshot.distribution.watchStateCounts == [.finished: 4])

    let completeVisiblePage = try search.searchVisiblePage(
        "a",
        limit: 10,
        cursor: .start
    )
    #expect(completeVisiblePage.facetSnapshot == snapshot)
}
