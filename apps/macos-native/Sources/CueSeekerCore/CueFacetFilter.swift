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

    public init(content: String) {
        self.init(characterCount: Self.characterWidth(of: content))
    }

    /// Computes the East Asian character width of a subtitle line after
    /// trimming leading and trailing whitespace (`W` and `F` count as 2;
    /// all other Unicode scalars count as 1).
    public static func characterWidth(of content: String) -> Int {
        let scalars = content.unicodeScalars
        guard let firstIndex = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let lastIndex = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else {
            return 0
        }
        var width = 0
        var index = firstIndex
        while true {
            width += isEastAsianWideOrFullwidth(scalars[index]) ? 2 : 1
            if index == lastIndex {
                break
            }
            index = scalars.index(after: index)
        }
        return width
    }

    /// Unicode Standard Annex #11 `East_Asian_Width` (`W` Wide or `F` Fullwidth).
    public static func isEastAsianWideOrFullwidth(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        if v < 0x1100 {
            return false
        }
        switch v {
        case 0x1100...0x115F,
             0x231A...0x231B,
             0x2329...0x232A,
             0x23E9...0x23EC,
             0x23F0,
             0x23F3,
             0x25FD...0x25FE,
             0x2614...0x2615,
             0x2630...0x2637,
             0x2648...0x2653,
             0x267F,
             0x268A...0x268F,
             0x2693,
             0x26A1,
             0x26AA...0x26AB,
             0x26BD...0x26BE,
             0x26C4...0x26C5,
             0x26CE,
             0x26D4,
             0x26EA,
             0x26F2...0x26F3,
             0x26F5,
             0x26FA,
             0x26FD,
             0x2705,
             0x270A...0x270B,
             0x2728,
             0x274C,
             0x274E,
             0x2753...0x2755,
             0x2757,
             0x2795...0x2797,
             0x27B0,
             0x27BF,
             0x2B1B...0x2B1C,
             0x2B50,
             0x2B55,
             0x2E80...0x2E99,
             0x2E9B...0x2EF3,
             0x2F00...0x2FD5,
             0x2FF0...0x303E,
             0x3041...0x3096,
             0x3099...0x30FF,
             0x3105...0x312F,
             0x3131...0x318E,
             0x3190...0x31E5,
             0x31EF...0x321E,
             0x3220...0x3247,
             0x3250...0xA48C,
             0xA490...0xA4C6,
             0xA960...0xA97C,
             0xAC00...0xD7A3,
             0xF900...0xFAFF,
             0xFE10...0xFE19,
             0xFE30...0xFE52,
             0xFE54...0xFE66,
             0xFE68...0xFE6B,
             0xFF01...0xFF60,
             0xFFE0...0xFFE6,
             0x16FE0...0x16FE4,
             0x16FF0...0x16FF1,
             0x17000...0x187F7,
             0x18800...0x18CD5,
             0x18CFF...0x18D08,
             0x1AFF0...0x1AFF3,
             0x1AFF5...0x1AFFB,
             0x1AFFD...0x1AFFE,
             0x1B000...0x1B122,
             0x1B132,
             0x1B150...0x1B152,
             0x1B155,
             0x1B164...0x1B167,
             0x1B170...0x1B2FB,
             0x1D300...0x1D356,
             0x1D360...0x1D376,
             0x1F004,
             0x1F0CF,
             0x1F18E,
             0x1F191...0x1F19A,
             0x1F200...0x1F202,
             0x1F210...0x1F23B,
             0x1F240...0x1F248,
             0x1F250...0x1F251,
             0x1F260...0x1F265,
             0x1F300...0x1F320,
             0x1F32D...0x1F335,
             0x1F337...0x1F37C,
             0x1F37E...0x1F393,
             0x1F3A0...0x1F3CA,
             0x1F3CF...0x1F3D3,
             0x1F3E0...0x1F3F0,
             0x1F3F4,
             0x1F3F8...0x1F43E,
             0x1F440,
             0x1F442...0x1F4FC,
             0x1F4FF...0x1F53D,
             0x1F54B...0x1F54E,
             0x1F550...0x1F567,
             0x1F57A,
             0x1F595...0x1F596,
             0x1F5A4,
             0x1F5FB...0x1F64F,
             0x1F680...0x1F6C5,
             0x1F6CC,
             0x1F6D0...0x1F6D2,
             0x1F6D5...0x1F6D7,
             0x1F6DC...0x1F6DF,
             0x1F6EB...0x1F6EC,
             0x1F6F4...0x1F6FC,
             0x1F7E0...0x1F7EB,
             0x1F7F0,
             0x1F90C...0x1F93A,
             0x1F93C...0x1F945,
             0x1F947...0x1F9FF,
             0x1FA70...0x1FA7C,
             0x1FA80...0x1FA89,
             0x1FA8F...0x1FAC6,
             0x1FACE...0x1FADC,
             0x1FADF...0x1FAE9,
             0x1FAF0...0x1FAF8,
             0x20000...0x2FFFD,
             0x30000...0x3FFFD:
            return true
        default:
            return false
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
