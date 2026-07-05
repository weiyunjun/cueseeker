import Foundation
import SwiftUI
import CueSeekerCore

@MainActor
enum WorkbenchPanelMode: String, CaseIterable {
    case library
    case shiori
    case recentWatching
    case testLibrary
    case search

    static let sidebarCases: [WorkbenchPanelMode] = [
        .search,
        .recentWatching,
        .testLibrary,
        .shiori,
    ]

    var sidebarLabel: String {
        switch self {
        case .library:
            return "Library"
        case .shiori:
            return "Shiori"
        case .recentWatching:
            return "Recent"
        case .testLibrary:
            return "Library"
        case .search:
            return "Search"
        }
    }

    var title: String {
        switch self {
        case .library:
            return "Library"
        case .shiori:
            return "Shiori"
        case .recentWatching:
            return "Recent"
        case .testLibrary:
            return "Library"
        case .search:
            return "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .library:
            return "folder"
        case .shiori:
            return "bookmark"
        case .recentWatching:
            return "clock"
        case .testLibrary:
            return "folder"
        case .search:
            return "magnifyingglass"
        }
    }
}

@MainActor
final class WorkbenchLayoutState: ObservableObject {
    private static let panelModeKey = "workbenchPanelMode"
    private static let isSidebarVisibleKey = "workbenchSidebarVisible"

    @Published var panelMode: WorkbenchPanelMode
    @Published var isSidebarVisible: Bool
    @Published fileprivate(set) var isVideoSizeTransitionInProgress = false
    @Published var isAppFullscreen = false
    @Published var isSearchFocused = false
    @Published var selectedTestLibraryFolder: CompleteLibraryFolderSummaryPresentation?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        let savedMode = WorkbenchPanelMode(
            rawValue: userDefaults.string(forKey: Self.panelModeKey) ?? ""
        ) ?? .search
        panelMode = savedMode == .library ? .search : savedMode
        isSidebarVisible = userDefaults.object(forKey: Self.isSidebarVisibleKey) as? Bool ?? true
    }

    func selectPanelMode(_ mode: WorkbenchPanelMode) {
        guard panelMode != mode else {
            return
        }

        panelMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.panelModeKey)
    }

    func toggleSidebarVisibility() {
        isSidebarVisible.toggle()
        userDefaults.set(isSidebarVisible, forKey: Self.isSidebarVisibleKey)
    }

    func setSidebarVisible(_ isVisible: Bool) {
        guard isSidebarVisible != isVisible else {
            return
        }

        isSidebarVisible = isVisible
        userDefaults.set(isVisible, forKey: Self.isSidebarVisibleKey)
    }

    @discardableResult
    func collapseSidebarForCompactWindowIfNeeded(width: CGFloat, threshold: CGFloat) -> Bool {
        guard width > 0, width <= threshold, isSidebarVisible else {
            return false
        }

        setSidebarVisible(false)
        return true
    }

    func selectTestLibraryFolder(_ folder: CompleteLibraryFolderSummaryPresentation) {
        selectedTestLibraryFolder = folder
    }

    func clearTestLibraryFolder() {
        selectedTestLibraryFolder = nil
    }

    func beginVideoSizeTransition() -> Bool {
        guard !isVideoSizeTransitionInProgress else {
            return false
        }

        isVideoSizeTransitionInProgress = true
        return true
    }

    func endVideoSizeTransition() {
        isVideoSizeTransitionInProgress = false
    }

    func clearSearchFocus() {
        guard isSearchFocused else {
            return
        }

        AppPerformanceProbe.measure("WorkbenchLayoutState.clearSearchFocus", thresholdMilliseconds: 4) {
            isSearchFocused = false
        }
    }
}
