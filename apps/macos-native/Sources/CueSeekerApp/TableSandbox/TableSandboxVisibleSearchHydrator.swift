import Foundation
import CueSeekerCore

struct TableSandboxSearchHydrationPage: Equatable, Sendable {
    let range: Range<Int>
    let results: [SubtitleSearchResult]
    let totalRowCount: Int
}

struct TableSandboxShioriHydrationPage: Equatable, Sendable {
    let range: Range<Int>
    let rows: [TableSandboxShioriRowSource]
    let totalRowCount: Int
    let totalSavedRowCount: Int
}

enum TableSandboxHydrationPaging {
    static let pageSize = 50
}
