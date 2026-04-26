import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search:
            "Search"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .search:
            "magnifyingglass"
        case .settings:
            "gearshape"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: AppSection = .search
    @Published var selectedFolders: [URL] = []

    func addFolder(_ folder: URL) {
        guard !selectedFolders.contains(folder) else {
            return
        }

        selectedFolders.append(folder)
    }

    func removeFolders(at offsets: IndexSet) {
        selectedFolders.remove(atOffsets: offsets)
    }
}

