import Testing
import CueSeekerCore

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
func cueFacetFilterTreatsEmptySelectionsAsAll() {
    let filter = CueFacetFilter()

    #expect(filter.activeCardCount == 0)
    #expect(matches(filter, languages: [.japanese, .english]))
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
func cueFacetFilterUsesAndForEveryActiveCardCombination() {
    for mask in 0..<16 {
        let filter = CueFacetFilter(
            durations: mask & 1 == 0 ? [] : [.oneToUnderThreeSeconds],
            characters: mask & 2 == 0 ? [] : [.elevenToTwenty],
            languages: mask & 4 == 0 ? [] : [.japanese],
            watchStates: mask & 8 == 0 ? [] : [.watching]
        )

        #expect(filter.activeCardCount == mask.nonzeroBitCount)
        #expect(matches(filter, languages: [.japanese, .english]))
        if mask & 1 != 0 { #expect(!matches(filter, durationMilliseconds: 5_000)) }
        if mask & 2 != 0 { #expect(!matches(filter, characterCount: 30)) }
        if mask & 4 != 0 { #expect(!matches(filter, languages: [.english])) }
        if mask & 8 != 0 { #expect(!matches(filter, watchState: .finished)) }
    }
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
func cueFacetFilterCanClearEveryCardBackToAll() {
    var filter = CueFacetFilter(
        durations: [.underOneSecond],
        characters: [.oneToTen],
        languages: [.unknown],
        watchStates: [.unwatched]
    )

    filter.durations.removeAll()
    filter.characters.removeAll()
    filter.languages.removeAll()
    filter.watchStates.removeAll()

    #expect(filter.activeCardCount == 0)
    #expect(matches(
        filter,
        durationMilliseconds: 5_000,
        characterCount: 31,
        languages: [.japanese],
        watchState: .finished
    ))
}
