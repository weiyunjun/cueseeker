import Foundation
import CueSeekerCore

@MainActor
final class ShioriStore: ObservableObject {
    @Published var collapsedShioriGroupPaths: Set<String> = []
    @Published var shioris: [Shiori] = []
    @Published var shioriFileGroups: [ShioriFileGroup] = []
    @Published var selectedShiori: Shiori?

    var hasShioriFileGroups: Bool {
        !shioriFileGroups.isEmpty
    }

    var shioriCount: Int {
        shioris.count
    }

    var shioriFileCount: Int {
        shioriFileGroups.count
    }
}
