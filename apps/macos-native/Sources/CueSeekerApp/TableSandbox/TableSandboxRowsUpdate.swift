import Foundation

enum TableSandboxRowsUpdate: Equatable {
    case none
    case append(Range<Int>)
    case reload

    var reason: String {
        switch self {
        case .none:
            return "none"
        case .append:
            return "append"
        case .reload:
            return "reload"
        }
    }
}
