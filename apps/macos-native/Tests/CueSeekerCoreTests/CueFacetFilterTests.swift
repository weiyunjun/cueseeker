import Testing
@testable import CueSeekerCore

private func matches(
    _ filter: CueFacetFilter,
    durationMilliseconds: Int = 1_500,
    characterCount: Int = 12,
    languages: Set<SubtitleLanguageCode> = [.japanese],
    watchState: LibraryWatchState = .watching
) -> Bool {
    filter.matches(
        durationMilliseconds: durationMilliseconds,
        characterCount: characterCount,
        languages: languages,
        watchState: watchState
    )
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
func cueFacetFilterTreatsEverySelectedOptionAsUnrestricted() {
    let filter = CueFacetFilter()

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
func cueFacetFilterRejectsResultsWhenAnyCardHasNoSelection() {
    let filters = [
        CueFacetFilter(durations: []),
        CueFacetFilter(characters: []),
        CueFacetFilter(languages: []),
        CueFacetFilter(watchStates: []),
        CueFacetFilter(
            durations: [],
            characters: [],
            languages: [],
            watchStates: []
        ),
    ]

    #expect(filters.allSatisfy { !matches($0) })
}

@Test
func cueFacetSnapshotProjectsMatchingIDsInSourceOrder() {
    let snapshot = CueFacetSearchSnapshot(
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
        ]
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
    let snapshot = CueFacetSearchSnapshot(
        cueIDs: [1, 2, 3, 4],
        durationFacets: Array(repeating: .underOneSecond, count: 4),
        characterFacets: Array(repeating: .oneToTen, count: 4),
        languageFacets: Array(repeating: [.english], count: 4),
        watchStateFacets: Array(repeating: .unwatched, count: 4)
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
func cueFacetSnapshotReturnsZeroImmediatelyForEmptyCardSelection() {
    let snapshot = CueFacetSearchSnapshot(
        cueIDs: [1, 2],
        durationFacets: [.underOneSecond, .fiveSecondsOrMore],
        characterFacets: [.oneToTen, .thirtyOneOrMore],
        languageFacets: [[.english], [.japanese]],
        watchStateFacets: [.unwatched, .finished]
    )

    let page = snapshot.filteredCueIDs(
        using: CueFacetFilter(languages: []),
        limit: 50
    )

    #expect(page.cueIDs.isEmpty)
    #expect(page.nextSourceIndex == snapshot.cueIDs.count)
    #expect(page.isComplete)
}
