import Combine
import Foundation
import CueSeekerCore

@MainActor
final class IndexingStore: ObservableObject {
    private static let selectedFolderPathsKey = "selectedFolderPaths"

    @Published var selectedFolders: [URL]
    @Published var indexingStatus: IndexingStatus = .idle
    @Published var folderRemovalStatus: LibraryFolderRemovalStatus = .idle
    @Published var databaseStorageStats: DatabaseStorageStats?
    @Published var databaseMaintenanceStatus: DatabaseMaintenanceStatus = .idle
    @Published var searchFTSVocabularyDiagnostics: SubtitleFTSVocabularyDiagnostics?
    @Published var searchFTSVocabularyDiagnosticsStatus: SearchFTSVocabularyDiagnosticsStatus = .idle

    var searchFTSVocabularyDiagnosticsTask: Task<Void, Never>?

    private let userDefaults: UserDefaults
    private var settingsCancellables: Set<AnyCancellable> = []

    init(userDefaults: UserDefaults, settings: SettingsStore) {
        self.userDefaults = userDefaults
        self.selectedFolders = Self.loadSelectedFolders(from: userDefaults)

        settings.$searchFTSVocabularyDiagnosticsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled {
                    self.searchFTSVocabularyDiagnosticsTask?.cancel()
                    self.searchFTSVocabularyDiagnosticsTask = nil
                    self.searchFTSVocabularyDiagnosticsStatus = .idle
                }
            }
            .store(in: &settingsCancellables)
    }

    func appendFolder(_ folder: URL) {
        selectedFolders.append(folder)
        persistSelectedFolders()
    }

    func removeFolder(_ folder: URL) {
        selectedFolders.removeAll { $0 == folder }
        persistSelectedFolders()
    }

    var isLibraryFolderOperationActive: Bool {
        indexingStatus.isIndexing
            || folderRemovalStatus.isRemoving
            || databaseMaintenanceStatus.isCompacting
    }

    private func persistSelectedFolders() {
        userDefaults.set(
            selectedFolders.map(\.path),
            forKey: Self.selectedFolderPathsKey
        )
    }

    private static func loadSelectedFolders(from userDefaults: UserDefaults) -> [URL] {
        userDefaults
            .stringArray(forKey: selectedFolderPathsKey)?
            .map { URL(fileURLWithPath: $0).standardizedFileURL } ?? []
    }
}
