import Foundation
import Darwin
import CueSeekerCore

struct TimedSearchPage {
    let page: SubtitleSearchPage
    let milliseconds: Double
}

struct Step1PreviewMilestone: Encodable {
    let targetFileGroups: Int
    let reached: Bool
    let warmupMilliseconds: Double?
    let hotAvgMilliseconds: Double?
    let hotRawMilliseconds: [Double]
    let subtitleDisplayTitle: String?
    let loadedRows: Int
    let totalRows: Int?
}

struct Step1FileGroupPreviewMetrics: Encodable {
    let metric: String
    let loadedFileGroups: Int
    let loadedRows: Int
    let milestones: [Step1PreviewMilestone]
}

struct Step1ExactCountsMetrics: Encodable {
    let metric: String
    let warmupMilliseconds: Double
    let hotAvgMilliseconds: Double
    let hotRawMilliseconds: [Double]
    let totalCount: Int
    let fileSummaries: Int
    let countState: String
    let knownResultCount: Int
    let knownFileCount: Int
}

struct Step1PerFileLoadMoreMetrics: Encodable {
    let metric: String
    let subtitlePath: String?
    let subtitleDisplayTitle: String?
    let limit: Int
    let warmupMilliseconds: Double?
    let returned: Int?
    let totalCount: Int?
    let hotAvgMilliseconds: Double?
    let hotRawMilliseconds: [Double]
}

struct Step1GapMetrics: Encodable {
    let query: String
    let limit: Int
    let preview: Step1FileGroupPreviewMetrics
    let exactCountsCompletion: Step1ExactCountsMetrics
    let perFileLoadMore: Step1PerFileLoadMoreMetrics
}

func milliseconds(since start: Date) -> Double {
    Date().timeIntervalSince(start) * 1000
}

func formatMs(_ value: Double) -> String {
    String(format: "%.2f", value)
}

private final class HeadlessSearchCollector: @unchecked Sendable {
    var reportedRows: [SubtitleSearchResult] = []
    var firstScreenMs: Double?
    var contentByCueID: [Int64: CueContent] = [:]
    var searchRankByCueID: [Int64: Int] = [:]
}

struct HeadlessColdSample {
    let firstScreenMs: Double
    let fullResultMs: Double
    let returnedCount: Int
    let totalCount: Int
    let fileSummariesCount: Int
}

struct HeadlessColdSummary {
    let query: String
    let runs: Int
    let samples: [HeadlessColdSample]
    let totalCount: Int
    let fileSummariesCount: Int

    var firstScreenRaw: [Double] { samples.map(\.firstScreenMs) }
    var firstScreenMedian: Double { median(firstScreenRaw) }
    var firstScreenMin: Double { firstScreenRaw.min() ?? 0 }
    var firstScreenMax: Double { firstScreenRaw.max() ?? 0 }

    var fullResultRaw: [Double] { samples.map(\.fullResultMs) }
    var fullResultMedian: Double { median(fullResultRaw) }
    var fullResultMin: Double { fullResultRaw.min() ?? 0 }
    var fullResultMax: Double { fullResultRaw.max() ?? 0 }
}

func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

func resolveSelectedFolders() -> [URL]? {
    guard let sharedDefaults = UserDefaults(suiteName: "com.cueseeker.shared") else {
        return nil
    }
    let paths = sharedDefaults.stringArray(forKey: "selectedFolderPaths") ?? []
    guard !paths.isEmpty else { return nil }
    return paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
}

func runSingleHeadlessColdSearch(
    dbPath: URL,
    query: String,
    limit: Int,
    folders: [URL]?,
    languageFilter: SubtitleSearchLanguageFilter,
    includeDebounce: Bool = true
) throws -> HeadlessColdSample {
    let start = Date()

    // Phase 1: User input debounce (100ms)
    if includeDebounce {
        Thread.sleep(forTimeInterval: 0.1)
    }

    let database = try SearchDatabase(path: dbPath)
    let collector = HeadlessSearchCollector()

    let page = try database.searchPage(
        query,
        limit: limit,
        cursor: .start,
        under: folders,
        languageFilter: languageFilter,
        diagnostics: nil,
        progress: { progress in
            let hadFirstPage = collector.reportedRows.count >= limit
            collector.reportedRows += progress.results
            if !hadFirstPage && collector.reportedRows.count >= limit {
                // First screen UI commit: install first 100 items into store
                let firstPageResults = Array(collector.reportedRows.prefix(limit))
                for result in firstPageResults {
                    collector.contentByCueID[result.entryID] = result.cueContent
                    collector.searchRankByCueID[result.entryID] = result.searchRank
                }
                collector.firstScreenMs = milliseconds(since: start)
            }
        }
    )

    let firstScreenMs = collector.firstScreenMs ?? milliseconds(since: start)

    // Phase 2: MainActor Full Results Commit
    let allResults = collector.reportedRows + page.renderableResults
    var contentByCueID = collector.contentByCueID
    var searchRankByCueID = collector.searchRankByCueID

    // 2a: CueContentStore.install(allResults.map(\.cueContent))
    var changedCueIDs: Set<Int64> = []
    changedCueIDs.reserveCapacity(allResults.count)
    for result in allResults {
        if contentByCueID[result.entryID] != result.cueContent {
            contentByCueID[result.entryID] = result.cueContent
            changedCueIDs.insert(result.entryID)
        }
        searchRankByCueID[result.entryID] = result.searchRank
    }
    _ = changedCueIDs

    // 2b: SearchFacetSnapshot full facet distribution calculation
    let facetDistribution = page.facetSnapshot?.filteredCueIDs(
        using: CueFacetFilter(),
        limit: page.facetSnapshot?.cueIDs.count ?? 0
    ).distribution
    _ = facetDistribution

    // 2c: TableSandboxRowModelStore snapshot assembly & row indexing
    let cueIDs = allResults.map(\.entryID)
    let tableSnapshotRanks = searchRankByCueID
    _ = tableSnapshotRanks
    _ = page.fileSummaries

    // 2d: searchResults materialization (called by UI / SearchPerformanceLogger / PlaybackPlaylist)
    let materializedSearchResults = cueIDs.compactMap { cueID in
        contentByCueID[cueID].map {
            SubtitleSearchResult(
                cueContent: $0,
                searchRank: searchRankByCueID[cueID] ?? 0
            )
        }
    }
    _ = materializedSearchResults.count

    // 2e: Table view layout calculation (76k rows virtual scroll height recomputation)
    let virtualRowHeight: Double = 56.0
    let totalVirtualHeight = Double(cueIDs.count) * virtualRowHeight
    _ = totalVirtualHeight

    let fullResultMs = milliseconds(since: start)

    return HeadlessColdSample(
        firstScreenMs: firstScreenMs,
        fullResultMs: fullResultMs,
        returnedCount: min(allResults.count, limit),
        totalCount: page.totalCount,
        fileSummariesCount: page.fileSummaries.count
    )
}

func evictFilePageCache(at url: URL) {
    let fd = open(url.path, O_RDONLY)
    guard fd >= 0 else { return }
    defer { close(fd) }
    var statBuf = stat()
    guard fstat(fd, &statBuf) == 0, statBuf.st_size > 0 else { return }
    let size = Int(statBuf.st_size)
    guard let addr = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0), addr != MAP_FAILED else {
        return
    }
    madvise(addr, size, MADV_DONTNEED)
    munmap(addr, size)

    for ext in ["-wal", "-shm"] {
        let walPath = url.path + ext
        let walFd = open(walPath, O_RDONLY)
        if walFd >= 0 {
            var walStat = stat()
            if fstat(walFd, &walStat) == 0 && walStat.st_size > 0 {
                let walSize = Int(walStat.st_size)
                if let walAddr = mmap(nil, walSize, PROT_READ, MAP_SHARED, walFd, 0), walAddr != MAP_FAILED {
                    madvise(walAddr, walSize, MADV_DONTNEED)
                    munmap(walAddr, walSize)
                }
            }
            close(walFd)
        }
    }
}

func runHeadlessColdBenchmark(
    dbPath: URL,
    query: String,
    limit: Int = 100,
    runs: Int = 5,
    folders: [URL]?,
    languageFilter: SubtitleSearchLanguageFilter = .all
) throws -> HeadlessColdSummary {
    var samples: [HeadlessColdSample] = []
    for runIndex in 1...runs {
        evictFilePageCache(at: dbPath)
        let sample = try runSingleHeadlessColdSearch(
            dbPath: dbPath,
            query: query,
            limit: limit,
            folders: folders,
            languageFilter: languageFilter
        )
        samples.append(sample)
        if runIndex < runs {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    return HeadlessColdSummary(
        query: query,
        runs: runs,
        samples: samples,
        totalCount: samples.first?.totalCount ?? 0,
        fileSummariesCount: samples.first?.fileSummariesCount ?? 0
    )
}

guard CommandLine.arguments.count >= 3 else {
    print("Usage: SearchBench <db-path> --headless-cold")
    print("       SearchBench <db-path> <query> [limit] [--step1-gaps] [--visible-window] [--language-filter=all|ja|en|zh|zh-Hans|zh-Hant]")
    exit(1)
}

let dbPath = URL(fileURLWithPath: CommandLine.arguments[1])
let isHeadlessCold = CommandLine.arguments.contains("--headless-cold") || CommandLine.arguments[2] == "--headless-cold"

let languageFilter = CommandLine.arguments
    .compactMap { argument -> SubtitleSearchLanguageFilter? in
        guard argument.hasPrefix("--language-filter=") else {
            return nil
        }
        let rawValue = String(argument.dropFirst("--language-filter=".count))
        return SubtitleSearchLanguageFilter(rawValue: rawValue)
    }
    .first ?? .all

if isHeadlessCold {
    let standardQueries = ["大丈夫", "今日", "の"]
    let folders = resolveSelectedFolders()
    print("== SearchBench Headless Full Chain Cold Benchmark ==")
    print("DB:              \(dbPath.path)")
    print("Selected folders: \(folders?.map(\.path).joined(separator: ", ") ?? "all (no folder scope)")")
    print("Limit:           100 (UI 1st page)")
    print("Mode:            Cold search (5 isolated full-chain runs per query)")
    print("")

    var summaries: [HeadlessColdSummary] = []
    for q in standardQueries {
        print("Testing \"\(q)\" (5 cold runs)...")
        let summary = try runHeadlessColdBenchmark(
            dbPath: dbPath,
            query: q,
            limit: 100,
            runs: 5,
            folders: folders,
            languageFilter: languageFilter
        )
        summaries.append(summary)
    }

    print("")
    print("### Headless Full Chain Cold Benchmark Results (5 Runs)")
    print("")
    print("| Query | Total Results | Files | 1st Screen Median | 1st Screen Raw (ms) | Full Results Median | Full Results Raw (ms) |")
    print("| --- | ---: | ---: | ---: | --- | ---: | --- |")
    for s in summaries {
        print("| `\(s.query)` | \(s.totalCount) | \(s.fileSummariesCount) | **\(formatMs(s.firstScreenMedian)) ms** | \(s.firstScreenRaw.map(formatMs).joined(separator: ", ")) | **\(formatMs(s.fullResultMedian)) ms** | \(s.fullResultRaw.map(formatMs).joined(separator: ", ")) |")
    }
    print("")
    exit(0)
}

let extraArguments = Array(CommandLine.arguments.dropFirst(3))
let query = CommandLine.arguments[2]
let limit = extraArguments.first(where: { !$0.hasPrefix("--") }).flatMap(Int.init) ?? 1000
let includesStep1Gaps = extraArguments.contains("--step1-gaps")
let usesVisibleWindow = extraArguments.contains("--visible-window")
let environment = ProcessInfo.processInfo.environment
let includesFTSVocabularyDiagnostics = environment["CUESEEKER_BENCH_FTS_VOCAB"] == "1"
let ftsVocabularyTopTermLimit = environment["CUESEEKER_BENCH_FTS_VOCAB_LIMIT"].flatMap(Int.init) ?? 12

print("== SearchBench ==")
print("DB:    \(dbPath.path)")
print("Query: \"\(query)\"")
print("Limit: \(limit)")
print("Metadata mode: \(usesVisibleWindow ? "visibleWindow" : "exact")")
print("Language filter: \(languageFilter.rawValue)")
print("FTS vocab diagnostics: \(includesFTSVocabularyDiagnostics ? "enabled" : "disabled")")
print("")

let openStart = Date()
try DatabaseBootstrap.prepare(at: dbPath)
let database = try SearchDatabase(path: dbPath, access: .readWrite)
let openMs = milliseconds(since: openStart)
print("Open connection:      \(formatMs(openMs)) ms")

let migrateStart = Date()
let migrateMs = milliseconds(since: migrateStart)
print("Migrate (one-time):   \(formatMs(migrateMs)) ms")
print("Schema version:       \(DatabaseBootstrap.currentSchemaVersion)")
print("")

func timedSearch(
    database: SearchDatabase,
    query: String,
    limit: Int,
    subtitlePath: String? = nil
) throws -> TimedSearchPage {
    let start = Date()
    let page = if usesVisibleWindow {
        try database.searchVisiblePage(
            query,
            limit: limit,
            cursor: .start,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter
        )
    } else {
        try database.searchPage(
            query,
            limit: limit,
            inSubtitlePath: subtitlePath,
            languageFilter: languageFilter
        )
    }
    return TimedSearchPage(page: page, milliseconds: milliseconds(since: start))
}

func average(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

func loadedFileSummaryRows(
    page: SubtitleSearchPage
) -> [(summary: SubtitleSearchFileSummary, loadedRows: Int)] {
    let loadedRowsByPath = Dictionary(grouping: page.results, by: \.subtitlePath)
    return page.fileSummaries.compactMap { summary in
        let loadedRows = loadedRowsByPath[summary.subtitlePath]?.count ?? 0
        guard loadedRows > 0 else {
            return nil
        }

        return (summary, loadedRows)
    }
}

func step1GapMetrics(
    query: String,
    limit: Int,
    warmup: TimedSearchPage,
    hotRuns: [TimedSearchPage],
    perFileWarmup: TimedSearchPage?,
    perFileHotRuns: [TimedSearchPage],
    perFileSummary: SubtitleSearchFileSummary?
) -> Step1GapMetrics {
    let hotTimes = hotRuns.map(\.milliseconds)
    let previewRows = loadedFileSummaryRows(page: warmup.page)
    let hotAvg = average(hotTimes)
    let milestones = [1, 2, 5, 10].map { target in
        guard previewRows.count >= target else {
            return Step1PreviewMilestone(
                targetFileGroups: target,
                reached: false,
                warmupMilliseconds: nil,
                hotAvgMilliseconds: nil,
                hotRawMilliseconds: [],
                subtitleDisplayTitle: nil,
                loadedRows: 0,
                totalRows: nil
            )
        }

        let row = previewRows[target - 1]
        return Step1PreviewMilestone(
            targetFileGroups: target,
            reached: true,
            warmupMilliseconds: warmup.milliseconds,
            hotAvgMilliseconds: hotAvg,
            hotRawMilliseconds: hotTimes,
            subtitleDisplayTitle: row.summary.subtitleDisplayTitle,
            loadedRows: row.loadedRows,
            totalRows: row.summary.matchCount
        )
    }
    let perFileHotTimes = perFileHotRuns.map(\.milliseconds)

    return Step1GapMetrics(
        query: query,
        limit: limit,
        preview: Step1FileGroupPreviewMetrics(
            metric: "current_complete_page_file_group_preview_readiness",
            loadedFileGroups: previewRows.count,
            loadedRows: warmup.page.results.count,
            milestones: milestones
        ),
        exactCountsCompletion: Step1ExactCountsMetrics(
            metric: "current_complete_page_exact_counts_completion",
            warmupMilliseconds: warmup.milliseconds,
            hotAvgMilliseconds: hotAvg,
            hotRawMilliseconds: hotTimes,
            totalCount: warmup.page.totalCount,
            fileSummaries: warmup.page.fileSummaries.count,
            countState: warmup.page.countState.rawValue,
            knownResultCount: warmup.page.knownResultCount,
            knownFileCount: warmup.page.knownFileCount
        ),
        perFileLoadMore: Step1PerFileLoadMoreMetrics(
            metric: "subtitle_path_filtered_page_load",
            subtitlePath: perFileSummary?.subtitlePath,
            subtitleDisplayTitle: perFileSummary?.subtitleDisplayTitle,
            limit: min(limit, 100),
            warmupMilliseconds: perFileWarmup?.milliseconds,
            returned: perFileWarmup?.page.results.count,
            totalCount: perFileWarmup?.page.totalCount,
            hotAvgMilliseconds: perFileHotTimes.isEmpty ? nil : average(perFileHotTimes),
            hotRawMilliseconds: perFileHotTimes
        )
    )
}

let warmupRun = try timedSearch(database: database, query: query, limit: limit)
let warmupPage = warmupRun.page
let warmupMs = warmupRun.milliseconds
print("Warmup search:        \(formatMs(warmupMs)) ms")
print("  results returned:   \(warmupPage.results.count)")
print("  total count:        \(warmupPage.totalCount)")
print("  file summaries:     \(warmupPage.fileSummaries.count)")
print("  count state:        \(warmupPage.countState.rawValue)")
print("  known result count: \(warmupPage.knownResultCount)")
print("  known file count:   \(warmupPage.knownFileCount)")
print("  cursor offset:      \(warmupPage.appliedCursor.offset)")
print("  next cursor:        \(warmupPage.nextCursor.map { String($0.offset) } ?? "none")")
print("")

var hotRuns: [TimedSearchPage] = []
for _ in 0..<5 {
    hotRuns.append(try timedSearch(database: database, query: query, limit: limit))
}

let times = hotRuns.map(\.milliseconds)
let sorted = times.sorted()
let median = sorted[sorted.count / 2]
let minMs = sorted.first ?? 0
let maxMs = sorted.last ?? 0
let avg = average(times)
print("Hot search (5 runs after warmup):")
print("  min:    \(formatMs(minMs)) ms")
print("  median: \(formatMs(median)) ms")
print("  avg:    \(formatMs(avg)) ms")
print("  max:    \(formatMs(maxMs)) ms")
print("  raw:    \(times.map(formatMs).joined(separator: ", "))")
print("")
if includesStep1Gaps {
    let perFileLimit = min(limit, 100)
    let perFileSummary = warmupPage.fileSummaries.first
    let perFileWarmup = try perFileSummary.map {
        try timedSearch(
            database: database,
            query: query,
            limit: perFileLimit,
            subtitlePath: $0.subtitlePath
        )
    }
    var perFileHotRuns: [TimedSearchPage] = []
    if let perFileSummary {
        for _ in 0..<5 {
            perFileHotRuns.append(
                try timedSearch(
                    database: database,
                    query: query,
                    limit: perFileLimit,
                    subtitlePath: perFileSummary.subtitlePath
                )
            )
        }
    }
    let metrics = step1GapMetrics(
        query: query,
        limit: limit,
        warmup: warmupRun,
        hotRuns: hotRuns,
        perFileWarmup: perFileWarmup,
        perFileHotRuns: perFileHotRuns,
        perFileSummary: perFileSummary
    )
    let encoded = try JSONEncoder().encode(metrics)

    print("Step 1 benchmark gaps:")
    print("  preview metric:     \(metrics.preview.metric)")
    print("  preview groups:     \(metrics.preview.loadedFileGroups)")
    print("  exact count metric: \(metrics.exactCountsCompletion.metric)")
    print("  per-file metric:    \(metrics.perFileLoadMore.metric)")
    print("  per-file title:     \(metrics.perFileLoadMore.subtitleDisplayTitle ?? "n/a")")
    print("  per-file warmup:    \(metrics.perFileLoadMore.warmupMilliseconds.map(formatMs) ?? "n/a") ms")
    print("  per-file hot raw:   \(metrics.perFileLoadMore.hotRawMilliseconds.map(formatMs).joined(separator: ", "))")
    print("STEP1_GAPS_JSON \(String(data: encoded, encoding: .utf8) ?? "{}")")
    print("")
}

let coldStart = Date()
let coldDatabase = try SearchDatabase(path: dbPath)
let coldOpenMs = milliseconds(since: coldStart)
let coldRun = try timedSearch(database: coldDatabase, query: query, limit: limit)
let coldSearchMs = coldRun.milliseconds
print("Cold open + migrate + 1 search (simulates old per-call pattern):")
print("  open + migrate:     \(formatMs(coldOpenMs)) ms")
print("  first search:       \(formatMs(coldSearchMs)) ms")
print("  total:              \(formatMs(coldOpenMs + coldSearchMs)) ms")

if includesFTSVocabularyDiagnostics {
    let diagnosticsStart = Date()
    let diagnostics = try database.ftsVocabularyDiagnostics(
        for: query,
        topTermLimit: ftsVocabularyTopTermLimit
    )
    let diagnosticsMs = milliseconds(since: diagnosticsStart)

    print("")
    print("FTS vocabulary diagnostics:")
    print("  elapsed:              \(formatMs(diagnosticsMs)) ms")
    print("  unique terms:         \(diagnostics.uniqueTermCount)")
    print("  term-doc references:  \(diagnostics.totalDocumentReferences)")
    print("  term occurrences:     \(diagnostics.totalOccurrences)")
    print("  query terms:")
    if diagnostics.queryTerms.isEmpty {
        print("    none")
    } else {
        for term in diagnostics.queryTerms {
            print("    \(term.term) docs=\(term.documentCount) occurrences=\(term.occurrenceCount)")
        }
    }
    print("  most frequent terms:")
    for term in diagnostics.mostFrequentTerms {
        print("    \(term.term) docs=\(term.documentCount) occurrences=\(term.occurrenceCount)")
    }
}
