import Foundation

struct TableSandboxCellInvalidation: Equatable {
    let row: Int
    let columnID: String
}

enum TableSandboxRowsUpdate: Equatable {
    case none
    case append(Range<Int>)
    case cells([TableSandboxCellInvalidation])
    case reload

    var reason: String {
        switch self {
        case .none:
            return "none"
        case .append:
            return "append"
        case .cells:
            return "cells"
        case .reload:
            return "reload"
        }
    }
}
