public enum CueDurationFacet: CaseIterable, Hashable, Sendable {
    case underOneSecond
    case oneToUnderThreeSeconds
    case threeToUnderFiveSeconds
    case fiveSecondsOrMore

    public init(durationMilliseconds: Int) {
        switch durationMilliseconds {
        case ..<1_000:
            self = .underOneSecond
        case ..<3_000:
            self = .oneToUnderThreeSeconds
        case ..<5_000:
            self = .threeToUnderFiveSeconds
        default:
            self = .fiveSecondsOrMore
        }
    }
}

public enum CueCharacterFacet: CaseIterable, Hashable, Sendable {
    case oneToTen
    case elevenToTwenty
    case twentyOneToThirty
    case thirtyOneOrMore

    public init(characterCount: Int) {
        switch characterCount {
        case ..<11:
            self = .oneToTen
        case ..<21:
            self = .elevenToTwenty
        case ..<31:
            self = .twentyOneToThirty
        default:
            self = .thirtyOneOrMore
        }
    }
}

public struct CueFacetFilter: Equatable, Sendable {
    public var durations: Set<CueDurationFacet>
    public var characters: Set<CueCharacterFacet>
    public var languages: Set<SubtitleLanguageCode>
    public var watchStates: Set<LibraryWatchState>

    public init(
        durations: Set<CueDurationFacet> = [],
        characters: Set<CueCharacterFacet> = [],
        languages: Set<SubtitleLanguageCode> = [],
        watchStates: Set<LibraryWatchState> = []
    ) {
        self.durations = durations
        self.characters = characters
        self.languages = languages
        self.watchStates = watchStates
    }

    public var activeCardCount: Int {
        var count = 0
        if !durations.isEmpty { count += 1 }
        if !characters.isEmpty { count += 1 }
        if !languages.isEmpty { count += 1 }
        if !watchStates.isEmpty { count += 1 }
        return count
    }

    public func matches(
        durationMilliseconds: Int,
        characterCount: Int,
        languages cueLanguages: Set<SubtitleLanguageCode>,
        watchState: LibraryWatchState
    ) -> Bool {
        (durations.isEmpty || durations.contains(CueDurationFacet(
            durationMilliseconds: durationMilliseconds
        ))) &&
        (characters.isEmpty || characters.contains(CueCharacterFacet(
            characterCount: characterCount
        ))) &&
        (languages.isEmpty || !languages.isDisjoint(with: cueLanguages)) &&
        (watchStates.isEmpty || watchStates.contains(watchState))
    }
}
