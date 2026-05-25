import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case deepSeek = "deepseek"

    static let keychainService = "CueSeekerAI"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .deepSeek:
            return "DeepSeek"
        }
    }

    var keychainAccount: String {
        rawValue
    }
}
