public enum CueDurationFacet: String, CaseIterable, Hashable, Sendable {
    case underOneSecond = "under_1s"
    case oneToUnderThreeSeconds = "1s_to_2_999s"
    case threeToUnderFiveSeconds = "3s_to_4_999s"
    case fiveSecondsOrMore = "5s_or_more"

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

public enum CueCharacterFacet: String, CaseIterable, Hashable, Sendable {
    case oneToTen = "1_to_10"
    case elevenToTwenty = "11_to_20"
    case twentyOneToThirty = "21_to_30"
    case thirtyOneOrMore = "31_or_more"

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
        durations: Set<CueDurationFacet> = Set(CueDurationFacet.allCases),
        characters: Set<CueCharacterFacet> = Set(CueCharacterFacet.allCases),
        languages: Set<SubtitleLanguageCode> = Set(SubtitleLanguageCode.allCases),
        watchStates: Set<LibraryWatchState> = [.unwatched, .watching, .finished]
    ) {
        self.durations = durations
        self.characters = characters
        self.languages = languages
        self.watchStates = watchStates
    }

    public func matches(
        durationMilliseconds: Int,
        characterCount: Int,
        languages cueLanguages: Set<SubtitleLanguageCode>,
        watchState: LibraryWatchState
    ) -> Bool {
        matches(
            duration: CueDurationFacet(
                durationMilliseconds: durationMilliseconds
            ),
            characters: CueCharacterFacet(
                characterCount: characterCount
            ),
            languages: cueLanguages,
            watchState: watchState
        )
    }

    public func matches(
        duration: CueDurationFacet,
        characters cueCharacters: CueCharacterFacet,
        languages cueLanguages: Set<SubtitleLanguageCode>,
        watchState: LibraryWatchState
    ) -> Bool {
        durations.contains(duration) &&
        characters.contains(cueCharacters) &&
        !languages.isDisjoint(with: cueLanguages) &&
        watchStates.contains(watchState)
    }
}

public struct CueFacetDistribution: Equatable, Sendable {
    public let totalCount: Int
    public let durationCounts: [CueDurationFacet: Int]
    public let characterCounts: [CueCharacterFacet: Int]
    public let languageCounts: [SubtitleLanguageCode: Int]
    public let watchStateCounts: [LibraryWatchState: Int]

    public init(
        totalCount: Int,
        durationCounts: [CueDurationFacet: Int],
        characterCounts: [CueCharacterFacet: Int],
        languageCounts: [SubtitleLanguageCode: Int],
        watchStateCounts: [LibraryWatchState: Int]
    ) {
        self.totalCount = totalCount
        self.durationCounts = durationCounts
        self.characterCounts = characterCounts
        self.languageCounts = languageCounts
        self.watchStateCounts = watchStateCounts
    }
}

public struct CueFacetSearchSnapshot: Equatable, Sendable {
    public static let empty = CueFacetSearchSnapshot(
        cueIDs: [],
        durationFacets: [],
        characterFacets: [],
        languageFacets: [],
        watchStateFacets: []
    )

    public let cueIDs: [Int64]
    public let durationFacets: [CueDurationFacet]
    public let characterFacets: [CueCharacterFacet]
    public let languageFacets: [Set<SubtitleLanguageCode>]
    public let watchStateFacets: [LibraryWatchState]
    public let distribution: CueFacetDistribution

    init(
        cueIDs: [Int64],
        durationFacets: [CueDurationFacet],
        characterFacets: [CueCharacterFacet],
        languageFacets: [Set<SubtitleLanguageCode>],
        watchStateFacets: [LibraryWatchState]
    ) {
        precondition(
            durationFacets.count == cueIDs.count
                && characterFacets.count == cueIDs.count
                && languageFacets.count == cueIDs.count
                && watchStateFacets.count == cueIDs.count
        )

        let resolvedLanguageFacets = languageFacets.map {
            $0.isEmpty ? Set([SubtitleLanguageCode.unknown]) : $0
        }
        var languageCounts: [SubtitleLanguageCode: Int] = [:]
        for languages in resolvedLanguageFacets {
            for language in languages {
                languageCounts[language, default: 0] += 1
            }
        }

        self.cueIDs = cueIDs
        self.durationFacets = durationFacets
        self.characterFacets = characterFacets
        self.languageFacets = resolvedLanguageFacets
        self.watchStateFacets = watchStateFacets
        distribution = CueFacetDistribution(
            totalCount: cueIDs.count,
            durationCounts: Dictionary(grouping: durationFacets, by: { $0 })
                .mapValues { $0.count },
            characterCounts: Dictionary(grouping: characterFacets, by: { $0 })
                .mapValues { $0.count },
            languageCounts: languageCounts,
            watchStateCounts: Dictionary(grouping: watchStateFacets, by: { $0 })
                .mapValues { $0.count }
        )
    }

    public func filteredCueIDs(
        using filter: CueFacetFilter,
        startingAt sourceIndex: Int = 0,
        limit: Int
    ) -> (cueIDs: [Int64], nextSourceIndex: Int, isComplete: Bool) {
        let start = min(max(0, sourceIndex), cueIDs.count)
        let pageLimit = max(0, limit)
        guard pageLimit > 0,
              !filter.durations.isEmpty,
              !filter.characters.isEmpty,
              !filter.languages.isEmpty,
              !filter.watchStates.isEmpty
        else {
            return ([], cueIDs.count, true)
        }

        var matches: [Int64] = []
        matches.reserveCapacity(min(pageLimit, cueIDs.count - start))
        var index = start
        while index < cueIDs.count, matches.count < pageLimit {
            if filter.matches(
                duration: durationFacets[index],
                characters: characterFacets[index],
                languages: languageFacets[index],
                watchState: watchStateFacets[index]
            ) {
                matches.append(cueIDs[index])
            }
            index += 1
        }
        return (matches, index, index == cueIDs.count)
    }
}
