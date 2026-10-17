import Testing
@testable import CueSeekerCore

private func matches(
    _ filter: CueFacetFilter,
    durationMilliseconds: Int = 1_500,
    characterCount: Int = 12,
    languages: Set<SubtitleLanguageCode> = [.japanese],
    watchState: LibraryWatchState = .watching,
    folder: String = "/Media"
) -> Bool {
    filter.matches(
        durationMilliseconds: durationMilliseconds,
        characterCount: characterCount,
        languages: languages,
        watchState: watchState,
        folder: folder
    )
}

@Test
func cueFacetFilterFolderSelectionRemembersTheFoldersLeftOut() {
    let listed = ["/Media/A", "/Media/B", "/Media/C"]
    var filter = CueFacetFilter()
    #expect(!filter.isFolderSelected("/Media/A"))
    #expect(matches(filter, folder: "/Media/A"))

    // Selecting the first folder leaves the others out; a folder indexed
    // later is not left out, so it is selected with it.
    filter.toggleFolder("/Media/A", listed: listed)
    #expect(filter.excludedFolders == ["/Media/B", "/Media/C"])
    #expect(filter.isFolderSelected("/Media/A"))
    #expect(!filter.isFolderSelected("/Media/B"))
    #expect(matches(filter, folder: "/Media/A"))
    #expect(!matches(filter, folder: "/Media/B"))
    #expect(matches(filter, folder: "/Media/D"))
    #expect(!filter.isEmpty)

    // Every listed folder selected is still a selection; deselecting the
    // last one leaves none.
    filter.toggleFolder("/Media/B", listed: listed)
    filter.toggleFolder("/Media/C", listed: listed)
    #expect(filter.excludedFolders == [])
    #expect(!filter.isEmpty)
    filter.toggleFolder("/Media/A", listed: listed)
    filter.toggleFolder("/Media/B", listed: listed)
    filter.toggleFolder("/Media/C", listed: listed)
    #expect(filter.excludedFolders == nil)
    #expect(filter.isEmpty)

    // A selection that leaves out every listed folder, as after the selected
    // folders' root is removed, is no selection.
    let stale = CueFacetFilter(excludedFolders: ["/Media/A", "/Media/B"])
    #expect(stale.normalizingFolders(listed: ["/Media/A", "/Media/B"]).excludedFolders == nil)
    #expect(stale.normalizingFolders(listed: listed).excludedFolders == ["/Media/A", "/Media/B"])
}

@Test
func cueFacetSnapshotCountsFoldersLikeEveryOtherGroup() {
    let snapshot = CueFacetSnapshot(
        cueIDs: [1, 2, 3, 4],
        durationFacets: [.underOneSecond, .fiveSecondsOrMore, .underOneSecond, .underOneSecond],
        characterFacets: Array(repeating: .oneToTen, count: 4),
        languageFacets: Array(repeating: [.japanese], count: 4),
        watchStateFacets: Array(repeating: .unwatched, count: 4),
        folderFacets: ["/Media/A", "/Media/A", "/Media/B", "/Media/B"]
    )
    #expect(snapshot.distribution.folderCounts == ["/Media/A": 2, "/Media/B": 2])

    // Folder A with short cues: the rows are A's short cue; the Folder counts
    // ignore the Folder selection and apply Duration, while the Duration
    // counts apply the Folder selection.
    let filter = CueFacetFilter(durations: [.underOneSecond], excludedFolders: ["/Media/B"])
    let page = snapshot.filteredCueIDs(using: filter, limit: 4)
    #expect(page.cueIDs == [1])
    #expect(page.distribution.folderCounts == ["/Media/A": 1, "/Media/B": 2])
    #expect(page.distribution.durationCounts == [.underOneSecond: 1, .fiveSecondsOrMore: 1])
}

@Test
func cueFacetBucketsUseRequiredBoundaries() {
    #expect(CueDurationFacet.allCases == [
        .underOneSecond,
        .oneToUnderThreeSeconds,
        .threeToUnderFiveSeconds,
        .fiveSecondsOrMore,
    ])
    #expect(CueDurationFacet(durationMilliseconds: 999) == .underOneSecond)
    #expect(CueDurationFacet(durationMilliseconds: 1_000) == .oneToUnderThreeSeconds)
    #expect(CueDurationFacet(durationMilliseconds: 2_999) == .oneToUnderThreeSeconds)
    #expect(CueDurationFacet(durationMilliseconds: 3_000) == .threeToUnderFiveSeconds)
    #expect(CueDurationFacet(durationMilliseconds: 4_999) == .threeToUnderFiveSeconds)
    #expect(CueDurationFacet(durationMilliseconds: 5_000) == .fiveSecondsOrMore)

    #expect(CueCharacterFacet.allCases == [
        .oneToTen,
        .elevenToTwenty,
        .twentyOneToThirty,
        .thirtyOneOrMore,
    ])
    #expect(CueCharacterFacet(characterCount: 10) == .oneToTen)
    #expect(CueCharacterFacet(characterCount: 11) == .elevenToTwenty)
    #expect(CueCharacterFacet(characterCount: 20) == .elevenToTwenty)
    #expect(CueCharacterFacet(characterCount: 21) == .twentyOneToThirty)
    #expect(CueCharacterFacet(characterCount: 30) == .twentyOneToThirty)
    #expect(CueCharacterFacet(characterCount: 31) == .thirtyOneOrMore)
}

@Test
func cueCharacterFacetWidthFollowsTrimmedEastAsianWidthRules() {
    // 6 pure Chinese characters -> width 12 -> 11–20
    #expect(CueCharacterFacet.characterWidth(of: "汉字六个字数") == 12)
    #expect(CueCharacterFacet(content: "汉字六个字数") == .elevenToTwenty)

    // 6 pure English letters -> width 6 -> 1–10
    #expect(CueCharacterFacet.characterWidth(of: "abcdef") == 6)
    #expect(CueCharacterFacet(content: "abcdef") == .oneToTen)

    // 4 Japanese kana (8) + 1 internal fullwidth space U+3000 (2) -> width 10 -> 1–10
    #expect(CueCharacterFacet.characterWidth(of: "あいう　え") == 10)
    #expect(CueCharacterFacet(content: "あいう　え") == .oneToTen)

    // Leading/trailing whitespace is trimmed; internal ASCII space (1) and punctuation (1) count
    #expect(CueCharacterFacet.characterWidth(of: "  \t\n　Hello world!　\n ") == 12)
    #expect(CueCharacterFacet(content: "  \t\n　Hello world!　\n ") == .elevenToTwenty)

    // Fullwidth punctuation & alphanumerics count as 2; halfwidth katakana, Latin Extended, Cyrillic count as 1
    #expect(CueCharacterFacet.characterWidth(of: "ＡＢＣ！") == 8)
    #expect(CueCharacterFacet.characterWidth(of: "한국어") == 6)
    #expect(CueCharacterFacet.characterWidth(of: "ｱｲｳｴｵ") == 5)
    #expect(CueCharacterFacet.characterWidth(of: "éüБГ") == 4)
    #expect(CueCharacterFacet.characterWidth(of: "   \t\n　 ") == 0)
}

@Test
func cueFacetFilterTreatsNoSelectionAsUnrestricted() {
    let filter = CueFacetFilter()

    #expect(filter.durations.isEmpty)
    #expect(filter.characters.isEmpty)
    #expect(filter.languages.isEmpty)
    #expect(filter.watchStates.isEmpty)
    #expect(matches(
        filter,
        durationMilliseconds: 500,
        characterCount: 5,
        languages: [.english],
        watchState: .finished
    ))
    #expect(matches(
        filter,
        durationMilliseconds: 6_000,
        characterCount: 40,
        languages: [.unknown],
        watchState: .unwatched
    ))
}

@Test
func cueFacetFilterTreatsEverySelectedOptionAsUnrestricted() {
    let filter = CueFacetFilter(
        durations: Set(CueDurationFacet.allCases),
        characters: Set(CueCharacterFacet.allCases),
        languages: Set(SubtitleLanguageCode.allCases),
        watchStates: [.unwatched, .watching, .finished]
    )

    #expect(matches(
        filter,
        durationMilliseconds: 500,
        characterCount: 5,
        languages: [.english],
        watchState: .finished
    ))
    #expect(matches(
        filter,
        durationMilliseconds: 6_000,
        characterCount: 40,
        languages: [.unknown],
        watchState: .unwatched
    ))
}

@Test
func cueFacetFilterUsesOrWithinEveryCard() {
    let durations = CueFacetFilter(durations: [
        .oneToUnderThreeSeconds,
        .threeToUnderFiveSeconds,
    ])
    #expect(matches(durations, durationMilliseconds: 1_500))
    #expect(matches(durations, durationMilliseconds: 4_000))
    #expect(!matches(durations, durationMilliseconds: 5_000))

    let characters = CueFacetFilter(characters: [.oneToTen, .twentyOneToThirty])
    #expect(matches(characters, characterCount: 7))
    #expect(matches(characters, characterCount: 24))
    #expect(!matches(characters, characterCount: 15))

    let languages = CueFacetFilter(languages: [.japanese, .english])
    #expect(matches(languages, languages: [.japanese]))
    #expect(matches(languages, languages: [.english]))
    #expect(!matches(languages, languages: [.unknown]))

    let watchStates = CueFacetFilter(watchStates: [.watching, .finished])
    #expect(matches(watchStates, watchState: .watching))
    #expect(matches(watchStates, watchState: .finished))
    #expect(!matches(watchStates, watchState: .unwatched))
}

@Test
func cueFacetFilterUsesAndBetweenCards() {
    let filter = CueFacetFilter(
        durations: [.oneToUnderThreeSeconds],
        characters: [.elevenToTwenty],
        languages: [.japanese],
        watchStates: [.watching]
    )

    #expect(matches(filter))
    #expect(!matches(filter, durationMilliseconds: 5_000))
    #expect(!matches(filter, characterCount: 30))
    #expect(!matches(filter, languages: [.english]))
    #expect(!matches(filter, watchState: .finished))
}

@Test
func cueFacetFilterMatchesEveryLanguageAssignedToCue() {
    let multilingualCue: Set<SubtitleLanguageCode> = [.japanese, .simplifiedChinese]

    #expect(matches(CueFacetFilter(languages: [.japanese]), languages: multilingualCue))
    #expect(matches(CueFacetFilter(languages: [.simplifiedChinese]), languages: multilingualCue))
    #expect(!matches(CueFacetFilter(languages: [.unknown]), languages: multilingualCue))
    #expect(matches(CueFacetFilter(languages: [.unknown]), languages: [.unknown]))
}

@Test
func cueFacetFilterLeavesEmptyCardsUnrestricted() {
    let filter = CueFacetFilter(languages: [.japanese])

    #expect(matches(filter, durationMilliseconds: 500, languages: [.japanese]))
    #expect(matches(filter, durationMilliseconds: 6_000, languages: [.japanese]))
    #expect(!matches(filter, languages: [.english]))
}

@Test
func cueFacetSnapshotProjectsMatchingIDsInSourceOrder() {
    let snapshot = CueFacetSnapshot(
        cueIDs: [10, 20, 30, 40, 50],
        durationFacets: [
            .underOneSecond,
            .oneToUnderThreeSeconds,
            .oneToUnderThreeSeconds,
            .threeToUnderFiveSeconds,
            .oneToUnderThreeSeconds,
        ],
        characterFacets: [
            .oneToTen,
            .elevenToTwenty,
            .elevenToTwenty,
            .elevenToTwenty,
            .elevenToTwenty,
        ],
        languageFacets: [
            [.japanese],
            [.english],
            [.japanese, .english],
            [.japanese],
            [.japanese],
        ],
        watchStateFacets: [
            .watching,
            .watching,
            .watching,
            .watching,
            .finished,
        ],
        folderFacets: Array(repeating: "/Media", count: ([10, 20, 30, 40, 50]).count)
    )
    let filter = CueFacetFilter(
        durations: [.oneToUnderThreeSeconds, .threeToUnderFiveSeconds],
        characters: [.elevenToTwenty],
        languages: [.japanese],
        watchStates: [.watching]
    )

    let firstPage = snapshot.filteredCueIDs(using: filter, limit: 2)
    #expect(firstPage.cueIDs == [30, 40])
    #expect(!firstPage.isComplete)

    let secondPage = snapshot.filteredCueIDs(
        using: filter,
        startingAt: firstPage.nextSourceIndex,
        limit: 2
    )
    #expect(secondPage.cueIDs.isEmpty)
    #expect(secondPage.isComplete)
}

@Test
func cueFacetSnapshotStopsAfterRequestedPageAndContinuesWithoutDuplicates() {
    let snapshot = CueFacetSnapshot(
        cueIDs: [1, 2, 3, 4],
        durationFacets: Array(repeating: .underOneSecond, count: 4),
        characterFacets: Array(repeating: .oneToTen, count: 4),
        languageFacets: Array(repeating: [.english], count: 4),
        watchStateFacets: Array(repeating: .unwatched, count: 4),
        folderFacets: Array(repeating: "/Media", count: ([1, 2, 3, 4]).count)
    )

    let firstPage = snapshot.filteredCueIDs(using: CueFacetFilter(), limit: 2)
    let secondPage = snapshot.filteredCueIDs(
        using: CueFacetFilter(),
        startingAt: firstPage.nextSourceIndex,
        limit: 2
    )

    #expect(firstPage.cueIDs == [1, 2])
    #expect(firstPage.nextSourceIndex == 2)
    #expect(!firstPage.isComplete)
    #expect(secondPage.cueIDs == [3, 4])
    #expect(secondPage.isComplete)
}

@Test
func cueFacetSnapshotTreatsEmptyCardSelectionAsAll() {
    let snapshot = CueFacetSnapshot(
        cueIDs: [1, 2],
        durationFacets: [.underOneSecond, .fiveSecondsOrMore],
        characterFacets: [.oneToTen, .thirtyOneOrMore],
        languageFacets: [[.english], [.japanese]],
        watchStateFacets: [.unwatched, .finished],
        folderFacets: Array(repeating: "/Media", count: ([1, 2]).count)
    )

    let page = snapshot.filteredCueIDs(
        using: CueFacetFilter(languages: []),
        limit: 50
    )

    #expect(page.cueIDs == [1, 2])
    #expect(page.nextSourceIndex == snapshot.cueIDs.count)
    #expect(page.isComplete)
}

@Test
func cueFacetSnapshotBuildsDisjunctiveCountsDuringPagedProjection() {
    let snapshot = CueFacetSnapshot(
        cueIDs: [1, 2, 3, 4, 5, 6],
        durationFacets: [
            .underOneSecond,
            .oneToUnderThreeSeconds,
            .oneToUnderThreeSeconds,
            .threeToUnderFiveSeconds,
            .underOneSecond,
            .oneToUnderThreeSeconds,
        ],
        characterFacets: [
            .oneToTen,
            .oneToTen,
            .elevenToTwenty,
            .elevenToTwenty,
            .elevenToTwenty,
            .elevenToTwenty,
        ],
        languageFacets: [
            [.japanese],
            [.english],
            [.japanese, .english],
            [.japanese],
            [.japanese],
            [.japanese],
        ],
        watchStateFacets: [
            .watching,
            .watching,
            .watching,
            .finished,
            .watching,
            .finished,
        ],
        folderFacets: Array(repeating: "/Media", count: ([1, 2, 3, 4, 5, 6]).count)
    )
    let filter = CueFacetFilter(
        durations: [.oneToUnderThreeSeconds],
        characters: [.elevenToTwenty],
        languages: [.japanese],
        watchStates: [.watching]
    )

    let firstPage = snapshot.filteredCueIDs(using: filter, limit: 1)
    let secondPage = snapshot.filteredCueIDs(
        using: filter,
        startingAt: firstPage.nextSourceIndex,
        limit: snapshot.cueIDs.count
    )
    let distribution = firstPage.distribution.adding(secondPage.distribution)

    #expect(firstPage.cueIDs == [3])
    #expect(secondPage.cueIDs.isEmpty)
    #expect(secondPage.isComplete)
    #expect(distribution.totalCount == 1)
    #expect(distribution.durationCounts == [
        .underOneSecond: 1,
        .oneToUnderThreeSeconds: 1,
    ])
    #expect(distribution.characterCounts == [
        .elevenToTwenty: 1,
    ])
    #expect(distribution.languageCounts == [
        .english: 1,
        .japanese: 1,
    ])
    #expect(distribution.watchStateCounts == [
        .watching: 1,
        .finished: 1,
    ])
}
