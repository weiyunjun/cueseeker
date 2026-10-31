import AppKit
import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    func currentWorkbenchAccessibilityTargets() -> [WorkbenchAccessibilityTarget] {
        var targets: [WorkbenchAccessibilityTarget] = []

        // 1. Topbar (L-01.2)
        if !workbenchLayout.isVideoSizeTransitionInProgress {
            targets.append(.topbarSidebarToggle)
            targets.append(.topbarBackButton)
            targets.append(.topbarForwardButton)
        }
        if workbenchLayout.currentRoute == .recent {
            for section in WorkbenchRecentSection.allCases {
                targets.append(.topbarRecentSegment(section))
            }
        }
        targets.append(.topbarTaskButton)
        targets.append(.topbarSettingsButton)

        // 2. Sidebar (L-01.1, only when expanded)
        if workbenchLayout.isSidebarVisible && !workbenchLayout.isVideoSizeTransitionInProgress {
            targets.append(.sidebarItem(.search))
            targets.append(.sidebarItem(.recentWatching))
            targets.append(.sidebarItem(.testLibrary))
            targets.append(.sidebarItem(.file))
            targets.append(.sidebarItem(.excerpt))
        }

        // 3. Page Content (L-01.3)
        switch workbenchLayout.currentRoute {
        case .recent:
            appendRecentAccessibilityTargets(to: &targets)
        case .library:
            appendLibraryOverviewAccessibilityTargets(to: &targets)
        case .libraryFolder(let folderPath):
            appendLibraryFolderDetailAccessibilityTargets(folderPath: folderPath, to: &targets)
        case .file:
            appendFileRootAccessibilityTargets(to: &targets)
        case .fileFolder(let rootPath):
            appendFileSubfolderAccessibilityTargets(rootPath: rootPath, to: &targets)
        case .fileFiles(let rootPath, let folderPath):
            appendFileFilesAccessibilityTargets(rootPath: rootPath, folderPath: folderPath, to: &targets)
        case .excerpt:
            appendExcerptOverviewAccessibilityTargets(to: &targets)
        case .excerptList(let listID):
            appendExcerptDetailAccessibilityTargets(listID: listID, to: &targets)
        case .search:
            appendSearchAccessibilityTargets(to: &targets)
        }

        return targets
    }

    private func appendRecentAccessibilityTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        switch workbenchLayout.route.selectedRecentSection {
        case .videos:
            if case .loading = library.testRecentWatchingStatus, library.testRecentWatchingItems.isEmpty {
                return
            }
            if case .failed = library.testRecentWatchingStatus {
                return
            }
            let sections = RecentTimeSection.group(
                library.testRecentWatchingItems,
                timestamp: \.updatedAt
            )
            for entry in sections {
                for item in entry.items {
                    targets.append(.mediaCard(item.id))
                }
            }
        case .excerpts:
            if !excerpt.hasLoadedListOverview && excerpt.recentListSummaries.isEmpty {
                return
            }
            let sections = RecentTimeSection.group(
                excerpt.recentListSummaries,
                timestamp: \.list.recentPlayedAt
            )
            for group in sections {
                for summary in group.items {
                    let cardID = String(summary.id)
                    targets.append(.mediaCard(cardID))
                    targets.append(.mediaCardActionButton(cardID))
                }
            }
        }
    }

    private func appendLibraryOverviewAccessibilityTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        if case .loading = library.completeLibraryStatus, library.completeLibraryFolderSummaries.isEmpty {
            return
        }
        if case .failed = library.completeLibraryStatus {
            return
        }
        guard !library.completeLibraryFolderSummaries.isEmpty else {
            return
        }
        targets.append(.toolbarSearchField)
        if !library.overviewSearchDraft.isEmpty {
            targets.append(.toolbarSearchClearButton)
        }
        targets.append(.toolbarSortButton)

        for folder in library.displayedCompleteLibraryFolderSummaries where folder.episodeCount > 0 {
            targets.append(.mediaCard(folder.id))
            targets.append(.mediaCardActionButton(folder.id))
        }
    }

    private func appendLibraryFolderDetailAccessibilityTargets(
        folderPath: String,
        to targets: inout [WorkbenchAccessibilityTarget]
    ) {
        guard !isWorkbenchRouteUnknown(.libraryFolder(folderPath: folderPath)),
              let selectedFolder = library.completeLibraryFolderSummaries.first(where: { $0.folderPath == folderPath })
        else {
            return
        }
        let status = library.completeLibraryFolderDetailStatusesByPath[selectedFolder.folderPath] ?? .idle
        let detail = library.completeLibraryFolderDetailsByPath[selectedFolder.folderPath]
        if case .loading = status, detail?.folderPath != selectedFolder.folderPath {
            return
        }
        if case .failed = status {
            return
        }
        guard let detail, detail.folderPath == selectedFolder.folderPath else {
            return
        }

        targets.append(.coverSummaryPrimaryButton)
        targets.append(.coverSummaryEditCoverButton)
        targets.append(.coverSummaryMoreButton)

        for video in detail.videos {
            targets.append(.mediaCard(video.id))
        }
    }

    private var isFileFolderOperationBlocked: Bool {
        tasks.hasLibraryTask || indexing.databaseMaintenanceStatus.isCompacting
    }

    private var isFileStatusIndicatorClickable: Bool {
        let info = FileStatusResolver.resolve(
            indexingStatus: indexing.indexingStatus,
            folderRemovalStatus: indexing.folderRemovalStatus,
            operationNotice: indexing.operationNotice,
            lastUpdatedDate: indexing.lastUpdatedDate
        )
        if case .idle = info, indexing.lastUpdatedDate == nil {
            return false
        }
        return true
    }

    private func appendFileTopBarAndBreadcrumbTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        targets.append(.fileAddFolderButton)
        targets.append(.fileIndexNowButton)
        targets.append(.fileStatusIndicatorText)

        let nodes = FileBreadcrumbResolver.nodes(
            for: workbenchLayout.currentRoute,
            folderCount: indexing.selectedFolders.count,
            singularRootTitle: L("file.all_folders.one"),
            pluralRootTitle: L("file.all_folders.other")
        )
        for node in nodes where node.destination != nil {
            targets.append(.fileBreadcrumb(node.id))
        }
    }

    private func appendFileRootAccessibilityTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        appendFileTopBarAndBreadcrumbTargets(to: &targets)
        let folders = FileFolderGroupingResolver.rootFolders(for: indexing.selectedFolders)
        for folder in folders {
            let rootPath = folder.mediaPath
            targets.append(.fileCard(rootPath))
            targets.append(.fileCardActionButton(rootPath))
        }
    }

    private func appendFileSubfolderAccessibilityTargets(
        rootPath: String,
        to targets: inout [WorkbenchAccessibilityTarget]
    ) {
        appendFileTopBarAndBreadcrumbTargets(to: &targets)
        guard !isWorkbenchRouteUnknown(.fileFolder(rootPath: rootPath)) else {
            return
        }
        let partition = FileFolderGroupingResolver.level2Partition(
            folders: library.fileSubfolders(for: rootPath),
            objects: library.fileObjects(for: rootPath),
            rootPath: rootPath
        )
        for folder in partition.subfolders {
            targets.append(.fileCard(folder.folderPath))
            targets.append(.fileCardActionButton(folder.folderPath))
        }
        for object in partition.directEpisodeGroups {
            if !object.videoPath.isEmpty {
                targets.append(.fileRowActionButton(object.videoPath))
            }
            for subtitle in object.subtitles {
                targets.append(.fileRowActionButton(subtitle.path))
            }
        }
    }

    private func appendFileFilesAccessibilityTargets(
        rootPath: String,
        folderPath: String,
        to targets: inout [WorkbenchAccessibilityTarget]
    ) {
        appendFileTopBarAndBreadcrumbTargets(to: &targets)
        guard !isWorkbenchRouteUnknown(.fileFiles(rootPath: rootPath, folderPath: folderPath)) else {
            return
        }
        let episodeGroups = FileFolderGroupingResolver.displayableEpisodeGroups(
            from: library.fileObjects(for: folderPath)
        )
        for object in episodeGroups {
            if !object.videoPath.isEmpty {
                targets.append(.fileRowActionButton(object.videoPath))
            }
            for subtitle in object.subtitles {
                targets.append(.fileRowActionButton(subtitle.path))
            }
        }
    }

    private func appendExcerptOverviewAccessibilityTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        targets.append(.toolbarSearchField)
        if !excerpt.overviewSearchDraft.isEmpty {
            targets.append(.toolbarSearchClearButton)
        }
        targets.append(.toolbarSortButton)
        targets.append(.excerptNewListButton)

        guard excerpt.hasLoadedListOverview else {
            return
        }
        for summary in excerpt.displayedListSummaries {
            let cardID = String(summary.id)
            targets.append(.mediaCard(cardID))
            targets.append(.mediaCardActionButton(cardID))
        }
    }

    private func appendSchemaToolbarAndTableTargets(
        searchDraft: String,
        to targets: inout [WorkbenchAccessibilityTarget]
    ) {
        if workbenchAccessibility.isTableInSelectionMode {
            targets.append(.toolbarExitSelectButton)
            targets.append(.toolbarSelectionAction(.exportToAnki))
            targets.append(.toolbarSelectionAction(.copyDeepLinks))
            targets.append(.toolbarSelectionAction(.copyTable))
        } else {
            targets.append(.toolbarSearchField)
            if !searchDraft.isEmpty {
                targets.append(.toolbarSearchClearButton)
            }
            targets.append(.toolbarFilterButton)
            targets.append(.toolbarSortButton)
        }
        if let overrideTargets = workbenchAccessibility.tableTargetsOverrideForTesting {
            targets.append(contentsOf: overrideTargets())
        } else if let tableCoordinator = workbenchAccessibility.activeSubtitleTableCoordinator {
            targets.append(contentsOf: tableCoordinator.accessibilityTargets())
        }
    }

    private func appendExcerptDetailAccessibilityTargets(
        listID: Int64,
        to targets: inout [WorkbenchAccessibilityTarget]
    ) {
        guard !isWorkbenchRouteUnknown(.excerptList(id: listID)) else {
            return
        }
        if excerpt.activeListSummary != nil {
            targets.append(.coverSummaryPrimaryButton)
            targets.append(.coverSummaryMoreButton)
        }
        appendSchemaToolbarAndTableTargets(
            searchDraft: excerpt.tableSearchDraft,
            to: &targets
        )
    }

    private func appendSearchAccessibilityTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        appendSchemaToolbarAndTableTargets(
            searchDraft: search.searchQuery,
            to: &targets
        )
    }

    // MARK: - Reconcile & Navigation

    func reconcileWorkbenchAccessibilityFocus() {
        if isPlaybackPageVisible
            || playbackFullscreenManager.isFullscreen
            || interfaceLayers.isCovered(.workbenchPage)
            || interfaceLayers.isFrozen(.workbenchPage)
        {
            workbenchAccessibility.clear()
            return
        }
        guard let focused = workbenchAccessibility.focusedTarget else {
            return
        }
        let targets = currentWorkbenchAccessibilityTargets()
        if !targets.contains(focused) {
            workbenchAccessibility.clear()
        }
    }

    @discardableResult
    func moveWorkbenchAccessibilityFocus(forward: Bool) -> Bool {
        let targets = currentWorkbenchAccessibilityTargets()
        guard !targets.isEmpty else {
            workbenchAccessibility.clear()
            return true
        }

        if let current = workbenchAccessibility.focusedTarget,
           let index = targets.firstIndex(of: current)
        {
            let nextIndex = forward
                ? (index + 1) % targets.count
                : (index - 1 + targets.count) % targets.count
            workbenchAccessibility.setFocus(targets[nextIndex])
        } else {
            workbenchAccessibility.setFocus(forward ? targets.first : targets.last)
        }
        return true
    }

    @discardableResult
    func moveWorkbenchCardSelection(_ direction: PlaybackMediaSelectionDirection) -> Bool {
        guard let focused = workbenchAccessibility.focusedTarget,
              let currentCardID = focused.mediaCardID
        else {
            return false
        }

        let orderedIDs: [String]
        let availableIDs: Set<String>
        let sectionItemCounts: [Int]

        switch workbenchLayout.currentRoute {
        case .recent:
            switch workbenchLayout.route.selectedRecentSection {
            case .videos:
                let sections = RecentTimeSection.group(
                    library.testRecentWatchingItems,
                    timestamp: \.updatedAt
                )
                orderedIDs = sections.flatMap { $0.items.map(\.id) }
                availableIDs = Set(orderedIDs)
                sectionItemCounts = sections.map { $0.items.count }
            case .excerpts:
                let sections = RecentTimeSection.group(
                    excerpt.recentListSummaries,
                    timestamp: \.list.recentPlayedAt
                )
                orderedIDs = sections.flatMap { $0.items.map { String($0.id) } }
                availableIDs = Set(orderedIDs)
                sectionItemCounts = sections.map { $0.items.count }
            }
        case .library:
            let folders = library.displayedCompleteLibraryFolderSummaries
            orderedIDs = folders.map(\.id)
            availableIDs = Set(folders.filter { $0.episodeCount > 0 }.map(\.id))
            sectionItemCounts = []
        case .libraryFolder(let folderPath):
            let videos = library.completeLibraryFolderDetailsByPath[folderPath]?.videos ?? []
            orderedIDs = videos.map(\.id)
            availableIDs = Set(orderedIDs)
            sectionItemCounts = []
        case .excerpt:
            let summaries = excerpt.displayedListSummaries
            orderedIDs = summaries.map { String($0.id) }
            availableIDs = Set(orderedIDs)
            sectionItemCounts = []
        default:
            return false
        }

        guard let currentIndex = orderedIDs.firstIndex(of: currentCardID) else {
            return false
        }

        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()

        if let targetIndex = PlaybackMediaSelectionStore.targetIndex(
            from: currentIndex,
            direction: direction,
            orderedItemIDs: orderedIDs,
            availableItemIDs: availableIDs,
            columnCount: max(1, workbenchAccessibility.cardGridColumnCount),
            sectionItemCounts: sectionItemCounts
        ) {
            workbenchAccessibility.setFocus(.mediaCard(orderedIDs[targetIndex]))
        }
        return true
    }

    @discardableResult
    func activateWorkbenchAccessibilityTarget(_ target: WorkbenchAccessibilityTarget) -> Bool {
        defer {
            reconcileWorkbenchAccessibilityFocus()
            DispatchQueue.main.async { [weak self] in
                self?.reconcileWorkbenchAccessibilityFocus()
            }
        }

        switch target {
        case .topbarSidebarToggle:
            guard !workbenchLayout.isVideoSizeTransitionInProgress else { return false }
            performUserInitiatedAppCommand {
                toggleWorkbenchSidebarVisibilityFromUser()
            }
            return true

        case .topbarBackButton:
            guard workbenchLayout.route.canGoBack,
                  !workbenchLayout.isVideoSizeTransitionInProgress
            else {
                return false
            }
            performUserInitiatedAppCommand {
                goBackInWorkbench()
            }
            return true

        case .topbarForwardButton:
            guard workbenchLayout.route.canGoForward,
                  !workbenchLayout.isVideoSizeTransitionInProgress
            else {
                return false
            }
            performUserInitiatedAppCommand {
                goForwardInWorkbench()
            }
            return true

        case .topbarRecentSegment(let section):
            workbenchLayout.selectRecentSection(section)
            return true

        case .topbarTaskButton:
            performUserInitiatedAppCommand {
                tasks.openPanel()
            }
            return true

        case .topbarSettingsButton:
            performUserInitiatedAppCommand {
                NotificationCenter.default.post(name: .cueSeekerShowSettings, object: nil)
            }
            return true

        case .sidebarItem(let mode):
            guard !workbenchLayout.isVideoSizeTransitionInProgress else { return false }
            performUserInitiatedAppCommand {
                activateWorkbenchPanelMode(mode)
            }
            return true

        case .coverSummaryPrimaryButton:
            switch workbenchLayout.currentRoute {
            case .libraryFolder(let folderPath):
                guard let detail = library.completeLibraryFolderDetailsByPath[folderPath] else {
                    return false
                }
                let recentItem = library.testRecentWatchingItems.first {
                    $0.folderPath == detail.folderPath && !$0.updatedAt.isEmpty
                }
                if let recentItem {
                    Task {
                        await openRecentLibraryWatching(recentItem)
                    }
                    return true
                }
                guard let firstVideo = detail.videos.first else {
                    return false
                }
                prepareLibraryNavigationVideos(detail.videos)
                openLibraryVideo(
                    firstVideo.libraryVideo,
                    displayTitle: firstVideo.displayTitle
                )
                return true

            case .excerptList:
                guard let summary = excerpt.activeListSummary,
                      excerpt.activeListHasPlayableContent
                else {
                    return false
                }
                openExcerptListPlayback(summary)
                return true

            default:
                return false
            }

        case .coverSummaryEditCoverButton:
            guard case .libraryFolder(let folderPath) = workbenchLayout.currentRoute else {
                return false
            }
            openLibraryFolderInFile(folderPath: folderPath)
            return true

        case .coverSummaryMoreButton:
            guard let toggle = workbenchAccessibility.onToggleCoverSummaryMoreMenu else {
                return false
            }
            toggle()
            return true

        case .toolbarSearchField:
            workbenchAccessibility.activeSearchTextField?.focusFromAccessibility()
            return true

        case .toolbarSearchClearButton:
            workbenchAccessibility.activeSearchTextField?.clearTextAndFocus()
            switch workbenchLayout.currentRoute {
            case .search:
                updateSearchQuery("")
            case .library:
                library.overviewSearchDraft = ""
            case .excerpt:
                excerpt.overviewSearchDraft = ""
            case .excerptList:
                updateExcerptSearchQuery("")
            default:
                return false
            }
            return true

        case .toolbarFilterButton:
            guard let openFilter = workbenchAccessibility.onOpenToolbarFilterDialog else {
                return false
            }
            openFilter()
            return true

        case .toolbarSortButton:
            guard let toggleSort = workbenchAccessibility.onToggleToolbarSortMenu else {
                return false
            }
            toggleSort()
            return true

        case .excerptNewListButton:
            beginCreatingExcerptList()
            return true

        case .toolbarExitSelectButton:
            guard let exitSelect = workbenchAccessibility.onExitTableSelectionMode else {
                return false
            }
            exitSelect()
            return true

        case .toolbarSelectionAction(let actionID):
            guard let performAction = workbenchAccessibility.onPerformSelectionAction else {
                return false
            }
            performAction(actionID)
            return true

        case .tableHeaderCheckbox, .tableRowCheckbox, .tableRowCueText, .tableRowActionButton:
            guard let tableCoordinator = workbenchAccessibility.activeSubtitleTableCoordinator else {
                return false
            }
            return tableCoordinator.activateAccessibilityTarget(target)

        case .mediaCard(let cardID):
            switch workbenchLayout.currentRoute {
            case .recent:
                switch workbenchLayout.route.selectedRecentSection {
                case .videos:
                    guard let item = library.testRecentWatchingItems.first(where: { $0.id == cardID }) else {
                        return false
                    }
                    Task {
                        await openRecentLibraryWatching(item)
                    }
                    return true
                case .excerpts:
                    guard let summary = excerpt.recentListSummaries.first(where: { String($0.id) == cardID }) else {
                        return false
                    }
                    openRecentExcerpt(summary)
                    return true
                }

            case .library:
                guard let folder = library.displayedCompleteLibraryFolderSummaries.first(where: { $0.id == cardID }),
                      folder.episodeCount > 0
                else {
                    return false
                }
                navigateWorkbench(to: .libraryFolder(folderPath: folder.folderPath))
                return true

            case .libraryFolder(let folderPath):
                guard let detail = library.completeLibraryFolderDetailsByPath[folderPath],
                      let video = detail.videos.first(where: { $0.id == cardID })
                else {
                    return false
                }
                prepareLibraryNavigationVideos(detail.videos)
                openLibraryVideo(video.libraryVideo, displayTitle: video.displayTitle)
                return true

            case .excerpt:
                guard let summary = excerpt.displayedListSummaries.first(where: { String($0.id) == cardID }) else {
                    return false
                }
                openExcerptList(id: summary.id)
                return true

            default:
                return false
            }

        case .mediaCardActionButton(let cardID):
            return workbenchAccessibility.activateMediaCardAction(id: cardID)

        case .fileAddFolderButton:
            guard !isFileFolderOperationBlocked,
                  let toggle = workbenchAccessibility.onToggleFileAddFolderMenu
            else {
                return false
            }
            toggle()
            return true

        case .fileIndexNowButton:
            guard !indexing.selectedFolders.isEmpty, !isFileFolderOperationBlocked else {
                return false
            }
            indexAllFolders()
            return true

        case .fileStatusIndicatorText:
            let info = FileStatusResolver.resolve(
                indexingStatus: indexing.indexingStatus,
                folderRemovalStatus: indexing.folderRemovalStatus,
                operationNotice: indexing.operationNotice,
                lastUpdatedDate: indexing.lastUpdatedDate
            )
            if case .idle = info, indexing.lastUpdatedDate == nil {
                return false
            }
            openFileStatusTaskDetail(for: info)
            return true

        case .fileBreadcrumb(let nodeID):
            let nodes = FileBreadcrumbResolver.nodes(
                for: workbenchLayout.currentRoute,
                folderCount: indexing.selectedFolders.count,
                singularRootTitle: L("file.all_folders.one"),
                pluralRootTitle: L("file.all_folders.other")
            )
            guard let destination = nodes.first(where: { $0.id == nodeID })?.destination else {
                return false
            }
            workbenchLayout.navigate(to: destination)
            return true

        case .fileCard(let path):
            switch workbenchLayout.currentRoute {
            case .file:
                loadFileSubfolders(rootPath: path)
                workbenchLayout.navigate(to: .fileFolder(rootPath: path))
                return true
            case .fileFolder(let rootPath):
                loadFileObjects(folderPath: path)
                workbenchLayout.navigate(to: .fileFiles(rootPath: rootPath, folderPath: path))
                return true
            default:
                return false
            }

        case .fileCardActionButton(let id), .fileRowActionButton(let id):
            return workbenchAccessibility.activateFileCardAction(id: id)
        }
    }

    // MARK: - Keyboard & Controller Routing

    func handleWorkbenchKeyDown(_ event: NSEvent) -> Bool {
        guard !isPlaybackPageVisible,
              !playbackFullscreenManager.isFullscreen,
              !interfaceLayers.isCovered(.workbenchPage),
              !interfaceLayers.isFrozen(.workbenchPage),
              !Self.hasMarkedTextInFocusedEditor()
        else {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option]
        guard flags.intersection(disallowed).isEmpty else {
            return false
        }

        switch event.keyCode {
        case MenuGate.tabKeyCode:
            let forward = !flags.contains(.shift)
            return moveWorkbenchAccessibilityFocus(forward: forward)

        case 53:
            guard !flags.contains(.shift) else {
                return false
            }
            if workbenchAccessibility.isActive {
                guard !event.isARepeat else {
                    return true
                }
                workbenchAccessibility.clear()
                return true
            }
            if workbenchAccessibility.resignActiveSearchTextFieldIfFocused() {
                return true
            }
            return false

        case 49, 36, 76:
            guard !flags.contains(.shift),
                  let focused = workbenchAccessibility.focusedTarget
            else {
                return false
            }
            if focused == .toolbarSearchField {
                return false
            }
            guard !event.isARepeat else {
                return true
            }
            _ = activateWorkbenchAccessibilityTarget(focused)
            return true

        case 123:
            guard !flags.contains(.shift) else { return false }
            return moveWorkbenchCardSelection(.left)
        case 124:
            guard !flags.contains(.shift) else { return false }
            return moveWorkbenchCardSelection(.right)
        case 125:
            guard !flags.contains(.shift) else { return false }
            return moveWorkbenchCardSelection(.down)
        case 126:
            guard !flags.contains(.shift) else { return false }
            return moveWorkbenchCardSelection(.up)

        default:
            return false
        }
    }

    @discardableResult
    func routeControllerInputToMenuGate(
        _ input: ControllerInput,
        menuGate: MenuGate
    ) -> Bool {
        guard menuGate.hasOpenUncoveredMenu else {
            return false
        }
        switch input {
        case .direction(let direction, _, let isRepeat):
            let keyCode: UInt16
            switch direction {
            case .up: keyCode = 126
            case .down: keyCode = 125
            case .left: keyCode = 123
            case .right: keyCode = 124
            }
            _ = menuGate.routeControllerKey(keyCode, isRepeat: isRepeat)
            return true

        case .button(let button, let isRepeat):
            switch button {
            case .rightShoulder:
                _ = menuGate.routeControllerKey(MenuGate.tabKeyCode, isRepeat: isRepeat)
            case .leftShoulder:
                _ = menuGate.routeControllerKey(MenuGate.shiftTabKeyCode, isRepeat: isRepeat)
            case .south:
                _ = menuGate.routeControllerKey(36, isRepeat: isRepeat)
            case .east:
                _ = menuGate.routeControllerKey(53, isRepeat: isRepeat)
            default:
                break
            }
            return true
        }
    }

    @discardableResult
    func handleGlobalControllerInput(
        _ input: ControllerInput,
        isMainWindowKey: Bool,
        isSettingsWindowKey: Bool
    ) -> Bool {
        if isSettingsWindowKey {
            if settingsInterfaceLayers.hasUncoveredOpenMenu {
                return routeControllerInputToMenuGate(input, menuGate: settingsInterfaceLayers.menuGate)
            }
            return false
        }

        guard isMainWindowKey else {
            return false
        }

        if interfaceLayers.hasUncoveredOpenMenu {
            return routeControllerInputToMenuGate(input, menuGate: interfaceLayers.menuGate)
        }

        if interfaceLayers.isOpen(.dialog) {
            return false
        }

        if isPlaybackPageVisible || playbackFullscreenManager.isFullscreen {
            return handlePlaybackControllerInput(input)
        }

        return handleWorkbenchControllerInput(input)
    }

    @discardableResult
    func handleWorkbenchControllerInput(_ input: ControllerInput) -> Bool {
        guard !isPlaybackPageVisible,
              !playbackFullscreenManager.isFullscreen,
              !interfaceLayers.isCovered(.workbenchPage),
              !interfaceLayers.isFrozen(.workbenchPage),
              !Self.hasMarkedTextInFocusedEditor()
        else {
            return false
        }

        switch input {
        case .button(let button, let isRepeat):
            switch button {
            case .rightShoulder:
                return moveWorkbenchAccessibilityFocus(forward: true)

            case .leftShoulder:
                return moveWorkbenchAccessibilityFocus(forward: false)

            case .south:
                guard let focused = workbenchAccessibility.focusedTarget else {
                    return false
                }
                guard !isRepeat else {
                    return true
                }
                if focused == .toolbarSearchField {
                    workbenchAccessibility.activeSearchTextField?.focusFromAccessibility()
                    return true
                }
                _ = activateWorkbenchAccessibilityTarget(focused)
                return true

            case .east:
                guard !isRepeat else {
                    return true
                }
                if workbenchAccessibility.isActive {
                    workbenchAccessibility.clear()
                    return true
                }
                if workbenchAccessibility.isTableInSelectionMode,
                   let exitSelect = workbenchAccessibility.onExitTableSelectionMode
                {
                    exitSelect()
                    return true
                }
                if workbenchAccessibility.resignActiveSearchTextFieldIfFocused() {
                    return true
                }
                return false

            default:
                return false
            }

        case .direction(let direction, _, _):
            let selectionDirection: PlaybackMediaSelectionDirection
            switch direction {
            case .up: selectionDirection = .up
            case .down: selectionDirection = .down
            case .left: selectionDirection = .left
            case .right: selectionDirection = .right
            }
            return moveWorkbenchCardSelection(selectionDirection)
        }
    }
}
