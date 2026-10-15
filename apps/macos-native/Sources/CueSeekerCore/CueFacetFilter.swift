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

/// The five Filter dialog groups.
public enum CueFacetKind: CaseIterable, Hashable, Sendable {
    case duration
    case characters
    case languages
    case watchState
    case folder
}

public struct CueFacetFilter: Equatable, Sendable {
    public var durations: Set<CueDurationFacet>
    public var characters: Set<CueCharacterFacet>
    public var languages: Set<SubtitleLanguageCode>
    public var watchStates: Set<LibraryWatchState>
    /// The Folder group remembers the listed folders that are not selected,
    /// so a folder indexed later is selected with the rest; nil when the
    /// group has no selection.
    public var excludedFolders: Set<String>?

    public init(
        durations: Set<CueDurationFacet> = [],
        characters: Set<CueCharacterFacet> = [],
        languages: Set<SubtitleLanguageCode> = [],
        watchStates: Set<LibraryWatchState> = [],
        excludedFolders: Set<String>? = nil
    ) {
        self.durations = durations
        self.characters = characters
        self.languages = languages
        self.watchStates = watchStates
        self.excludedFolders = excludedFolders
    }

    public var isEmpty: Bool {
        durations.isEmpty && characters.isEmpty && languages.isEmpty && watchStates.isEmpty
            && excludedFolders == nil
    }

    public func isFolderSelected(_ folder: String) -> Bool {
        excludedFolders.map { !$0.contains(folder) } ?? false
    }

    /// Selecting the first folder leaves every other listed folder out;
    /// deselecting the last one leaves the group without a selection.
    public mutating func toggleFolder(_ folder: String, listed: [String]) {
        var excluded = excludedFolders ?? Set(listed)
        if excluded.contains(folder) {
            excluded.remove(folder)
        } else {
            excluded.insert(folder)
        }
        excludedFolders = excluded
        self = normalizingFolders(listed: listed)
    }

    /// A selection that leaves out every listed folder is no selection.
    public func normalizingFolders<Folders: Collection>(
        listed: Folders
    ) -> CueFacetFilter where Folders.Element == String {
        guard let excludedFolders, excludedFolders.isSuperset(of: listed) else {
            return self
        }
        var filter = self
        filter.excludedFolders = nil
        return filter
    }

    public func matches(
        durationMilliseconds: Int,
        characterCount: Int,
        languages cueLanguages: Set<SubtitleLanguageCode>,
        watchState: LibraryWatchState,
        folder: String
    ) -> Bool {
        matches(
            duration: CueDurationFacet(
                durationMilliseconds: durationMilliseconds
            ),
            characters: CueCharacterFacet(
                characterCount: characterCount
            ),
            languages: cueLanguages,
            watchState: watchState,
            folder: folder
        )
    }

    /// Whether a line satisfies the selection: every group with a selected
    /// option must hold.
    public func matches(
        duration: CueDurationFacet,
        characters cueCharacters: CueCharacterFacet,
        languages cueLanguages: Set<SubtitleLanguageCode>,
        watchState: LibraryWatchState,
        folder: String
    ) -> Bool {
        (durations.isEmpty || durations.contains(duration))
            && (characters.isEmpty || characters.contains(cueCharacters))
            && (languages.isEmpty || !languages.isDisjoint(with: cueLanguages))
            && (watchStates.isEmpty || watchStates.contains(watchState))
            && (excludedFolders?.contains(folder) != true)
    }
}

public struct CueFacetDistribution: Equatable, Sendable {
    public static let zero = CueFacetDistribution(
        totalCount: 0,
        durationCounts: [:],
        characterCounts: [:],
        languageCounts: [:],
        watchStateCounts: [:],
        folderCounts: [:]
    )

    public let totalCount: Int
    public let durationCounts: [CueDurationFacet: Int]
    public let characterCounts: [CueCharacterFacet: Int]
    public let languageCounts: [SubtitleLanguageCode: Int]
    public let watchStateCounts: [LibraryWatchState: Int]
    public let folderCounts: [String: Int]

    public init(
        totalCount: Int,
        durationCounts: [CueDurationFacet: Int],
        characterCounts: [CueCharacterFacet: Int],
        languageCounts: [SubtitleLanguageCode: Int],
        watchStateCounts: [LibraryWatchState: Int],
        folderCounts: [String: Int]
    ) {
        self.totalCount = totalCount
        self.durationCounts = durationCounts
        self.characterCounts = characterCounts
        self.languageCounts = languageCounts
        self.watchStateCounts = watchStateCounts
        self.folderCounts = folderCounts
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
            ),
            folderCounts: folderCounts.merging(
                other.folderCounts,
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
        watchStateFacets: [],
        folderFacets: []
    )

    public let cueIDs: [Int64]
    public let durationFacets: [CueDurationFacet]
    public let characterFacets: [CueCharacterFacet]
    public let languageFacets: [Set<SubtitleLanguageCode>]
    public let watchStateFacets: [LibraryWatchState]
    public let folderFacets: [String]
    public let distribution: CueFacetDistribution

    init(
        cueIDs: [Int64],
        durationFacets: [CueDurationFacet],
        characterFacets: [CueCharacterFacet],
        languageFacets: [Set<SubtitleLanguageCode>],
        watchStateFacets: [LibraryWatchState],
        folderFacets: [String]
    ) {
        precondition(
            durationFacets.count == cueIDs.count
                && characterFacets.count == cueIDs.count
                && languageFacets.count == cueIDs.count
                && watchStateFacets.count == cueIDs.count
                && folderFacets.count == cueIDs.count
        )

        var resolvedLanguageFacets = languageFacets
        var durationCounts: [CueDurationFacet: Int] = [:]
        var characterCounts: [CueCharacterFacet: Int] = [:]
        var languageCounts: [SubtitleLanguageCode: Int] = [:]
        var watchStateCounts: [LibraryWatchState: Int] = [:]
        var folderCounts: [String: Int] = [:]

        for index in 0..<cueIDs.count {
            durationCounts[durationFacets[index], default: 0] += 1
            characterCounts[characterFacets[index], default: 0] += 1
            watchStateCounts[watchStateFacets[index], default: 0] += 1
            folderCounts[folderFacets[index], default: 0] += 1
            let languages = resolvedLanguageFacets[index]
            if languages.isEmpty {
                let unknownSet: Set<SubtitleLanguageCode> = [.unknown]
                resolvedLanguageFacets[index] = unknownSet
                languageCounts[.unknown, default: 0] += 1
            } else {
                for language in languages {
                    languageCounts[language, default: 0] += 1
                }
            }
        }

        self.cueIDs = cueIDs
        self.durationFacets = durationFacets
        self.characterFacets = characterFacets
        self.languageFacets = resolvedLanguageFacets
        self.watchStateFacets = watchStateFacets
        self.folderFacets = folderFacets
        distribution = CueFacetDistribution(
            totalCount: cueIDs.count,
            durationCounts: durationCounts,
            characterCounts: characterCounts,
            languageCounts: languageCounts,
            watchStateCounts: watchStateCounts,
            folderCounts: folderCounts
        )
    }

    public func keeping(cueIDs keptIDs: Set<Int64>) -> CueFacetSnapshot {
        guard !keptIDs.isEmpty else {
            return .empty
        }
        var nextCueIDs: [Int64] = []
        var nextDurations: [CueDurationFacet] = []
        var nextCharacters: [CueCharacterFacet] = []
        var nextLanguages: [Set<SubtitleLanguageCode>] = []
        var nextWatchStates: [LibraryWatchState] = []
        var nextFolders: [String] = []

        for index in 0..<cueIDs.count {
            let id = cueIDs[index]
            guard keptIDs.contains(id) else { continue }
            nextCueIDs.append(id)
            nextDurations.append(durationFacets[index])
            nextCharacters.append(characterFacets[index])
            nextLanguages.append(languageFacets[index])
            nextWatchStates.append(watchStateFacets[index])
            nextFolders.append(folderFacets[index])
        }

        return CueFacetSnapshot(
            cueIDs: nextCueIDs,
            durationFacets: nextDurations,
            characterFacets: nextCharacters,
            languageFacets: nextLanguages,
            watchStateFacets: nextWatchStates,
            folderFacets: nextFolders
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
        if filter.isEmpty, start == 0, pageLimit >= cueIDs.count {
            return (cueIDs, cueIDs.count, true, distribution)
        }

        var matches: [Int64] = []
        matches.reserveCapacity(min(pageLimit, cueIDs.count - start))
        var durationCounts: [CueDurationFacet: Int] = [:]
        var characterCounts: [CueCharacterFacet: Int] = [:]
        var languageCounts: [SubtitleLanguageCode: Int] = [:]
        var watchStateCounts: [LibraryWatchState: Int] = [:]
        var folderCounts: [String: Int] = [:]
        var index = start
        while index < cueIDs.count, matches.count < pageLimit {
            let duration = durationFacets[index]
            let characters = characterFacets[index]
            let languages = languageFacets[index]
            let watchState = watchStateFacets[index]
            let folder = folderFacets[index]
            let matchesDuration = filter.durations.isEmpty
                || filter.durations.contains(duration)
            let matchesCharacters = filter.characters.isEmpty
                || filter.characters.contains(characters)
            let matchesLanguages = filter.languages.isEmpty
                || !filter.languages.isDisjoint(with: languages)
            let matchesWatchState = filter.watchStates.isEmpty
                || filter.watchStates.contains(watchState)
            let matchesFolder = filter.excludedFolders?.contains(folder) != true

            if matchesCharacters && matchesLanguages && matchesWatchState && matchesFolder {
                durationCounts[duration, default: 0] += 1
            }
            if matchesDuration && matchesLanguages && matchesWatchState && matchesFolder {
                characterCounts[characters, default: 0] += 1
            }
            if matchesDuration && matchesCharacters && matchesWatchState && matchesFolder {
                for language in languages {
                    languageCounts[language, default: 0] += 1
                }
            }
            if matchesDuration && matchesCharacters && matchesLanguages && matchesFolder {
                watchStateCounts[watchState, default: 0] += 1
            }
            if matchesDuration && matchesCharacters && matchesLanguages && matchesWatchState {
                folderCounts[folder, default: 0] += 1
            }
            if matchesDuration
                && matchesCharacters
                && matchesLanguages
                && matchesWatchState
                && matchesFolder {
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
                watchStateCounts: watchStateCounts,
                folderCounts: folderCounts
            )
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
            watchStateFacets: retainedIndices.map { watchStateFacets[$0] },
            folderFacets: retainedIndices.map { folderFacets[$0] }
        )
    }
}
