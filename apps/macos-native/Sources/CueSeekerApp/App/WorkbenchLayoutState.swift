import Foundation
import SwiftUI
import CueSeekerCore

@MainActor
enum WorkbenchPanelMode: String, CaseIterable {
    case library
    case shiori
    case recentWatching
    case testLibrary
    case file
    case search

    var sidebarLabel: String {
        switch self {
        case .library:
            return L("sidebar.library")
        case .shiori:
            return L("sidebar.shiori")
        case .recentWatching:
            return L("sidebar.recent")
        case .testLibrary:
            return L("sidebar.library")
        case .file:
            return L("sidebar.file")
        case .search:
            return L("sidebar.search")
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
            // Library shows a grid of folder cards; the folder glyph belongs
            // to File, which owns the indexed root folders.
            return "square.grid.2x2"
        case .file:
            return "folder"
        case .search:
            return "magnifyingglass"
        }
    }
}

/// The two Tabs of the Recent page.
enum WorkbenchRecentSection: String, CaseIterable {
    case videos
    case shioris

    var label: String {
        switch self {
        case .videos:
            L("sidebar.recent_videos")
        case .shioris:
            L("sidebar.recent_shioris")
        }
    }
}

@MainActor
final class WorkbenchRouteState: ObservableObject {
    // Each of these is an interface switch: the pointer goes back to the
    // arrow until it moves again.
    @Published fileprivate(set) var panelMode: WorkbenchPanelMode {
        didSet {
            if panelMode != oldValue {
                AppPointerShape.reset()
            }
        }
    }
    @Published fileprivate(set) var isSearchFocused = false
    @Published fileprivate(set) var selectedTestLibraryFolder: CompleteLibraryFolderSummaryPresentation? {
        didSet {
            if selectedTestLibraryFolder?.id != oldValue?.id {
                AppPointerShape.reset()
            }
        }
    }
    @Published fileprivate(set) var selectedShioriListID: Int64? {
        didSet {
            if selectedShioriListID != oldValue {
                AppPointerShape.reset()
            }
        }
    }
    /// Kept while the reader is on other pages, for as long as the App runs.
    @Published fileprivate(set) var selectedRecentSection: WorkbenchRecentSection = .videos {
        didSet {
            if selectedRecentSection != oldValue {
                AppPointerShape.reset()
            }
        }
    }

    init(panelMode: WorkbenchPanelMode) {
        self.panelMode = panelMode
    }

    var canNavigateBack: Bool {
        switch panelMode {
        case .testLibrary:
            selectedTestLibraryFolder != nil
        case .shiori:
            selectedShioriListID != nil
        case .recentWatching, .library, .file, .search:
            false
        }
    }
}

@MainActor
final class WorkbenchLayoutState: ObservableObject {
    private static let panelModeKey = "workbenchPanelMode"
    private static let isSidebarVisibleKey = "workbenchSidebarVisible"

    @Published var isSidebarVisible: Bool
    @Published fileprivate(set) var isVideoSizeTransitionInProgress = false
    @Published var isAppFullscreen = false
    let route: WorkbenchRouteState

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        let savedMode = WorkbenchPanelMode(
            rawValue: userDefaults.string(forKey: Self.panelModeKey) ?? ""
        ) ?? .search
        route = WorkbenchRouteState(panelMode: savedMode == .library ? .search : savedMode)
        isSidebarVisible = userDefaults.object(forKey: Self.isSidebarVisibleKey) as? Bool ?? true
    }

    var panelMode: WorkbenchPanelMode {
        route.panelMode
    }

    var isSearchFocused: Bool {
        get { route.isSearchFocused }
        set { route.isSearchFocused = newValue }
    }

    var selectedTestLibraryFolder: CompleteLibraryFolderSummaryPresentation? {
        get { route.selectedTestLibraryFolder }
        set { route.selectedTestLibraryFolder = newValue }
    }

    var selectedShioriListID: Int64? {
        route.selectedShioriListID
    }

    var selectedRecentSection: WorkbenchRecentSection {
        route.selectedRecentSection
    }

    func selectPanelMode(_ mode: WorkbenchPanelMode) {
        guard route.panelMode != mode else {
            return
        }

        route.panelMode = mode
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
        route.selectedTestLibraryFolder = folder
    }

    func clearTestLibraryFolder() {
        route.selectedTestLibraryFolder = nil
    }

    func selectShioriList(id: Int64) {
        route.selectedShioriListID = id
    }

    func clearShioriList() {
        route.selectedShioriListID = nil
    }

    func selectRecentSection(_ section: WorkbenchRecentSection) {
        route.selectedRecentSection = section
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
        guard route.isSearchFocused else {
            return
        }

        AppPerformanceProbe.measure("WorkbenchLayoutState.clearSearchFocus", thresholdMilliseconds: 4) {
            route.isSearchFocused = false
        }
    }
}
