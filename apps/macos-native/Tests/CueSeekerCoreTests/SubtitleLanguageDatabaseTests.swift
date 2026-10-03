import Foundation
import Testing
@testable import CueSeekerCore

@Test
func persistsSRTLanguageAnalysisWithCueGroupLanguages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Japanese.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Japanese.mkv")
    let entries = [
        SubtitleEntry(
            sequenceNumber: 1,
            startTimecode: "00:00:01,000",
            endTimecode: "00:00:03,000",
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            text: "今日はみんなで映画を見に行きます。"
        ),
        SubtitleEntry(
            sequenceNumber: 2,
            startTimecode: "00:00:04,000",
            endTimecode: "00:00:06,000",
            startMilliseconds: 4_000,
            endMilliseconds: 6_000,
            text: "明日は学校のあとで友達と話します。"
        )
    ]
    let cueGroups = entries.enumerated().map { index, entry in
        entry.cueGroup(eventIndex: index)
    }
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .srt, cueGroups: cueGroups)

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: subtitleFile))

    let detections = try database.languageDetections(forSubtitleFile: subtitleFile)
    #expect(detections.count == 1)
    #expect(detections[0].scope == .file)
    #expect(detections[0].scopeKey == nil)
    #expect(detections[0].algorithmVersion == SubtitleLanguageRecognizer.algorithmVersion)
    #expect(detections[0].languages == [.japanese])
    #expect(detections[0].confidence >= SubtitleLanguageRecognizer.defaultConfidenceThreshold)

    let storedEntries = try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: subtitleFile)
    #expect(languagesByCueGroupID[storedEntries[0].id] == [.japanese])
    #expect(languagesByCueGroupID[storedEntries[1].id] == [.japanese])
}

@Test
func persistsASSStyleLanguageAnalysisForUsedStylesOnly() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Bilingual.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Bilingual.mkv")
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: JP,2,20,20,30
    Style: CN,8,20,20,40
    Style: Unused,2,20,20,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
    Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,我们今天准备演出，大家一起练习新的歌曲。
    Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
    """
    let cueGroups = ASSParser.parseCueGroups(contents)
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .ass, cueGroups: cueGroups)

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups,
        languageAnalysis: analysis
    )

    #expect(try database.hasCurrentSubtitleLanguageManifest(forSubtitleFile: subtitleFile))

    let detections = try database.languageDetections(forSubtitleFile: subtitleFile)
    #expect(detections.map(\.scopeKey) == ["CN", "JP"])
    #expect(detections.first { $0.scopeKey == "CN" }?.languages == [.simplifiedChinese])
    #expect(detections.first { $0.scopeKey == "JP" }?.languages == [.japanese])

    let storedEntries = try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile)
    let languagesByCueGroupID = try database.cueGroupLanguages(forSubtitleFile: subtitleFile)
    #expect(languagesByCueGroupID[storedEntries[0].id] == [.japanese, .simplifiedChinese])
    #expect(languagesByCueGroupID[storedEntries[1].id] == [.japanese])
}

@Test
func searchLanguageFilterMatchesCueGroupLanguagesOrUnknown() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/LanguageFilter.srt")
    let videoFile = URL(fileURLWithPath: "/Media/LanguageFilter.mkv")
    let entries = [
        languageFilterTestEntry(sequenceNumber: 1, text: "Shared Japanese cue"),
        languageFilterTestEntry(sequenceNumber: 2, text: "Shared English cue"),
        languageFilterTestEntry(sequenceNumber: 3, text: "Shared Unknown cue"),
        languageFilterTestEntry(sequenceNumber: 4, text: "Shared Generic Chinese cue"),
        languageFilterTestEntry(sequenceNumber: 5, text: "Shared Mixed cue"),
        languageFilterTestEntry(sequenceNumber: 6, text: "Shared Traditional cue")
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .srt,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [
            [.japanese],
            [.english],
            [.unknown],
            [.chinese],
            [.simplifiedChinese, .japanese],
            [.traditionalChinese]
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    #expect(try SearchDatabase(path: database.path).search("shared", languageFilter: .all).map(\.content) == [
        "Shared Japanese cue",
        "Shared English cue",
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Mixed cue",
        "Shared Traditional cue"
    ])
    #expect(try SearchDatabase(path: database.path).search("shared", languageFilter: .japanese).map(\.content) == [
        "Shared Japanese cue",
        "Shared Unknown cue",
        "Shared Mixed cue"
    ])
    #expect(try SearchDatabase(path: database.path).search("shared", languageFilter: .english).map(\.content) == [
        "Shared English cue",
        "Shared Unknown cue"
    ])
    #expect(try SearchDatabase(path: database.path).search("shared", languageFilter: .chinese).map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Mixed cue",
        "Shared Traditional cue"
    ])
    #expect(try SearchDatabase(path: database.path).search("shared", languageFilter: .simplifiedChinese).map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Mixed cue"
    ])
    #expect(try SearchDatabase(path: database.path).search("shared", languageFilter: .traditionalChinese).map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue",
        "Shared Traditional cue"
    ])

    let visiblePage = try SearchDatabase(path: database.path).searchVisiblePage(
        "shared",
        limit: 2,
        cursor: .start,
        languageFilter: .chinese
    )
    #expect(visiblePage.results.map(\.content) == [
        "Shared Unknown cue",
        "Shared Generic Chinese cue"
    ])
    #expect(visiblePage.nextCursor?.offset == 2)
}

@Test
func searchResultsExposeCueGroupLanguages() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/LanguageResultTags.srt")
    let videoFile = URL(fileURLWithPath: "/Media/LanguageResultTags.mkv")
    let entries = [
        languageFilterTestEntry(sequenceNumber: 1, text: "Shared Japanese cue"),
        languageFilterTestEntry(sequenceNumber: 2, text: "Shared Mixed cue")
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .srt,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [
            [.japanese],
            [.simplifiedChinese, .japanese]
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )
    try LibraryDatabase(path: databaseURL).refreshPresentationAfterIndexedContentChange()

    let exactPage = try SearchDatabase(path: database.path).searchPage("shared", limit: 10)
    #expect(exactPage.results.map(\.displayTitle) == [
        "Media - 01",
        "Media - 01"
    ])
    #expect(exactPage.results.map(\.languages) == [
        [.japanese],
        [.japanese, .simplifiedChinese]
    ])

    let visiblePage = try SearchDatabase(path: database.path).searchVisiblePage("shared", limit: 2, cursor: .start)
    #expect(visiblePage.results.map(\.displayTitle) == [
        "Media - 01",
        "Media - 01"
    ])
    #expect(visiblePage.results.map(\.languages) == [
        [.japanese],
        [.japanese, .simplifiedChinese]
    ])
}

@Test
func searchLanguageFilterAppliesToMatchingLinesBeforeMergedDisplayGroups() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/BilingualLineFilter.ass")
    let videoFile = URL(fileURLWithPath: "/Media/BilingualLineFilter.mkv")
    let cueGroups = [
        languageFilterASSCueGroup(
            startMilliseconds: 1_000,
            lines: [
                (style: "CN", content: "今天来了"),
                (style: "JP", content: "明日は来ません")
            ]
        ),
        languageFilterASSCueGroup(
            startMilliseconds: 2_000,
            lines: [
                (style: "CN", content: "只是中文上下文"),
                (style: "JP", content: "今日は大丈夫です")
            ]
        ),
        languageFilterASSCueGroup(
            startMilliseconds: 3_000,
            lines: [
                (style: nil, content: "今天没有样式"),
                (style: "JP", content: "明日も大丈夫です")
            ]
        )
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .ass,
        fileDetection: nil,
        styleDetections: [
            "CN": SubtitleLanguageDetectionResult(
                languages: [.simplifiedChinese],
                confidence: 1,
                segmentCount: 2,
                effectiveCharacterCount: 16,
                distribution: [SubtitleLanguageDistribution(language: .simplifiedChinese, share: 1)]
            ),
            "JP": SubtitleLanguageDetectionResult(
                languages: [.japanese],
                confidence: 1,
                segmentCount: 3,
                effectiveCharacterCount: 24,
                distribution: [SubtitleLanguageDistribution(language: .japanese, share: 1)]
            )
        ],
        cueGroupLanguages: [
            [.simplifiedChinese, .japanese],
            [.simplifiedChinese, .japanese],
            [.japanese]
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: cueGroups,
        languageAnalysis: analysis
    )

    #expect(try SearchDatabase(path: database.path).search("今天", languageFilter: .all).map(\.startMilliseconds) == [
        1_000,
        3_000
    ])
    #expect(try SearchDatabase(path: database.path).search("今天", languageFilter: .japanese).map(\.startMilliseconds) == [
        3_000
    ])
    #expect(try SearchDatabase(path: database.path).search("今天", languageFilter: .chinese).map(\.startMilliseconds) == [
        1_000,
        3_000
    ])

    let japaneseResults = try SearchDatabase(path: database.path).search("今日", languageFilter: .japanese)
    #expect(japaneseResults.map(\.startMilliseconds) == [2_000])
    #expect(japaneseResults.first?.cueLines == ["今日は大丈夫です"])
    #expect(japaneseResults.first?.cueGroupLines == [
        "只是中文上下文",
        "今日は大丈夫です"
    ])
    #expect(japaneseResults.first?.languages == [.japanese])
    #expect(try SearchDatabase(path: database.path).search("今日", languageFilter: .chinese).isEmpty)

    let visiblePage = try SearchDatabase(path: database.path).searchVisiblePage(
        "今天",
        limit: 1,
        cursor: .start,
        languageFilter: .japanese
    )
    #expect(visiblePage.results.map(\.startMilliseconds) == [3_000])
    #expect(visiblePage.nextCursor == nil)
}

@Test
func searchLanguageFilterTreatsMissingLanguageRowsAsUnknown() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/LegacyLanguage.srt")
    let videoFile = URL(fileURLWithPath: "/Media/LegacyLanguage.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            languageFilterTestEntry(sequenceNumber: 1, text: "Legacy shared row")
        ]
    )

    #expect(try SearchDatabase(path: database.path).search("legacy", languageFilter: .japanese).map(\.content) == [
        "Legacy shared row"
    ])
}

@Test
func searchFilterSetMatchesLanguageCollectionValues() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/FilterLanguages.srt")
    let videoFile = URL(fileURLWithPath: "/Media/FilterLanguages.mkv")
    let entries = [
        languageFilterTestEntry(sequenceNumber: 1, text: "Shared Japanese filter"),
        languageFilterTestEntry(sequenceNumber: 2, text: "Shared English filter"),
        languageFilterTestEntry(sequenceNumber: 3, text: "Shared Mixed filter")
    ]
    let analysis = SubtitleLanguageAnalysis(
        format: .srt,
        fileDetection: nil,
        styleDetections: [:],
        cueGroupLanguages: [
            [.japanese],
            [.english],
            [.simplifiedChinese, .japanese]
        ]
    )

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries,
        languageAnalysis: analysis
    )

    let filterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .language,
            operatorID: .contains,
            value: "ja"
        )
    ])
    let page = try SearchDatabase(path: database.path).searchPage("shared", limit: 10, filterSet: filterSet)

    #expect(page.totalCount == 2)
    #expect(page.results.map(\.content) == [
        "Shared Japanese filter",
        "Shared Mixed filter"
    ])
}
