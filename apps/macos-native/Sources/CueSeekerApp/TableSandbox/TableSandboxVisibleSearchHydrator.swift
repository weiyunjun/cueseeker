import Foundation
import CueSeekerCore

struct TableSandboxSearchHydrationPage: Equatable, Sendable {
    let range: Range<Int>
    let results: [SubtitleSearchResult]
    let totalRowCount: Int
}

enum TableSandboxHydrationPaging {
    static let pageSize = 50
}
