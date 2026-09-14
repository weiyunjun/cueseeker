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

/// The four Filter Menu cards.
public enum CueFacetKind: CaseIterable, Hashable, Sendable {
    case duration
    case characters
    case languages
    case watchState
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

    public var isEmpty: Bool {
        durations.isEmpty && characters.isEmpty && languages.isEmpty && watchStates.isEmpty
    }

    /// The cards with a checked option, in menu order.
    public var selectedKinds: [CueFacetKind] {
        var kinds: [CueFacetKind] = []
        if !durations.isEmpty { kinds.append(.duration) }
        if !characters.isEmpty { kinds.append(.characters) }
        if !languages.isEmpty { kinds.append(.languages) }
        if !watchStates.isEmpty { kinds.append(.watchState) }
        return kinds
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

    /// Whether a line satisfies the selection. With `negatedKind`, that card's
    /// selection must fail instead while the other three still apply: those
    /// are exactly the rows the card's unchecked options need for their counts.
    public func matches(
        duration: CueDurationFacet,
        characters cueCharacters: CueCharacterFacet,
        languages cueLanguages: Set<SubtitleLanguageCode>,
        watchState: LibraryWatchState,
        negating negatedKind: CueFacetKind? = nil
    ) -> Bool {
        let matchesDuration = durations.isEmpty || durations.contains(duration)
        let matchesCharacters = characters.isEmpty || characters.contains(cueCharacters)
        let matchesLanguages = languages.isEmpty || !languages.isDisjoint(with: cueLanguages)
        let matchesWatchState = watchStates.isEmpty || watchStates.contains(watchState)
        switch negatedKind {
        case nil:
            return matchesDuration && matchesCharacters && matchesLanguages && matchesWatchState
        case .duration:
            return !matchesDuration && matchesCharacters && matchesLanguages && matchesWatchState
        case .characters:
            return matchesDuration && !matchesCharacters && matchesLanguages && matchesWatchState
        case .languages:
            return matchesDuration && matchesCharacters && !matchesLanguages && matchesWatchState
        case .watchState:
            return matchesDuration && matchesCharacters && matchesLanguages && !matchesWatchState
        }
    }
}

public struct CueFacetDistribution: Equatable, Sendable {
    public static let zero = CueFacetDistribution(
        totalCount: 0,
        durationCounts: [:],
        characterCounts: [:],
        languageCounts: [:],
        watchStateCounts: [:]
    )

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

    public func adding(_ other: CueFacetDistribution) -> CueFacetDistribution {
        CueFacetDistribution(
            totalCount: totalCount + other.totalCount,
            durationCounts: durationCounts.merging(
                other.durationCounts,
                uniquingKeysWith: +
            ),
            characterCounts: characterCounts.merging(
                other.characterCounts,
                uniquingKeysWith: +
            ),
            languageCounts: languageCounts.merging(
                other.languageCounts,
                uniquingKeysWith: +
            ),
            watchStateCounts: watchStateCounts.merging(
                other.watchStateCounts,
                uniquingKeysWith: +
            )
        )
    }
}

public struct CueFacetSnapshot: Equatable, Sendable {
    public static let empty = CueFacetSnapshot(
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
    ) -> (
        cueIDs: [Int64],
        nextSourceIndex: Int,
        isComplete: Bool,
        distribution: CueFacetDistribution
    ) {
        let start = min(max(0, sourceIndex), cueIDs.count)
        let pageLimit = max(0, limit)
        guard pageLimit > 0 else {
            return ([], cueIDs.count, true, .zero)
        }

        var matches: [Int64] = []
        matches.reserveCapacity(min(pageLimit, cueIDs.count - start))
        var durationCounts: [CueDurationFacet: Int] = [:]
        var characterCounts: [CueCharacterFacet: Int] = [:]
        var languageCounts: [SubtitleLanguageCode: Int] = [:]
        var watchStateCounts: [LibraryWatchState: Int] = [:]
        var index = start
        while index < cueIDs.count, matches.count < pageLimit {
            let duration = durationFacets[index]
            let characters = characterFacets[index]
            let languages = languageFacets[index]
            let watchState = watchStateFacets[index]
            let matchesDuration = filter.durations.isEmpty
                || filter.durations.contains(duration)
            let matchesCharacters = filter.characters.isEmpty
                || filter.characters.contains(characters)
            let matchesLanguages = filter.languages.isEmpty
                || !filter.languages.isDisjoint(with: languages)
            let matchesWatchState = filter.watchStates.isEmpty
                || filter.watchStates.contains(watchState)

            if matchesCharacters && matchesLanguages && matchesWatchState {
                durationCounts[duration, default: 0] += 1
            }
            if matchesDuration && matchesLanguages && matchesWatchState {
                characterCounts[characters, default: 0] += 1
            }
            if matchesDuration && matchesCharacters && matchesWatchState {
                for language in languages {
                    languageCounts[language, default: 0] += 1
                }
            }
            if matchesDuration && matchesCharacters && matchesLanguages {
                watchStateCounts[watchState, default: 0] += 1
            }
            if matchesDuration
                && matchesCharacters
                && matchesLanguages
                && matchesWatchState {
                matches.append(cueIDs[index])
            }
            index += 1
        }
        return (
            matches,
            index,
            index == cueIDs.count,
            CueFacetDistribution(
                totalCount: matches.count,
                durationCounts: durationCounts,
                characterCounts: characterCounts,
                languageCounts: languageCounts,
                watchStateCounts: watchStateCounts
            )
        )
    }

    /// The rows of both snapshots in order: a filtered result's rows followed by
    /// the rows a negated scan read for one card's unchecked options.
    public func appending(_ other: CueFacetSnapshot) -> CueFacetSnapshot {
        CueFacetSnapshot(
            cueIDs: cueIDs + other.cueIDs,
            durationFacets: durationFacets + other.durationFacets,
            characterFacets: characterFacets + other.characterFacets,
            languageFacets: languageFacets + other.languageFacets,
            watchStateFacets: watchStateFacets + other.watchStateFacets
        )
    }

    public func removingCueIDs(_ removedCueIDs: Set<Int64>) -> CueFacetSnapshot {
        guard !removedCueIDs.isEmpty else { return self }

        let retainedIndices = cueIDs.indices.filter {
            !removedCueIDs.contains(cueIDs[$0])
        }
        return CueFacetSnapshot(
            cueIDs: retainedIndices.map { cueIDs[$0] },
            durationFacets: retainedIndices.map { durationFacets[$0] },
            characterFacets: retainedIndices.map { characterFacets[$0] },
            languageFacets: retainedIndices.map { languageFacets[$0] },
            watchStateFacets: retainedIndices.map { watchStateFacets[$0] }
        )
    }
}
