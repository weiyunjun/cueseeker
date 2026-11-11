import Foundation
import SwiftUI
import CueSeekerCore

@MainActor
enum WorkbenchPanelMode: String, CaseIterable {
    case excerpt
    case recentWatching
    case testLibrary
    case file
    case search

    var sidebarLabel: String {
        switch self {
        case .excerpt:
            return L("sidebar.excerpt")
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

    var icon: AppIcon {
        switch self {
        case .excerpt:
            return .bookmarkSimple
        case .recentWatching:
            return .clock
        case .testLibrary:
            // Library shows a grid of folder cards; the folder glyph belongs
            // to File, which owns the indexed root folders.
            return .squaresFour
        case .file:
            return .folder
        case .search:
            return .magnifyingGlass
        }
    }
}

/// The two Tabs of the Recent page.
enum WorkbenchRecentSection: String, CaseIterable {
    case videos
    case excerpts

    var label: String {
        switch self {
        case .videos:
            L("sidebar.recent_videos")
        case .excerpts:
            L("sidebar.recent_excerpts")
        }
    }

    var shortLabel: String {
        switch self {
        case .videos:
            L("recent.segment.videos")
        case .excerpts:
            L("recent.segment.excerpts")
        }
    }
}

/// Level 1 Workbench surfaces that freeze in place when the last folder is
/// removed until a refresh action or page/tab switch occurs.
enum WorkbenchNoFolderHoldSurface: Equatable {
    case search
    case recent(WorkbenchRecentSection)
    case libraryRoot
    case excerptOverview
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
    case fileFolder(rootPath: String)
    case fileFiles(rootPath: String, folderPath: String)
    case excerpt
    case excerptList(id: Int64)

    /// The first level of the section a Sidebar item opens.
    static func firstLevel(of mode: WorkbenchPanelMode) -> WorkbenchRoute {
        switch mode {
        case .search:
            .search
        case .recentWatching:
            .recent
        case .testLibrary:
            .library
        case .file:
            .file
        case .excerpt:
            .excerpt
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
        case .file, .fileFolder, .fileFiles:
            .file
        case .excerpt, .excerptList:
            .excerpt
        }
    }

    func rewritingFolderPaths(_ steps: [LibraryRenameStep]) -> WorkbenchRoute {
        switch self {
        case .libraryFolder(let folderPath):
            return .libraryFolder(
                folderPath: LibraryRenamer.rewrittenPath(folderPath, steps: steps)
            )
        case .fileFolder(let rootPath):
            return .fileFolder(
                rootPath: LibraryRenamer.rewrittenPath(rootPath, steps: steps)
            )
        case .fileFiles(let rootPath, let folderPath):
            return .fileFiles(
                rootPath: LibraryRenamer.rewrittenPath(rootPath, steps: steps),
                folderPath: LibraryRenamer.rewrittenPath(folderPath, steps: steps)
            )
        case .search, .recent, .library, .file, .excerpt, .excerptList:
            return self
        }
    }

    func diagnosticLabel(
        recentSection: WorkbenchRecentSection,
        fileSection: WorkbenchFileSection
    ) -> String {
        switch self {
        case .search:
            return "search"
        case .recent:
            return recentSection == .videos ? "recent_videos" : "recent_excerpts"
        case .library:
            return "library_overview"
        case .libraryFolder:
            return "library_directory"
        case .file:
            return "file_\(fileSection.rawValue)_roots"
        case .fileFolder:
            return "file_\(fileSection.rawValue)_subfolders"
        case .fileFiles:
            return "file_\(fileSection.rawValue)_files"
        case .excerpt:
            return "excerpt_overview"
        case .excerptList:
            return "excerpt_detail"
        }
    }
}

@MainActor
final class WorkbenchRouteState: ObservableObject {
    @Published fileprivate(set) var panelMode: WorkbenchPanelMode {
        didSet {
            if panelMode != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    @Published fileprivate(set) var isSearchFocused = false
    @Published fileprivate(set) var selectedLibraryFolderPath: String? {
        didSet {
            if selectedLibraryFolderPath != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    @Published fileprivate(set) var selectedExcerptListID: Int64? {
        didSet {
            if selectedExcerptListID != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    /// Kept while the reader is on other pages, for as long as the App runs.
    @Published fileprivate(set) var selectedRecentSection: WorkbenchRecentSection = .videos {
        didSet {
            if selectedRecentSection != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    /// Kept the same way as the Recent tab.
    @Published fileprivate(set) var selectedFileSection: WorkbenchFileSection = .index {
        didSet {
            if selectedFileSection != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    @Published fileprivate(set) var selectedFileRootPath: String? {
        didSet {
            if selectedFileRootPath != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    @Published fileprivate(set) var selectedFileFolderPath: String? {
        didSet {
            if selectedFileFolderPath != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    /// Browser-style history of the pages shown since launch. It lives only
    /// as long as the App runs; the launch page is its first entry.
    @Published fileprivate(set) var history: [WorkbenchRoute]
    @Published fileprivate(set) var historyIndex: Int
    /// Active 3-step File onboarding step (`1...3`) when the tutorial is open.
    @Published private(set) var activeFileOnboardingStep: Int?
    /// Armed on App launch when 0 folders exist and the user has never clicked
    /// `Done`. Entering `File` while still at 0 folders starts Step 1.
    @Published private(set) var isMandatoryFileOnboardingArmedForZeroFolders = false
    /// Holds a Level 1 Workbench surface after the last folder is removed so
    /// the active page stays frozen until a refresh action or page/tab switch.
    @Published private(set) var heldNoFolderSurface: WorkbenchNoFolderHoldSurface?
    var onHeldNoFolderSurfaceInvalidated: (() -> Void)?
    var onRecentSectionChanged: (() -> Void)?

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

    var displayedFileOnboardingStep: Int {
        activeFileOnboardingStep ?? 1
    }

    func isFileOnboardingPresented(hasIndexedFolders: Bool) -> Bool {
        if activeFileOnboardingStep != nil {
            return true
        }
        return isMandatoryFileOnboardingArmedForZeroFolders && !hasIndexedFolders
    }

    func configureInitialFileOnboarding(
        hasIndexedFolders: Bool,
        hasCompletedFileOnboarding: Bool
    ) {
        let shouldArm = !hasIndexedFolders && !hasCompletedFileOnboarding
        isMandatoryFileOnboardingArmedForZeroFolders = shouldArm
        if shouldArm && currentRoute == .file {
            activeFileOnboardingStep = 1
        } else {
            activeFileOnboardingStep = nil
        }
    }

    func lockMandatoryFileOnboardingIfNeeded(hasIndexedFolders: Bool) {
        guard activeFileOnboardingStep == nil else {
            return
        }
        if isMandatoryFileOnboardingArmedForZeroFolders && !hasIndexedFolders {
            activeFileOnboardingStep = 1
        } else if hasIndexedFolders {
            isMandatoryFileOnboardingArmedForZeroFolders = false
        }
    }

    func disarmMandatoryFileOnboarding() {
        if isMandatoryFileOnboardingArmedForZeroFolders {
            isMandatoryFileOnboardingArmedForZeroFolders = false
        }
    }

    func openFileOnboarding() {
        activeFileOnboardingStep = 1
    }

    func goBackFileOnboardingStep() {
        let current = activeFileOnboardingStep ?? 1
        activeFileOnboardingStep = max(1, current - 1)
    }

    func advanceFileOnboardingStep() {
        let current = activeFileOnboardingStep ?? 1
        activeFileOnboardingStep = min(3, current + 1)
    }

    func completeFileOnboarding() {
        isMandatoryFileOnboardingArmedForZeroFolders = false
        activeFileOnboardingStep = nil
    }

    func holdNoFolderSurface(_ surface: WorkbenchNoFolderHoldSurface?) {
        heldNoFolderSurface = surface
    }

    func clearHeldNoFolderSurface() {
        if heldNoFolderSurface != nil {
            heldNoFolderSurface = nil
        }
    }

    fileprivate func currentNoFolderHoldSurface(for route: WorkbenchRoute) -> WorkbenchNoFolderHoldSurface? {
        switch route {
        case .search:
            return .search
        case .recent:
            return .recent(selectedRecentSection)
        case .library:
            return .libraryRoot
        case .excerpt:
            return .excerptOverview
        case .libraryFolder, .file, .fileFolder, .fileFiles, .excerptList:
            return nil
        }
    }

    fileprivate func show(_ route: WorkbenchRoute) {
        let shouldInvalidateHeldSurface = heldNoFolderSurface != nil
            && heldNoFolderSurface != currentNoFolderHoldSurface(for: route)
        panelMode = route.panelMode
        if case .libraryFolder(let folderPath) = route {
            selectedLibraryFolderPath = folderPath
        } else {
            selectedLibraryFolderPath = nil
        }
        if case .excerptList(let id) = route {
            selectedExcerptListID = id
        } else {
            selectedExcerptListID = nil
        }
        switch route {
        case .file:
            selectedFileRootPath = nil
            selectedFileFolderPath = nil
        case .fileFolder(let rootPath):
            selectedFileRootPath = rootPath
            selectedFileFolderPath = nil
        case .fileFiles(let rootPath, let folderPath):
            selectedFileRootPath = rootPath
            selectedFileFolderPath = folderPath
        default:
            selectedFileRootPath = nil
            selectedFileFolderPath = nil
        }
        if shouldInvalidateHeldSurface {
            heldNoFolderSurface = nil
            onHeldNoFolderSurfaceInvalidated?()
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
        // A mode this build no longer has, such as the retired `library`,
        // opens on Search.
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

    var selectedExcerptListID: Int64? {
        route.selectedExcerptListID
    }

    var selectedRecentSection: WorkbenchRecentSection {
        route.selectedRecentSection
    }

    var selectedFileSection: WorkbenchFileSection {
        route.selectedFileSection
    }

    var selectedFileRootPath: String? {
        route.selectedFileRootPath
    }

    var selectedFileFolderPath: String? {
        route.selectedFileFolderPath
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

    func rewriteFolderPaths(_ steps: [LibraryRenameStep]) {
        guard !steps.isEmpty else {
            return
        }
        let rewrittenHistory = route.history.map { $0.rewritingFolderPaths(steps) }
        guard rewrittenHistory != route.history else {
            return
        }
        route.history = rewrittenHistory
        route.show(route.currentRoute)
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
    func collapseSidebarForCompactWindowIfNeeded(
        width: CGFloat,
        threshold: CGFloat = AppShellLayout.sidebarAutoCollapseWindowWidth
    ) -> Bool {
        guard width > 0, width < threshold, isSidebarVisible else {
            return false
        }

        setSidebarVisible(false)
        return true
    }

    func selectRecentSection(_ section: WorkbenchRecentSection) {
        let startedAt = DebugInteractionLatencyProbe.now()
        let previousSection = route.selectedRecentSection
        if previousSection != section {
            DebugInteractionLatencyProbe.beginNavigation(
                domain: "workbench",
                from: previousSection == .videos ? "recent_videos" : "recent_excerpts",
                to: section == .videos ? "recent_videos" : "recent_excerpts",
                trigger: "recent_tab_select",
                startedAt: startedAt
            )
        }
        route.selectedRecentSection = section
        if previousSection != section {
            if route.heldNoFolderSurface != nil {
                route.clearHeldNoFolderSurface()
                route.onHeldNoFolderSurfaceInvalidated?()
            }
            route.onRecentSectionChanged?()
            DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(domain: "workbench")
        }
    }

    func selectFileSection(_ section: WorkbenchFileSection) {
        let startedAt = DebugInteractionLatencyProbe.now()
        let previousSection = route.selectedFileSection
        let fromLabel = route.currentRoute.diagnosticLabel(
            recentSection: route.selectedRecentSection,
            fileSection: previousSection
        )
        route.selectedFileSection = section
        if previousSection != section {
            let toLabel = route.currentRoute.diagnosticLabel(
                recentSection: route.selectedRecentSection,
                fileSection: section
            )
            DebugInteractionLatencyProbe.completeImmediateNavigation(
                domain: "workbench",
                from: fromLabel,
                to: toLabel,
                trigger: "file_tab_select",
                startedAt: startedAt
            )
        }
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
