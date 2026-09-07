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

/// The two Tabs of the File page.
enum WorkbenchFileSection: String, CaseIterable {
    case index
    case edit

    var label: String {
        switch self {
        case .index:
            L("file.section.index")
        case .edit:
            L("file.section.edit")
        }
    }
}

/// One Workbench page, the way the history remembers it. The Recent and File
/// tabs, the Video / Metadata segments and the search text are not part of
/// the page.
@MainActor
enum WorkbenchRoute: Equatable {
    case search
    case recent
    case library
    case libraryFolder(folderPath: String)
    case file
    case shiori
    case shioriList(id: Int64)

    /// The first level of the section a Sidebar item opens. The retired
    /// `library` mode lands on Search, as it did when it was migrated.
    static func firstLevel(of mode: WorkbenchPanelMode) -> WorkbenchRoute {
        switch mode {
        case .search, .library:
            .search
        case .recentWatching:
            .recent
        case .testLibrary:
            .library
        case .file:
            .file
        case .shiori:
            .shiori
        }
    }

    var panelMode: WorkbenchPanelMode {
        switch self {
        case .search:
            .search
        case .recent:
            .recentWatching
        case .library, .libraryFolder:
            .testLibrary
        case .file:
            .file
        case .shiori, .shioriList:
            .shiori
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
    @Published fileprivate(set) var selectedLibraryFolderPath: String? {
        didSet {
            if selectedLibraryFolderPath != oldValue {
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
    /// Kept the same way as the Recent tab.
    @Published fileprivate(set) var selectedFileSection: WorkbenchFileSection = .index {
        didSet {
            if selectedFileSection != oldValue {
                AppPointerShape.reset()
            }
        }
    }
    /// Browser-style history of the pages shown since launch. It lives only
    /// as long as the App runs; the launch page is its first entry.
    @Published fileprivate(set) var history: [WorkbenchRoute]
    @Published fileprivate(set) var historyIndex: Int

    init(panelMode: WorkbenchPanelMode) {
        let route = WorkbenchRoute.firstLevel(of: panelMode)
        self.panelMode = route.panelMode
        history = [route]
        historyIndex = 0
    }

    var currentRoute: WorkbenchRoute {
        history[historyIndex]
    }

    var canGoBack: Bool {
        historyIndex > 0
    }

    var canGoForward: Bool {
        historyIndex < history.count - 1
    }

    fileprivate func show(_ route: WorkbenchRoute) {
        panelMode = route.panelMode
        if case .libraryFolder(let folderPath) = route {
            selectedLibraryFolderPath = folderPath
        } else {
            selectedLibraryFolderPath = nil
        }
        if case .shioriList(let id) = route {
            selectedShioriListID = id
        } else {
            selectedShioriListID = nil
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
    /// Whether the Settings window is open, so the topbar's Settings button can
    /// stay lit for as long as it is. It follows the window's open and closed
    /// edges, not its visibility, so minimising to the Dock keeps the button lit.
    @Published var isSettingsWindowOpen = false
    let route: WorkbenchRouteState

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        let savedMode = WorkbenchPanelMode(
            rawValue: userDefaults.string(forKey: Self.panelModeKey) ?? ""
        ) ?? .search
        route = WorkbenchRouteState(panelMode: savedMode)
        isSidebarVisible = userDefaults.object(forKey: Self.isSidebarVisibleKey) as? Bool ?? true
    }

    var panelMode: WorkbenchPanelMode {
        route.panelMode
    }

    var currentRoute: WorkbenchRoute {
        route.currentRoute
    }

    var isSearchFocused: Bool {
        get { route.isSearchFocused }
        set { route.isSearchFocused = newValue }
    }

    var selectedLibraryFolderPath: String? {
        route.selectedLibraryFolderPath
    }

    var selectedShioriListID: Int64? {
        route.selectedShioriListID
    }

    var selectedRecentSection: WorkbenchRecentSection {
        route.selectedRecentSection
    }

    var selectedFileSection: WorkbenchFileSection {
        route.selectedFileSection
    }

    /// Shows a page as one new step of the history, dropping whatever could
    /// have been reached with Forward. Showing the page already shown is not
    /// a step.
    func navigate(to target: WorkbenchRoute) {
        guard route.currentRoute != target else {
            return
        }

        route.show(target)
        route.history.removeSubrange((route.historyIndex + 1)...)
        route.history.append(target)
        route.historyIndex += 1
        userDefaults.set(target.panelMode.rawValue, forKey: Self.panelModeKey)
    }

    func goBack() {
        guard route.canGoBack else {
            return
        }

        route.historyIndex -= 1
        showCurrentHistoryEntry()
    }

    func goForward() {
        guard route.canGoForward else {
            return
        }

        route.historyIndex += 1
        showCurrentHistoryEntry()
    }

    private func showCurrentHistoryEntry() {
        let target = route.currentRoute
        route.show(target)
        userDefaults.set(target.panelMode.rawValue, forKey: Self.panelModeKey)
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

    func selectRecentSection(_ section: WorkbenchRecentSection) {
        route.selectedRecentSection = section
    }

    func selectFileSection(_ section: WorkbenchFileSection) {
        route.selectedFileSection = section
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
