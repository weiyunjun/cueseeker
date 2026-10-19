import Combine
import Foundation
import CueSeekerCore

enum DatabaseOperationNotice: Equatable {
    case indexed(folderName: String)
    case indexedAll
    case removed(folderName: String)
    case indexFailed(folderName: String)
    case removalFailed(folderName: String)
}

@MainActor
final class IndexingStore: ObservableObject {
    private static let selectedFolderPathsKey = "selectedFolderPaths"
    private static let lastUpdatedTimestampKey = "lastUpdatedTimestamp"
    private static let legacyLastIndexedTimestampKey = "lastIndexedTimestamp"

    nonisolated static func displayName(for folder: URL) -> String {
        if folder.isWebDAVURL {
            if let config = WebDAVConfigurationStore.shared.config(for: folder) {
                let trimmed = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            return WebDAVAddress.defaultDisplayName(for: folder)
        }
        if folder.isSMBURL {
            if let config = SMBConfigurationStore.shared.config(for: folder) {
                let trimmed = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            return SMBAddress.defaultDisplayName(for: folder)
        }
        return folder.lastPathComponent
    }

    @Published var selectedFolders: [URL]
    @Published var indexingStatus: IndexingStatus = .idle {
        didSet {
            switch indexingStatus {
            case .completed(let folder, _):
                recordLastUpdatedDate(Date())
                operationNotice = .indexed(folderName: Self.displayName(for: folder))
            case .completedAll:
                recordLastUpdatedDate(Date())
                operationNotice = .indexedAll
            case .failed(let folder, _):
                operationNotice = .indexFailed(folderName: Self.displayName(for: folder))
            default:
                break
            }
        }
    }
    @Published var lastUpdatedDate: Date?
    var lastIndexedDate: Date? {
        lastUpdatedDate
    }
    @Published var operationNotice: DatabaseOperationNotice?
    @Published var auxiliaryFailures: [IndexingAuxiliaryFailure] = []
    @Published var folderRemovalStatus: LibraryFolderRemovalStatus = .idle
    @Published var removedFolderNotice: URL? {
        didSet {
            if let folder = removedFolderNotice {
                recordLastUpdatedDate(Date())
                operationNotice = .removed(folderName: Self.displayName(for: folder))
            }
        }
    }
    @Published var databaseStorageStats: DatabaseStorageStats?
    @Published var databaseMaintenanceStatus: DatabaseMaintenanceStatus = .idle
    @Published var searchFTSVocabularyDiagnostics: SubtitleFTSVocabularyDiagnostics?
    @Published var searchFTSVocabularyDiagnosticsStatus: SearchFTSVocabularyDiagnosticsStatus = .idle

    var isDatabaseOperationActive: Bool {
        indexingStatus.isIndexing || folderRemovalStatus.isRemoving
    }

    var searchFTSVocabularyDiagnosticsTask: Task<Void, Never>?

    private let userDefaults: UserDefaults
    private var settingsCancellables: Set<AnyCancellable> = []

    init(userDefaults: UserDefaults, settings: SettingsStore) {
        self.userDefaults = userDefaults
        self.selectedFolders = Self.loadSelectedFolders(from: userDefaults)
        let timestamp = userDefaults.double(forKey: Self.lastUpdatedTimestampKey)
        if timestamp > 0 {
            self.lastUpdatedDate = Date(timeIntervalSince1970: timestamp)
        } else {
            let legacyTimestamp = userDefaults.double(forKey: Self.legacyLastIndexedTimestampKey)
            self.lastUpdatedDate = legacyTimestamp > 0 ? Date(timeIntervalSince1970: legacyTimestamp) : nil
        }

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

    func recordLastUpdatedDate(_ date: Date) {
        lastUpdatedDate = date
        userDefaults.set(date.timeIntervalSince1970, forKey: Self.lastUpdatedTimestampKey)
        userDefaults.set(date.timeIntervalSince1970, forKey: Self.legacyLastIndexedTimestampKey)
    }

    func recordLastIndexedDate(_ date: Date) {
        recordLastUpdatedDate(date)
    }

    func clearTransientNotice() {
        operationNotice = nil
        removedFolderNotice = nil
    }

    func appendFolder(_ folder: URL) {
        selectedFolders.append(folder)
        persistSelectedFolders()
    }

    func removeFolder(_ folder: URL) {
        selectedFolders.removeAll { $0 == folder }
        persistSelectedFolders()
    }

    /// A root that was renamed in the App, or sits inside a folder that was,
    /// keeps its place in the list under its new path.
    func replaceFolderPathPrefix(_ oldPath: String, with newPath: String) {
        selectedFolders = selectedFolders.map { folder in
            if let rewritten = LibraryRenamer.rewrite(folder.mediaPath, from: oldPath, to: newPath) {
                return URL.fromMediaPath(rewritten)
            }
            return folder
        }
        persistSelectedFolders()
    }

    private func persistSelectedFolders() {
        userDefaults.set(
            selectedFolders.map(\.mediaPath),
            forKey: Self.selectedFolderPathsKey
        )
    }

    private static func loadSelectedFolders(from userDefaults: UserDefaults) -> [URL] {
        userDefaults
            .stringArray(forKey: selectedFolderPathsKey)?
            .map { URL.fromMediaPath($0) } ?? []
    }
}
