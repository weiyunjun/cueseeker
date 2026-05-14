import Foundation
import CueSeekerCore

func milliseconds(since start: Date) -> Double {
    Date().timeIntervalSince(start) * 1000
}

func formatMs(_ value: Double) -> String {
    String(format: "%.2f", value)
}

guard CommandLine.arguments.count >= 3 else {
    print("Usage: SearchBench <db-path> <query> [limit]")
    exit(1)
}

let dbPath = URL(fileURLWithPath: CommandLine.arguments[1])
let query = CommandLine.arguments[2]
let limit = CommandLine.arguments.count >= 4 ? Int(CommandLine.arguments[3]) ?? 1000 : 1000
let diagnosticsEnabled = ProcessInfo.processInfo.environment["CUESEEKER_BENCH_DIAGNOSTICS"] == "1"
let metadataMode: SubtitleSearchMetadataMode =
    ProcessInfo.processInfo.environment["CUESEEKER_BENCH_METADATA"] == "deferred"
    ? .deferred
    : .complete

func diagnosticsSink(_ event: SubtitleSearchDiagnosticEvent) {
    let fields = event.fields
        .map { "\($0.name)=\($0.value)" }
        .joined(separator: " ")
    if fields.isEmpty {
        print("  diag \(event.name): \(formatMs(event.phaseMilliseconds)) ms")
    } else {
        print("  diag \(event.name): \(formatMs(event.phaseMilliseconds)) ms \(fields)")
    }
}

func searchPage() throws -> SubtitleSearchPage {
    try database.searchPage(
        query,
        limit: limit,
        metadataMode: metadataMode,
        diagnostics: diagnosticsEnabled ? diagnosticsSink : nil
    )
}

print("== SearchBench ==")
print("DB:    \(dbPath.path)")
print("Query: \"\(query)\"")
print("Limit: \(limit)")
print("Metadata mode: \(metadataMode == .deferred ? "deferred" : "complete")")
print("")

let openStart = Date()
let database = try SubtitleDatabase(path: dbPath)
let openMs = milliseconds(since: openStart)
print("Open connection:      \(formatMs(openMs)) ms")

let migrateStart = Date()
try database.migrate()
let migrateMs = milliseconds(since: migrateStart)
print("Migrate (one-time):   \(formatMs(migrateMs)) ms")
print("Schema version:       \(try database.schemaVersion())")
print("")

let warmupStart = Date()
let warmupPage = try searchPage()
let warmupMs = milliseconds(since: warmupStart)
print("Warmup search:        \(formatMs(warmupMs)) ms")
print("  results returned:   \(warmupPage.results.count)")
print("  total count:        \(warmupPage.totalCount)")
print("  file summaries:     \(warmupPage.fileSummaries.count)")
print("  has more results:   \(warmupPage.hasMoreResults)")
print("  metadata state:     \(warmupPage.metadataState.rawValue)")
print("")

var times: [Double] = []
for _ in 0..<5 {
    let start = Date()
    _ = try searchPage()
    times.append(milliseconds(since: start))
}

let sorted = times.sorted()
let median = sorted[sorted.count / 2]
let minMs = sorted.first ?? 0
let maxMs = sorted.last ?? 0
let avg = times.reduce(0, +) / Double(times.count)
print("Hot search (5 runs after warmup):")
print("  min:    \(formatMs(minMs)) ms")
print("  median: \(formatMs(median)) ms")
print("  avg:    \(formatMs(avg)) ms")
print("  max:    \(formatMs(maxMs)) ms")
print("  raw:    \(times.map(formatMs).joined(separator: ", "))")
print("")

let coldStart = Date()
let coldDatabase = try SubtitleDatabase(path: dbPath)
try coldDatabase.migrate()
let coldOpenMs = milliseconds(since: coldStart)
let coldSearchStart = Date()
_ = try coldDatabase.searchPage(
    query,
    limit: limit,
    metadataMode: metadataMode,
    diagnostics: diagnosticsEnabled ? diagnosticsSink : nil
)
let coldSearchMs = milliseconds(since: coldSearchStart)
print("Cold open + migrate + 1 search (simulates old per-call pattern):")
print("  open + migrate:     \(formatMs(coldOpenMs)) ms")
print("  first search:       \(formatMs(coldSearchMs)) ms")
print("  total:              \(formatMs(coldOpenMs + coldSearchMs)) ms")
