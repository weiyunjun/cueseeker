import AppKit
import Combine
import CueSeekerCore
import CueSeekerPlayback
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
                    targets.append(.mediaCardActionButton(item.id))
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

        for folder in library.displayedCompleteLibraryFolderSummaries {
            targets.append(.mediaCard(folder.id))
            if folder.episodeCount > 0 {
                targets.append(.mediaCardActionButton(folder.id))
            }
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
            targets.append(.mediaCardActionButton(video.id))
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
        isExcerptTable: Bool,
        to targets: inout [WorkbenchAccessibilityTarget]
    ) {
        if workbenchAccessibility.isTableInSelectionMode {
            targets.append(.toolbarExitSelectButton)
            targets.append(.toolbarSelectionAction(.exportToAnki))
            targets.append(.toolbarSelectionAction(.copyDeepLinks))
            targets.append(.toolbarSelectionAction(.copyTable))
            if isExcerptTable {
                targets.append(.toolbarSelectionAction(.moveTo))
                targets.append(.toolbarSelectionAction(.duplicateTo))
                targets.append(.toolbarSelectionAction(.removeExcerpt))
            } else {
                targets.append(.toolbarSelectionAction(.saveToExcerpt))
            }
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
            isExcerptTable: true,
            to: &targets
        )
    }

    private func appendSearchAccessibilityTargets(to targets: inout [WorkbenchAccessibilityTarget]) {
        appendSchemaToolbarAndTableTargets(
            searchDraft: search.searchQuery,
            isExcerptTable: false,
            to: &targets
        )
    }

    // MARK: - Reconcile & Navigation

    func reconcileWorkbenchAccessibilityFocus() {
        if isPlaybackPageVisible
            || playbackFullscreenManager.isFullscreen
            || activeDialogAccessibilityID() != nil
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

    // MARK: - Dialog & Task Panel Accessibility (Step 2: L-06.1 ~ L-06.11)

    func activeDialogAccessibilityID() -> WorkbenchDialogAccessibilityID? {
        if confirmation.session != nil {
            return .confirmation
        }
        if let detailTaskID = tasks.detailTaskID,
           tasks.taskDetailSnapshot(for: detailTaskID) != nil
        {
            return .taskDetail
        }
        if tasks.isPanelOpen {
            return .taskPanel
        }
        if tasks.ankiExportSession != nil {
            return .ankiExport
        }
        if filterDialog.session != nil {
            return .filter
        }
        if library.fileDetailSession != nil {
            return .fileDetail
        }
        if library.nfsDialogSession != nil {
            return .nfs
        }
        if library.ftpDialogSession != nil {
            return .ftp
        }
        if library.smbDialogSession != nil {
            return .smb
        }
        if library.webdavDialogSession != nil {
            return .webdav
        }
        if library.renameSession != nil {
            return .rename
        }
        if excerpt.listEditorSession != nil {
            return .excerptListEditor
        }
        if library.coverEditingSession != nil {
            return .editCover
        }
        return nil
    }

    private func activeDialogSessionPublisher() -> (ObjectIdentifier, AnyPublisher<Void, Never>)? {
        guard let dialogID = activeDialogAccessibilityID() else {
            return nil
        }
        switch dialogID {
        case .editCover:
            guard let session = library.coverEditingSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .excerptListEditor:
            guard let session = excerpt.listEditorSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .rename:
            guard let session = library.renameSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .webdav:
            guard let session = library.webdavDialogSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .smb:
            guard let session = library.smbDialogSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .ftp:
            guard let session = library.ftpDialogSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .nfs:
            guard let session = library.nfsDialogSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .ankiExport:
            guard let session = tasks.ankiExportSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .filter:
            guard let session = filterDialog.session else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .fileDetail:
            guard let session = library.fileDetailSession else { return nil }
            return (ObjectIdentifier(session), session.objectWillChange.map { _ in () }.eraseToAnyPublisher())
        case .confirmation, .settingsConfirmation, .taskPanel, .taskDetail:
            return nil
        }
    }

    private func updateActiveDialogSessionSubscriptionIfNeeded() {
        guard let (objectID, publisher) = activeDialogSessionPublisher() else {
            activeDialogSessionObjectID = nil
            activeDialogSessionCancellable = nil
            return
        }
        guard activeDialogSessionObjectID != objectID else {
            return
        }
        activeDialogSessionObjectID = objectID
        activeDialogSessionCancellable = publisher.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reconcileDialogAccessibilityFocus()
            }
        }
    }

    func currentDialogAccessibilityTargets() -> [WorkbenchDialogAccessibilityTarget] {
        guard let dialogID = activeDialogAccessibilityID() else {
            return []
        }

        switch dialogID {
        case .editCover:
            guard let session = library.coverEditingSession else { return [] }
            var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
            if session.selectedSource == nil {
                targets.append(.editCoverChooseImage)
            }
            targets.append(.editCoverCancel)
            targets.append(.editCoverSave)
            return targets

        case .excerptListEditor:
            guard let session = excerpt.listEditorSession else { return [] }
            var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
            if session.selectedCoverSource == nil {
                targets.append(.excerptEditorChooseImage)
            }
            targets.append(.excerptEditorNameField)
            targets.append(.excerptEditorDescriptionField)
            targets.append(.excerptEditorCancel)
            targets.append(.excerptEditorSave)
            return targets

        case .rename:
            guard library.renameSession != nil else { return [] }
            return [
                .dialogCloseButton,
                .renameNewNameField,
                .renameCancel,
                .renameConfirm
            ]

        case .webdav:
            guard let session = library.webdavDialogSession else { return [] }
            return remoteFolderDialogAccessibilityTargets(
                session: session,
                connectionFieldTargets: [.remoteAddressField, .remoteUsernameField, .remotePasswordField]
            )

        case .smb:
            guard let session = library.smbDialogSession else { return [] }
            return remoteFolderDialogAccessibilityTargets(
                session: session,
                connectionFieldTargets: [.remoteAddressField, .remotePortField, .remoteUsernameField, .remotePasswordField]
            )

        case .ftp:
            guard let session = library.ftpDialogSession else { return [] }
            return remoteFolderDialogAccessibilityTargets(
                session: session,
                connectionFieldTargets: [.remoteAddressField, .remotePortField, .remoteUsernameField, .remotePasswordField]
            )

        case .nfs:
            guard let session = library.nfsDialogSession else { return [] }
            return remoteFolderDialogAccessibilityTargets(
                session: session,
                connectionFieldTargets: [.remoteAddressField]
            )

        case .ankiExport:
            guard let session = tasks.ankiExportSession else { return [] }
            var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
            targets.append(.ankiAddFront)
            for item in session.items(for: .front) {
                targets.append(.ankiRemoveItem(.front, item))
            }
            targets.append(.ankiAddBack)
            for item in session.items(for: .back) {
                targets.append(.ankiRemoveItem(.back, item))
            }
            targets.append(.ankiFileNameField)
            targets.append(.ankiLocationField)
            targets.append(.ankiChooseFolderButton)
            targets.append(.ankiCancel)
            targets.append(.ankiExport)
            return targets

        case .filter:
            guard let session = filterDialog.session else { return [] }
            var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
            for section in filterDialogSections(for: session) {
                for option in section.options {
                    targets.append(.filterChip(section.id, option.id))
                }
            }
            targets.append(.filterReset)
            targets.append(.filterCancel)
            targets.append(.filterShow)
            return targets

        case .confirmation:
            guard let session = confirmation.session else { return [] }
            var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
            for action in session.actions {
                targets.append(.confirmationAction(action.id))
            }
            return targets

        case .settingsConfirmation:
            return currentSettingsDialogAccessibilityTargets()

        case .fileDetail:
            guard let session = library.fileDetailSession else { return [] }
            if session.isFileDetail {
                return [.dialogCloseButton, .fileDetailPairedSwitcher]
            } else {
                return [.dialogCloseButton]
            }

        case .taskPanel:
            guard tasks.isPanelOpen else { return [] }
            var targets: [WorkbenchDialogAccessibilityTarget] = TaskQueueTab.allCases.map {
                .taskPanelTab($0)
            }
            targets.append(.dialogCloseButton)
            switch tasks.selectedTab {
            case .current:
                for entry in tasks.current {
                    targets.append(.taskCardActionButton("current-\(entry.id)"))
                }
            case .completed:
                for record in tasks.completed {
                    targets.append(.taskCardActionButton("history-\(record.id)"))
                }
            case .incomplete:
                for record in tasks.incomplete {
                    targets.append(.taskCardActionButton("history-\(record.id)"))
                }
            }
            return targets

        case .taskDetail:
            return [.dialogCloseButton]
        }
    }

    private func remoteFolderDialogAccessibilityTargets<Session: RemoteFolderDialogSessionProtocol>(
        session: Session,
        connectionFieldTargets: [WorkbenchDialogAccessibilityTarget]
    ) -> [WorkbenchDialogAccessibilityTarget] {
        var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
        switch session.step {
        case .connection:
            targets.append(contentsOf: connectionFieldTargets)
            targets.append(.remoteCancel)
            targets.append(.remoteConnect)
        case .browser:
            for node in session.breadcrumbNodes.dropLast() {
                targets.append(.remoteBreadcrumb(node.id))
            }
            if !session.isLoadingDirectory && session.directoryErrorMessage == nil {
                for item in session.items where item.kind == .folder {
                    if !session.isFolderItemDisabled(item) {
                        targets.append(.remoteFolderCard(item.id))
                    }
                    targets.append(.remoteFolderEnterButton(item.id))
                }
            }
            targets.append(.remoteBack)
            targets.append(.remoteCancel)
            targets.append(.remoteAdd)
        }
        return targets
    }

    private func filterDialogCountsAndOptions(
        for session: CueFacetFilterDialogSession
    ) -> (
        counts: CueFacetFilterCounts,
        availableLanguages: [SubtitleLanguageCode],
        availableFolders: [CueFacetFolderOption]
    ) {
        switch session.source {
        case .search:
            let state = SearchFacetDialogSearchState(search)
            return (
                counts: state.counts(for: session.filter),
                availableLanguages: state.availableLanguages,
                availableFolders: state.availableFolders
            )
        case .excerpt:
            let availableLanguages = SubtitleLanguageCode.listed(
                emptyDistribution: search.emptySearchFacetDistribution,
                snapshot: excerpt.residentFacetSnapshot
            )
            let availableFolders = CueFacetFolderOption.listed(
                emptyDistribution: search.emptySearchFacetDistribution,
                snapshot: excerpt.residentFacetSnapshot
            )
            let counts: CueFacetFilterCounts
            if excerpt.residentFacetSnapshot != nil {
                let projection = residentExcerptTableProjection(
                    searchText: excerpt.tableSearchDraft,
                    facetFilter: session.filter
                )
                counts = CueFacetFilterCounts(
                    distribution: projection.distribution,
                    isCalculating: false,
                    totalCount: projection.distribution.totalCount
                )
            } else {
                counts = .unknown
            }
            return (
                counts: counts,
                availableLanguages: availableLanguages,
                availableFolders: availableFolders
            )
        }
    }

    func filterDialogSections(for session: CueFacetFilterDialogSession) -> [CueFacetSection] {
        let resolved = filterDialogCountsAndOptions(for: session)
        return CueFacetSection.sections(
            counts: resolved.counts,
            availableLanguages: resolved.availableLanguages,
            availableFolders: resolved.availableFolders,
            selection: session.filter,
            update: { change in change(&session.filter) }
        )
    }

    func isDialogAccessibilityTargetEnabled(_ target: WorkbenchDialogAccessibilityTarget) -> Bool {
        guard let dialogID = activeDialogAccessibilityID() else {
            return false
        }
        switch target {
        case .dialogCloseButton:
            switch dialogID {
            case .editCover:
                return library.coverEditingSession?.isSaving == false
            case .excerptListEditor:
                return excerpt.listEditorSession?.isSaving == false
            default:
                return true
            }

        case .editCoverChooseImage, .editCoverCancel:
            return library.coverEditingSession?.isSaving == false

        case .editCoverSave:
            return library.coverEditingSession?.canSave == true

        case .excerptEditorChooseImage, .excerptEditorCancel, .excerptEditorSave:
            return excerpt.listEditorSession?.isSaving == false

        case .excerptEditorNameField, .excerptEditorDescriptionField:
            return true

        case .renameNewNameField, .renameCancel, .renameConfirm:
            return true

        case .remoteAddressField, .remotePortField, .remoteUsernameField, .remotePasswordField, .remoteConnect:
            switch dialogID {
            case .webdav:
                return library.webdavDialogSession?.isSubmitting == false
            case .smb:
                return library.smbDialogSession?.isSubmitting == false
            case .ftp:
                return library.ftpDialogSession?.isSubmitting == false
            case .nfs:
                return library.nfsDialogSession?.isSubmitting == false
            default:
                return false
            }

        case .remoteCancel, .remoteBack, .remoteBreadcrumb:
            return true

        case .remoteFolderCard(let itemID):
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder && !session.isFolderItemDisabled(item)
            case .smb:
                guard let session = library.smbDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder && !session.isFolderItemDisabled(item)
            case .ftp:
                guard let session = library.ftpDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder && !session.isFolderItemDisabled(item)
            case .nfs:
                guard let session = library.nfsDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder && !session.isFolderItemDisabled(item)
            default:
                return false
            }

        case .remoteFolderEnterButton(let itemID):
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder
            case .smb:
                guard let session = library.smbDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder
            case .ftp:
                guard let session = library.ftpDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder
            case .nfs:
                guard let session = library.nfsDialogSession,
                      let item = session.items.first(where: { $0.id == itemID })
                else { return false }
                return item.kind == .folder
            default:
                return false
            }

        case .remoteAdd:
            switch dialogID {
            case .webdav:
                return library.webdavDialogSession?.canAddInBrowser == true
            case .smb:
                return library.smbDialogSession?.canAddInBrowser == true
            case .ftp:
                return library.ftpDialogSession?.canAddInBrowser == true
            case .nfs:
                return library.nfsDialogSession?.canAddInBrowser == true
            default:
                return false
            }

        case .ankiAddFront:
            return tasks.ankiExportSession?.remainingItems(for: .front).isEmpty == false

        case .ankiAddBack:
            return tasks.ankiExportSession?.remainingItems(for: .back).isEmpty == false

        case .ankiRemoveItem, .ankiFileNameField, .ankiLocationField, .ankiChooseFolderButton, .ankiCancel, .ankiExport:
            return true

        case .filterChip:
            return true

        case .filterReset:
            guard let session = filterDialog.session else { return false }
            let resolved = filterDialogCountsAndOptions(for: session)
            return !session.filter.normalizingFolders(
                listed: resolved.availableFolders.map(\.path)
            ).isEmpty

        case .filterCancel:
            return true

        case .filterShow:
            guard let session = filterDialog.session else { return false }
            let resolved = filterDialogCountsAndOptions(for: session)
            return resolved.counts.totalCount != nil

        case .confirmationAction, .fileDetailPairedSwitcher, .taskPanelTab, .taskCardActionButton:
            return true
        }
    }

    func reconcileDialogAccessibilityFocus() {
        updateActiveDialogSessionSubscriptionIfNeeded()

        guard let currentDialogID = activeDialogAccessibilityID() else {
            if workbenchAccessibility.activeDialogID != nil {
                workbenchAccessibility.activeDialogID = nil
            }
            if workbenchAccessibility.focusedDialogTarget != nil
                || workbenchAccessibility.isAnyDialogTextInputFocused
            {
                workbenchAccessibility.clearDialog(keepTextInputFocus: false)
            }
            return
        }

        workbenchAccessibility.clear()

        if interfaceLayers.hasUncoveredOpenMenu {
            if workbenchAccessibility.activeDialogID != currentDialogID {
                workbenchAccessibility.activeDialogID = currentDialogID
            }
            workbenchAccessibility.clearDialog(keepTextInputFocus: false)
            return
        }

        if workbenchAccessibility.activeDialogID != currentDialogID {
            workbenchAccessibility.activeDialogID = currentDialogID
            workbenchAccessibility.clearDialog(keepTextInputFocus: true)
            return
        }

        guard let focused = workbenchAccessibility.focusedDialogTarget else {
            return
        }

        let targets = currentDialogAccessibilityTargets()
        if !targets.contains(focused) {
            workbenchAccessibility.clearDialog(keepTextInputFocus: true)
        }
    }

    @discardableResult
    func moveDialogAccessibilityFocus(forward: Bool) -> Bool {
        updateActiveDialogSessionSubscriptionIfNeeded()

        guard let activeDialogID = activeDialogAccessibilityID() else {
            workbenchAccessibility.activeDialogID = nil
            workbenchAccessibility.clearDialog(keepTextInputFocus: true)
            return false
        }

        workbenchAccessibility.clear()

        let targets = currentDialogAccessibilityTargets()
        guard !targets.isEmpty else {
            workbenchAccessibility.activeDialogID = activeDialogID
            workbenchAccessibility.clearDialog(keepTextInputFocus: true)
            return true
        }

        let nextTarget: WorkbenchDialogAccessibilityTarget
        if workbenchAccessibility.activeDialogID == activeDialogID,
           let current = workbenchAccessibility.focusedDialogTarget,
           let index = targets.firstIndex(of: current)
        {
            let nextIndex = forward
                ? (index + 1) % targets.count
                : (index - 1 + targets.count) % targets.count
            nextTarget = targets[nextIndex]
        } else {
            nextTarget = forward ? targets[0] : targets[targets.count - 1]
        }

        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()

        let isEnabled = isDialogAccessibilityTargetEnabled(nextTarget)
        workbenchAccessibility.setDialogFocus(
            nextTarget,
            dialogID: activeDialogID,
            isTargetEnabled: isEnabled
        )
        return true
    }

    @discardableResult
    func closeTopmostDialogFromAccessibility() -> Bool {
        guard let dialogID = activeDialogAccessibilityID() else {
            return false
        }
        defer {
            reconcileDialogAccessibilityFocus()
        }

        switch dialogID {
        case .confirmation:
            confirmation.session = nil
            return true
        case .settingsConfirmation:
            return closeSettingsDialogFromAccessibility()
        case .taskDetail:
            tasks.closeTaskDetail()
            return true
        case .taskPanel:
            tasks.closePanel()
            return true
        case .ankiExport:
            closeAnkiExportDialog()
            return true
        case .filter:
            filterDialog.session = nil
            return true
        case .fileDetail:
            closeFileDetailDialog()
            return true
        case .nfs:
            closeNFSFolderDialog()
            return true
        case .ftp:
            closeFTPFolderDialog()
            return true
        case .smb:
            closeSMBFolderDialog()
            return true
        case .webdav:
            closeWebDAVFolderDialog()
            return true
        case .rename:
            closeRenameDialog()
            return true
        case .excerptListEditor:
            guard excerpt.listEditorSession?.isSaving != true else {
                return false
            }
            closeExcerptListEditor()
            return true
        case .editCover:
            guard library.coverEditingSession?.isSaving != true else {
                return false
            }
            cancelLibraryCoverEditing()
            return true
        }
    }

    @discardableResult
    func activateDialogAccessibilityTarget(_ target: WorkbenchDialogAccessibilityTarget) -> Bool {
        guard let dialogID = activeDialogAccessibilityID(),
              isDialogAccessibilityTargetEnabled(target)
        else {
            return false
        }
        defer {
            reconcileDialogAccessibilityFocus()
            DispatchQueue.main.async { [weak self] in
                self?.reconcileDialogAccessibilityFocus()
            }
        }

        switch target {
        case .dialogCloseButton:
            return closeTopmostDialogFromAccessibility()

        case .editCoverChooseImage:
            guard let session = library.coverEditingSession else { return false }
            beginChoosingLibraryCover(session)
            return true

        case .editCoverCancel:
            return closeTopmostDialogFromAccessibility()

        case .editCoverSave:
            guard let session = library.coverEditingSession, session.canSave else {
                return false
            }
            saveLibraryCoverEditing(session)
            return true

        case .excerptEditorChooseImage:
            guard let session = excerpt.listEditorSession else { return false }
            beginChoosingExcerptListCover(session)
            return true

        case .excerptEditorNameField:
            workbenchAccessibility.focusDialogTextInput(.excerptEditorName)
            return true

        case .excerptEditorDescriptionField:
            workbenchAccessibility.focusDialogTextInput(.excerptEditorDescription)
            return true

        case .excerptEditorCancel:
            return closeTopmostDialogFromAccessibility()

        case .excerptEditorSave:
            guard let session = excerpt.listEditorSession else { return false }
            validateExcerptListEditor(session)
            if session.nameValidationMessage != nil {
                workbenchAccessibility.focusDialogTextInput(.excerptEditorName)
                return true
            }
            if session.descriptionValidationMessage != nil {
                workbenchAccessibility.focusDialogTextInput(.excerptEditorDescription)
                return true
            }
            saveExcerptListEditor(session)
            return true

        case .renameNewNameField:
            workbenchAccessibility.focusDialogTextInput(.renameNewName)
            return true

        case .renameCancel:
            return closeTopmostDialogFromAccessibility()

        case .renameConfirm:
            guard let session = library.renameSession else { return false }
            guard session.validate() else {
                workbenchAccessibility.focusDialogTextInput(.renameNewName)
                return true
            }
            confirmRename(session)
            return true

        case .remoteAddressField:
            workbenchAccessibility.focusDialogTextInput(.remoteAddress)
            return true

        case .remotePortField:
            workbenchAccessibility.focusDialogTextInput(.remotePort)
            return true

        case .remoteUsernameField:
            workbenchAccessibility.focusDialogTextInput(.remoteUsername)
            return true

        case .remotePasswordField:
            workbenchAccessibility.focusDialogTextInput(.remotePassword)
            return true

        case .remoteCancel:
            return closeTopmostDialogFromAccessibility()

        case .remoteConnect, .remoteAdd:
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession else { return false }
                confirmWebDAVFolderDialog(session)
                return true
            case .smb:
                guard let session = library.smbDialogSession else { return false }
                confirmSMBFolderDialog(session)
                return true
            case .ftp:
                guard let session = library.ftpDialogSession else { return false }
                confirmFTPFolderDialog(session)
                return true
            case .nfs:
                guard let session = library.nfsDialogSession else { return false }
                confirmNFSFolderDialog(session)
                return true
            default:
                return false
            }

        case .remoteBack:
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession else { return false }
                navigateBackInWebDAVFolderDialog(session)
                return true
            case .smb:
                guard let session = library.smbDialogSession else { return false }
                navigateBackInSMBFolderDialog(session)
                return true
            case .ftp:
                guard let session = library.ftpDialogSession else { return false }
                navigateBackInFTPFolderDialog(session)
                return true
            case .nfs:
                guard let session = library.nfsDialogSession else { return false }
                navigateBackInNFSFolderDialog(session)
                return true
            default:
                return false
            }

        case .remoteBreadcrumb(let nodeID):
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession,
                      let node = session.breadcrumbNodes.dropLast().first(where: { $0.id == nodeID })
                else { return false }
                navigateWebDAVBreadcrumb(to: node, in: session)
                return true
            case .smb:
                guard let session = library.smbDialogSession,
                      let node = session.breadcrumbNodes.dropLast().first(where: { $0.id == nodeID })
                else { return false }
                navigateSMBBreadcrumb(to: node, in: session)
                return true
            case .ftp:
                guard let session = library.ftpDialogSession,
                      let node = session.breadcrumbNodes.dropLast().first(where: { $0.id == nodeID })
                else { return false }
                navigateFTPBreadcrumb(to: node, in: session)
                return true
            case .nfs:
                guard let session = library.nfsDialogSession,
                      let node = session.breadcrumbNodes.dropLast().first(where: { $0.id == nodeID })
                else { return false }
                navigateNFSBreadcrumb(to: node, in: session)
                return true
            default:
                return false
            }

        case .remoteFolderCard(let itemID):
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder,
                      !session.isFolderItemDisabled(item)
                else { return false }
                session.toggleFolderSelection(item)
                return true
            case .smb:
                guard let session = library.smbDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder,
                      !session.isFolderItemDisabled(item)
                else { return false }
                session.toggleFolderSelection(item)
                return true
            case .ftp:
                guard let session = library.ftpDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder,
                      !session.isFolderItemDisabled(item)
                else { return false }
                session.toggleFolderSelection(item)
                return true
            case .nfs:
                guard let session = library.nfsDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder,
                      !session.isFolderItemDisabled(item)
                else { return false }
                session.toggleFolderSelection(item)
                return true
            default:
                return false
            }

        case .remoteFolderEnterButton(let itemID):
            switch dialogID {
            case .webdav:
                guard let session = library.webdavDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder
                else { return false }
                openWebDAVSubfolder(item, in: session)
                return true
            case .smb:
                guard let session = library.smbDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder
                else { return false }
                openSMBBSubfolderIfAvailable(item, in: session)
                return true
            case .ftp:
                guard let session = library.ftpDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder
                else { return false }
                openFTPSubfolder(item, in: session)
                return true
            case .nfs:
                guard let session = library.nfsDialogSession,
                      let item = session.items.first(where: { $0.id == itemID }),
                      item.kind == .folder
                else { return false }
                openNFSSubfolder(item, in: session)
                return true
            default:
                return false
            }

        case .ankiAddFront:
            guard let trigger = workbenchAccessibility.onTriggerAnkiAddFront else {
                return false
            }
            trigger()
            return true

        case .ankiAddBack:
            guard let trigger = workbenchAccessibility.onTriggerAnkiAddBack else {
                return false
            }
            trigger()
            return true

        case .ankiRemoveItem(let side, let item):
            guard let session = tasks.ankiExportSession else { return false }
            session.removeItem(item, from: side)
            workbenchAccessibility.clearDialog(keepTextInputFocus: true)
            return true

        case .ankiFileNameField:
            workbenchAccessibility.focusDialogTextInput(.ankiFileName)
            return true

        case .ankiLocationField:
            workbenchAccessibility.focusDialogTextInput(.ankiLocation)
            return true

        case .ankiChooseFolderButton:
            guard let session = tasks.ankiExportSession else { return false }
            beginChoosingAnkiExportFolder(session)
            return true

        case .ankiCancel:
            return closeTopmostDialogFromAccessibility()

        case .ankiExport:
            guard let session = tasks.ankiExportSession else { return false }
            guard session.validate() else {
                if session.validationMessage != nil {
                    workbenchAccessibility.focusDialogTextInput(.ankiFileName)
                } else if session.locationValidationMessage != nil {
                    workbenchAccessibility.focusDialogTextInput(.ankiLocation)
                }
                return true
            }
            confirmAnkiExport(session)
            return true

        case .filterChip(let sectionKind, let optionID):
            guard let session = filterDialog.session else { return false }
            let sections = filterDialogSections(for: session)
            guard let section = sections.first(where: { $0.id == sectionKind }),
                  let option = section.options.first(where: { $0.id == optionID })
            else {
                return false
            }
            option.toggle()
            return true

        case .filterReset:
            guard let session = filterDialog.session else { return false }
            session.filter = CueFacetFilter()
            return true

        case .filterCancel:
            return closeTopmostDialogFromAccessibility()

        case .filterShow:
            guard let session = filterDialog.session else { return false }
            session.show()
            filterDialog.session = nil
            return true

        case .confirmationAction(let actionID):
            guard let session = confirmation.session,
                  let action = session.actions.first(where: { $0.id == actionID })
            else {
                return false
            }
            action.action()
            return true

        case .fileDetailPairedSwitcher:
            guard let toggle = workbenchAccessibility.onToggleFileDetailPairedMenu else {
                return false
            }
            toggle()
            return true

        case .taskPanelTab(let tab):
            tasks.selectedTab = tab
            return true

        case .taskCardActionButton(let cardID):
            return workbenchAccessibility.activateTaskCardAction(id: cardID)
        }
    }

    private func openSMBBSubfolderIfAvailable(
        _ item: WebDAVBrowserItem,
        in session: SMBFolderDialogSession
    ) {
        openSMBSubfolder(item, in: session)
    }

    func handleDialogKeyDown(_ event: NSEvent) -> Bool {
        guard !Self.hasMarkedTextInFocusedEditor(),
              !interfaceLayers.hasUncoveredOpenMenu,
              activeDialogAccessibilityID() != nil
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
            return moveDialogAccessibilityFocus(forward: forward)

        case 53:
            guard !flags.contains(.shift) else {
                return false
            }
            guard !event.isARepeat else {
                return true
            }
            reconcileDialogAccessibilityFocus()
            if workbenchAccessibility.isDialogActive {
                workbenchAccessibility.clearDialog(keepTextInputFocus: true)
                return true
            }
            return closeTopmostDialogFromAccessibility()

        case 49, 36, 76:
            guard !flags.contains(.shift) else {
                return false
            }
            reconcileDialogAccessibilityFocus()
            guard let focused = workbenchAccessibility.focusedDialogTarget else {
                return false
            }
            if focused.dialogTextInputKind != nil {
                return false
            }
            guard !event.isARepeat else {
                return true
            }
            _ = activateDialogAccessibilityTarget(focused)
            return true

        default:
            return false
        }
    }

    @discardableResult
    func handleDialogControllerInput(_ input: ControllerInput) -> Bool {
        guard !Self.hasMarkedTextInFocusedEditor(),
              !interfaceLayers.hasUncoveredOpenMenu,
              activeDialogAccessibilityID() != nil
        else {
            return false
        }

        switch input {
        case .button(let button, let isRepeat):
            switch button {
            case .rightShoulder:
                return moveDialogAccessibilityFocus(forward: true)

            case .leftShoulder:
                return moveDialogAccessibilityFocus(forward: false)

            case .south:
                reconcileDialogAccessibilityFocus()
                guard let focused = workbenchAccessibility.focusedDialogTarget else {
                    return false
                }
                guard !isRepeat else {
                    return true
                }
                if let inputKind = focused.dialogTextInputKind {
                    let isEnabled = isDialogAccessibilityTargetEnabled(focused)
                    workbenchAccessibility.focusDialogTextInput(inputKind, isEnabled: isEnabled)
                    return true
                }
                _ = activateDialogAccessibilityTarget(focused)
                return true

            case .east:
                guard !isRepeat else {
                    return true
                }
                reconcileDialogAccessibilityFocus()
                if workbenchAccessibility.isDialogActive {
                    workbenchAccessibility.clearDialog(keepTextInputFocus: true)
                    return true
                }
                return closeTopmostDialogFromAccessibility()

            default:
                return false
            }

        case .direction:
            return false
        }
    }

    // MARK: - Keyboard & Controller Routing

    func handleWorkbenchKeyDown(_ event: NSEvent) -> Bool {
        guard !Self.hasMarkedTextInFocusedEditor() else {
            return false
        }

        if activeDialogAccessibilityID() != nil {
            guard !interfaceLayers.hasUncoveredOpenMenu else {
                return false
            }
            return handleDialogKeyDown(event)
        }

        guard !isPlaybackPageVisible,
              !playbackFullscreenManager.isFullscreen,
              !interfaceLayers.isCovered(.workbenchPage),
              !interfaceLayers.isFrozen(.workbenchPage)
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
            return handleSettingsControllerInput(input)
        }

        guard isMainWindowKey else {
            return false
        }

        if interfaceLayers.hasUncoveredOpenMenu {
            return routeControllerInputToMenuGate(input, menuGate: interfaceLayers.menuGate)
        }

        if activeDialogAccessibilityID() != nil {
            return handleDialogControllerInput(input)
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
        if activeDialogAccessibilityID() != nil {
            guard !interfaceLayers.hasUncoveredOpenMenu else {
                return false
            }
            return handleDialogControllerInput(input)
        }

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

    // MARK: - Settings Window Accessibility (Step 3)

    func currentSettingsAccessibilityTargets() -> [SettingsAccessibilityTarget] {
        var targets: [SettingsAccessibilityTarget] = SettingsCategory.allCases.map {
            .sidebarCategory($0)
        }

        switch workbenchAccessibility.selectedSettingsCategory {
        case .general:
            for mode in AppAppearanceMode.allCases {
                targets.append(.appearanceMode(mode))
            }
            targets.append(.searchShowCueGroup)
            targets.append(.searchPrefillCommandPanel)
            targets.append(.languageDropdown)
            targets.append(.deepLinkPlayFirstSearchResult)

        case .play:
            targets.append(.playAutoPause)
            targets.append(.playAutoSwitch)
            targets.append(.numberField(.autoSwitchGap))
            for mode in PlaybackDecodeMode.allCases {
                targets.append(.decodeMode(mode))
            }

        case .shortcuts:
            let keymap = settings.playbackShortcuts.keymap
            for action in PlaybackShortcutAction.allCases where !keymap.isDefault(action) {
                targets.append(.shortcutRestoreDefault(action))
            }

        case .subtitle:
            let style = settings.srtSubtitleStyle
            targets.append(.subtitleFontDropdown)
            targets.append(.numberField(.subtitleSize))
            targets.append(.subtitleBold)
            targets.append(.subtitleItalic)
            appendSubtitleColorWellTargets(.textColor, to: &targets)
            targets.append(.numberField(.subtitleLetterSpacing))
            targets.append(.numberField(.subtitleLineSpacing))

            for alignment in SRTSubtitleStyle.HorizontalAlignment.allCases {
                targets.append(.subtitleHorizontalAlignment(alignment))
            }
            targets.append(.numberField(.subtitleMarginX))
            for alignment in SRTSubtitleStyle.VerticalAlignment.allCases {
                targets.append(.subtitleVerticalAlignment(alignment))
            }
            targets.append(.numberField(.subtitleMarginY))

            for borderType in SRTSubtitleStyle.BorderType.allCases {
                targets.append(.subtitleBorderType(borderType))
            }
            if style.borderType == .outline {
                appendSubtitleColorWellTargets(.outlineColor, to: &targets)
                targets.append(.numberField(.subtitleOutlineWidth))
            } else {
                appendSubtitleColorWellTargets(.backgroundColor, to: &targets)
                targets.append(.numberField(.subtitleBackgroundOpacity))
            }
            targets.append(.numberField(.subtitleBlur))

            appendSubtitleColorWellTargets(.shadowColor, to: &targets)
            targets.append(.numberField(.subtitleShadowOpacity))
            targets.append(.numberField(.subtitleShadowOffset))

            targets.append(.subtitleRestoreDefaults)

        case .maintenance:
            targets.append(.maintenanceRefresh)
            targets.append(.maintenanceCompactDatabase)

        case .developer:
            targets.append(.developerEnableFTSDiagnostics)
            targets.append(.developerRefresh)
        }

        return targets
    }

    private func appendSubtitleColorWellTargets(
        _ id: SettingsSubtitleCategory.ColorFieldID,
        to targets: inout [SettingsAccessibilityTarget]
    ) {
        targets.append(.subtitleColorField(id))
        if workbenchAccessibility.activeSubtitleColorPopover == id,
           workbenchAccessibility.focusedSettingsTarget?.colorWellID == id {
            for index in SettingsSubtitleColorField.presetHexColors.indices {
                targets.append(.subtitleColorPreset(id, index))
            }
        }
    }

    func isSettingsAccessibilityTargetEnabled(_ target: SettingsAccessibilityTarget) -> Bool {
        switch target {
        case .playAutoSwitch:
            return settings.autoPauseAfterCueFinishesEnabled
        case .shortcutRestoreDefault(let action):
            return !settings.playbackShortcuts.keymap.isDefault(action)
        case .subtitleRestoreDefaults:
            return settings.srtSubtitleStyle != SRTSubtitleStyle()
        case .maintenanceRefresh:
            return !indexing.folderRemovalStatus.isRemoving
                && !indexing.databaseMaintenanceStatus.isCompacting
        case .maintenanceCompactDatabase:
            return canCompactDatabase
        case .developerRefresh:
            return settings.searchFTSVocabularyDiagnosticsEnabled
                && !indexing.searchFTSVocabularyDiagnosticsStatus.isLoading
        default:
            return true
        }
    }

    func reconcileSettingsAccessibilityFocus() {
        if settings.confirmation.session != nil
            || settingsInterfaceLayers.hasUncoveredOpenMenu
            || workbenchAccessibility.isShortcutRecording
        {
            _ = workbenchAccessibility.clearSettings(
                keepTextInputFocus: false,
                keepColorPopoverOpen: false
            )
            return
        }

        guard let focused = workbenchAccessibility.focusedSettingsTarget else {
            return
        }

        let targets = currentSettingsAccessibilityTargets()
        if !targets.contains(focused) {
            _ = workbenchAccessibility.clearSettings(
                keepTextInputFocus: false,
                keepColorPopoverOpen: false
            )
            return
        }

        if let inputKind = focused.textInputKind,
           !isSettingsAccessibilityTargetEnabled(focused) {
            workbenchAccessibility.unfocusSettingsTextInput(inputKind)
        }
    }

    @discardableResult
    func moveSettingsAccessibilityFocus(forward: Bool) -> Bool {
        let targets = currentSettingsAccessibilityTargets()
        guard !targets.isEmpty else {
            _ = workbenchAccessibility.clearSettings(
                keepTextInputFocus: false,
                keepColorPopoverOpen: false
            )
            return false
        }

        let nextTarget: SettingsAccessibilityTarget
        if let current = workbenchAccessibility.focusedSettingsTarget,
           let index = targets.firstIndex(of: current)
        {
            if forward {
                nextTarget = targets[(index + 1) % targets.count]
            } else {
                nextTarget = targets[(index - 1 + targets.count) % targets.count]
            }
        } else {
            nextTarget = forward ? targets[0] : targets[targets.count - 1]
        }

        let isEnabled = isSettingsAccessibilityTargetEnabled(nextTarget)
        workbenchAccessibility.setSettingsFocus(nextTarget, isTargetEnabled: isEnabled)
        return true
    }

    @discardableResult
    func activateSettingsAccessibilityTarget(_ target: SettingsAccessibilityTarget) -> Bool {
        guard isSettingsAccessibilityTargetEnabled(target) else {
            return false
        }

        switch target {
        case .sidebarCategory(let category):
            guard workbenchAccessibility.selectedSettingsCategory != category else {
                return true
            }
            TooltipCenter.shared.dismissFromUserInteraction()
            workbenchAccessibility.selectedSettingsCategory = category
            workbenchAccessibility.activeSubtitleColorPopover = nil
            workbenchAccessibility.unfocusAllSettingsTextInputs()
            return true

        case .appearanceMode(let mode):
            if settings.appAppearanceMode != mode {
                settings.appAppearanceMode = mode
            }
            return true

        case .searchShowCueGroup:
            settings.cueGroupPresentation.setFromUser(!settings.cueGroupPresentation.isEnabled)
            return true

        case .searchPrefillCommandPanel:
            settings.prefillCommandPanelWithFocusedCue.toggle()
            return true

        case .languageDropdown:
            workbenchAccessibility.onToggleSettingsLanguageMenu?()
            return true

        case .deepLinkPlayFirstSearchResult:
            settings.urlSchemePlayFirstSearchResultEnabled.toggle()
            return true

        case .playAutoPause:
            settings.autoPauseAfterCueFinishesEnabled.toggle()
            return true

        case .playAutoSwitch:
            settings.autoSwitchToNextCuesInPlaylistEnabled.toggle()
            return true

        case .decodeMode(let mode):
            if settings.playbackDecodeMode != mode {
                settings.playbackDecodeMode = mode
            }
            return true

        case .shortcutRestoreDefault(let action):
            settings.playbackShortcuts.reset(action)
            _ = workbenchAccessibility.clearSettings(
                keepTextInputFocus: false,
                keepColorPopoverOpen: false
            )
            return true

        case .subtitleFontDropdown:
            workbenchAccessibility.onToggleSettingsSubtitleFontMenu?()
            return true

        case .subtitleBold:
            settings.srtSubtitleStyle.isBold.toggle()
            return true

        case .subtitleItalic:
            settings.srtSubtitleStyle.isItalic.toggle()
            return true

        case .subtitleColorField(let id):
            workbenchAccessibility.activeSubtitleColorPopover = id
            workbenchAccessibility.focusSettingsTextInput(.subtitleColorField(id), isEnabled: true)
            return true

        case .subtitleColorPreset(let id, let index):
            guard SettingsSubtitleColorField.presetHexColors.indices.contains(index) else {
                return false
            }
            applySubtitlePresetColor(SettingsSubtitleColorField.presetHexColors[index], for: id)
            return true

        case .subtitleHorizontalAlignment(let alignment):
            if settings.srtSubtitleStyle.horizontalAlignment != alignment {
                settings.srtSubtitleStyle.horizontalAlignment = alignment
            }
            return true

        case .subtitleVerticalAlignment(let alignment):
            if settings.srtSubtitleStyle.verticalAlignment != alignment {
                settings.srtSubtitleStyle.verticalAlignment = alignment
            }
            return true

        case .subtitleBorderType(let borderType):
            if settings.srtSubtitleStyle.borderType != borderType {
                settings.srtSubtitleStyle.borderType = borderType
            }
            return true

        case .subtitleRestoreDefaults:
            workbenchAccessibility.activeSubtitleColorPopover = nil
            workbenchAccessibility.unfocusAllSettingsTextInputs()
            settings.srtSubtitleStyle = SRTSubtitleStyle()
            return true

        case .maintenanceRefresh:
            refreshDatabaseStorageStats()
            return true

        case .maintenanceCompactDatabase:
            requestCompactDatabaseConfirmation()
            return true

        case .developerEnableFTSDiagnostics:
            settings.searchFTSVocabularyDiagnosticsEnabled.toggle()
            return true

        case .developerRefresh:
            refreshSearchFTSVocabularyDiagnostics()
            return true

        case .numberField(let id):
            workbenchAccessibility.focusSettingsTextInput(.numberField(id), isEnabled: true)
            return true
        }
    }

    func applySubtitlePresetColor(
        _ presetHex: String,
        for id: SettingsSubtitleCategory.ColorFieldID
    ) {
        guard let rgb = SettingsSubtitleColorField.parseRGB(fromHex: presetHex) else {
            return
        }
        let keyPath: WritableKeyPath<SRTSubtitleStyle, SRTSubtitleStyle.Color>
        switch id {
        case .textColor:
            keyPath = \.textColor
        case .outlineColor:
            keyPath = \.outlineColor
        case .backgroundColor:
            keyPath = \.backgroundColor
        case .shadowColor:
            keyPath = \.shadowColor
        }
        var updated = settings.srtSubtitleStyle[keyPath: keyPath]
        updated.red = rgb.red
        updated.green = rgb.green
        updated.blue = rgb.blue
        settings.srtSubtitleStyle[keyPath: keyPath] = updated
    }

    // MARK: - Settings Confirmation Dialog Accessibility

    func currentSettingsDialogAccessibilityTargets() -> [WorkbenchDialogAccessibilityTarget] {
        guard let session = settings.confirmation.session else {
            return []
        }
        var targets: [WorkbenchDialogAccessibilityTarget] = [.dialogCloseButton]
        for action in session.actions {
            targets.append(.confirmationAction(action.id))
        }
        return targets
    }

    func reconcileSettingsDialogAccessibilityFocus() {
        guard settings.confirmation.session != nil else {
            _ = workbenchAccessibility.clearSettingsDialog()
            return
        }

        _ = workbenchAccessibility.clearSettings(
            keepTextInputFocus: false,
            keepColorPopoverOpen: false
        )

        guard let focused = workbenchAccessibility.focusedSettingsDialogTarget else {
            return
        }

        let targets = currentSettingsDialogAccessibilityTargets()
        if !targets.contains(focused) {
            _ = workbenchAccessibility.clearSettingsDialog()
        }
    }

    @discardableResult
    func moveSettingsDialogAccessibilityFocus(forward: Bool) -> Bool {
        guard settings.confirmation.session != nil else {
            _ = workbenchAccessibility.clearSettingsDialog()
            return false
        }
        let targets = currentSettingsDialogAccessibilityTargets()
        guard !targets.isEmpty else {
            _ = workbenchAccessibility.clearSettingsDialog()
            return false
        }

        let nextTarget: WorkbenchDialogAccessibilityTarget
        if let current = workbenchAccessibility.focusedSettingsDialogTarget,
           let index = targets.firstIndex(of: current)
        {
            if forward {
                nextTarget = targets[(index + 1) % targets.count]
            } else {
                nextTarget = targets[(index - 1 + targets.count) % targets.count]
            }
        } else {
            nextTarget = forward ? targets[0] : targets[targets.count - 1]
        }

        workbenchAccessibility.setSettingsDialogFocus(nextTarget)
        return true
    }

    @discardableResult
    func closeSettingsDialogFromAccessibility() -> Bool {
        guard settings.confirmation.session != nil else {
            return false
        }
        _ = workbenchAccessibility.clearSettingsDialog()
        settings.confirmation.session = nil
        return true
    }

    @discardableResult
    func activateSettingsDialogAccessibilityTarget(
        _ target: WorkbenchDialogAccessibilityTarget
    ) -> Bool {
        guard let session = settings.confirmation.session else {
            return false
        }
        switch target {
        case .dialogCloseButton:
            return closeSettingsDialogFromAccessibility()
        case .confirmationAction(let actionID):
            guard let action = session.actions.first(where: { $0.id == actionID }) else {
                return false
            }
            _ = workbenchAccessibility.clearSettingsDialog()
            action.action()
            settings.confirmation.session = nil
            return true
        default:
            return false
        }
    }

    @discardableResult
    func handleSettingsDialogKeyDown(_ event: NSEvent) -> Bool {
        guard settings.confirmation.session != nil,
              !settingsInterfaceLayers.hasUncoveredOpenMenu,
              !Self.hasMarkedTextInFocusedEditor()
        else {
            return false
        }

        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function])

        switch event.keyCode {
        case 48: // Tab
            if modifiers.isEmpty {
                return moveSettingsDialogAccessibilityFocus(forward: true)
            } else if modifiers == [.shift] {
                return moveSettingsDialogAccessibilityFocus(forward: false)
            }
            return false

        case 53: // Esc
            guard modifiers.isEmpty else { return false }
            guard !event.isARepeat else { return true }
            if workbenchAccessibility.isSettingsDialogActive {
                _ = workbenchAccessibility.clearSettingsDialog()
                return true
            }
            return closeSettingsDialogFromAccessibility()

        case 49: // Space
            guard modifiers.isEmpty,
                  let focused = workbenchAccessibility.focusedSettingsDialogTarget
            else {
                return false
            }
            guard !event.isARepeat else { return true }
            _ = activateSettingsDialogAccessibilityTarget(focused)
            return true

        case 36, 76: // Return / Keypad Enter
            guard modifiers.isEmpty else { return false }
            guard let focused = workbenchAccessibility.focusedSettingsDialogTarget else {
                return true
            }
            guard !event.isARepeat else { return true }
            _ = activateSettingsDialogAccessibilityTarget(focused)
            return true

        default:
            return false
        }
    }

    @discardableResult
    func handleSettingsDialogControllerInput(_ input: ControllerInput) -> Bool {
        guard settings.confirmation.session != nil,
              !settingsInterfaceLayers.hasUncoveredOpenMenu,
              !Self.hasMarkedTextInFocusedEditor()
        else {
            return false
        }

        switch input {
        case .button(let button, let isRepeat):
            switch button {
            case .rightShoulder:
                return moveSettingsDialogAccessibilityFocus(forward: true)
            case .leftShoulder:
                return moveSettingsDialogAccessibilityFocus(forward: false)
            case .south:
                guard let focused = workbenchAccessibility.focusedSettingsDialogTarget else {
                    return false
                }
                guard !isRepeat else { return true }
                _ = activateSettingsDialogAccessibilityTarget(focused)
                return true
            case .east:
                guard !isRepeat else { return true }
                if workbenchAccessibility.isSettingsDialogActive {
                    _ = workbenchAccessibility.clearSettingsDialog()
                    return true
                }
                return closeSettingsDialogFromAccessibility()
            default:
                return false
            }
        case .direction:
            return false
        }
    }

    // MARK: - Settings Window Keyboard & Controller Routing

    @discardableResult
    func handleSettingsKeyDown(_ event: NSEvent) -> Bool {
        guard !settingsInterfaceLayers.hasUncoveredOpenMenu else {
            return false
        }

        if settings.confirmation.session != nil {
            return handleSettingsDialogKeyDown(event)
        }

        guard !workbenchAccessibility.isShortcutRecording,
              !Self.hasMarkedTextInFocusedEditor()
        else {
            return false
        }

        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function])

        switch event.keyCode {
        case 48: // Tab
            if modifiers.isEmpty {
                return moveSettingsAccessibilityFocus(forward: true)
            } else if modifiers == [.shift] {
                return moveSettingsAccessibilityFocus(forward: false)
            }
            return false

        case 53: // Esc
            guard modifiers.isEmpty else { return false }
            guard !event.isARepeat else { return true }
            if workbenchAccessibility.isSettingsActive {
                _ = workbenchAccessibility.clearSettings(
                    keepTextInputFocus: true,
                    keepColorPopoverOpen: true
                )
                return true
            }
            if workbenchAccessibility.activeSubtitleColorPopover != nil
                || workbenchAccessibility.isAnySettingsTextInputFocused
            {
                workbenchAccessibility.activeSubtitleColorPopover = nil
                workbenchAccessibility.unfocusAllSettingsTextInputs()
                return true
            }
            return false

        case 49: // Space
            guard modifiers.isEmpty else { return false }
            if workbenchAccessibility.isAnySettingsTextInputFocused {
                return false
            }
            guard let focused = workbenchAccessibility.focusedSettingsTarget else {
                return false
            }
            guard !event.isARepeat else { return true }
            _ = activateSettingsAccessibilityTarget(focused)
            return true

        case 36, 76: // Return / Keypad Enter
            guard modifiers.isEmpty else { return false }
            if workbenchAccessibility.isAnySettingsTextInputFocused {
                return false
            }
            guard let focused = workbenchAccessibility.focusedSettingsTarget else {
                return false
            }
            guard !event.isARepeat else { return true }
            _ = activateSettingsAccessibilityTarget(focused)
            return true

        default:
            return false
        }
    }

    @discardableResult
    func handleSettingsControllerInput(_ input: ControllerInput) -> Bool {
        guard !settingsInterfaceLayers.hasUncoveredOpenMenu else {
            return false
        }

        if settings.confirmation.session != nil {
            return handleSettingsDialogControllerInput(input)
        }

        guard !workbenchAccessibility.isShortcutRecording,
              !Self.hasMarkedTextInFocusedEditor()
        else {
            return false
        }

        switch input {
        case .button(let button, let isRepeat):
            switch button {
            case .rightShoulder:
                return moveSettingsAccessibilityFocus(forward: true)
            case .leftShoulder:
                return moveSettingsAccessibilityFocus(forward: false)
            case .south:
                guard let focused = workbenchAccessibility.focusedSettingsTarget else {
                    return false
                }
                guard !isRepeat else { return true }
                _ = activateSettingsAccessibilityTarget(focused)
                return true
            case .east:
                guard !isRepeat else { return true }
                if workbenchAccessibility.isSettingsActive {
                    _ = workbenchAccessibility.clearSettings(
                        keepTextInputFocus: true,
                        keepColorPopoverOpen: true
                    )
                    return true
                }
                if workbenchAccessibility.activeSubtitleColorPopover != nil
                    || workbenchAccessibility.isAnySettingsTextInputFocused
                {
                    workbenchAccessibility.activeSubtitleColorPopover = nil
                    workbenchAccessibility.unfocusAllSettingsTextInputs()
                    return true
                }
                return false
            default:
                return false
            }
        case .direction:
            return false
        }
    }

    // MARK: - Playback Surfaces Accessibility (Step 4: L-07 ~ L-09)

    func activePlaybackAccessibilitySurface() -> PlaybackAccessibilitySurface? {
        guard activeDialogAccessibilityID() == nil,
              !interfaceLayers.isOpen(.dialog)
        else {
            return nil
        }
        guard currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen else {
            return nil
        }
        if let presentation = playback.commandPanelPresentation {
            return .commandPanel(presentation.page)
        }
        if let session = playback.subtitleFocusSession,
           session.state != .closed
        {
            return .playbackOverlay
        }
        if currentPlaybackVideoPath != nil {
            return .playerStage
        }
        return nil
    }

    func currentPlaybackAccessibilityTargets() -> [PlaybackAccessibilityTarget] {
        guard let surface = activePlaybackAccessibilitySurface() else {
            return []
        }

        switch surface {
        case .playerStage:
            var targets: [PlaybackAccessibilityTarget] = [
                .playerReturn,
                .playerCommandPanel,
                .playerTask,
                .playerSettings,
            ]
            if playback.chromeSnapshot.isCueQueuePlayback || isCueQueuePlaybackActive {
                targets.append(contentsOf: [
                    .playerAutoPause,
                    .playerAutoSwitch,
                    .playerAutoSwitchGapDecrease,
                    .playerAutoSwitchGapIncrease,
                ])
            }
            if playback.playbackViewModel != nil {
                targets.append(contentsOf: [
                    .playerPlayPause,
                    .playerPrevious,
                    .playerNext,
                    .playerMute,
                    .playerPlaybackOverlay,
                    .playerRepeat,
                    .playerCopyScreenshot,
                    .playerSubtitlesMenu,
                    .playerSpeedMenu,
                    .playerMoreMenu,
                    .playerFullscreen,
                ])
            }
            return targets

        case .playbackOverlay:
            guard let session = playback.subtitleFocusSession,
                  session.state != .closed
            else {
                return []
            }
            var targets: [PlaybackAccessibilityTarget] = [.overlayReturn]
            for module in session.availableModules {
                targets.append(.overlayTab(module))
            }
            targets.append(contentsOf: [
                .overlayCommandPanel,
                .overlayTask,
                .overlaySettings,
            ])

            if session.selectedModule == .current {
                if session.currentSnapshot != nil {
                    targets.append(contentsOf: [
                        .overlayFooterAction("excerpt"),
                        .overlayFooterAction("copy-cue-text"),
                        .overlayFooterAction("copy-deep-link"),
                        .overlayFooterAction("play"),
                    ])
                }
            } else if session.selectedModule == .collage {
                if session.collageSnapshot != nil {
                    targets.append(contentsOf: [
                        .overlayFooterAction("copy-collage"),
                        .overlayFooterAction("export-collage"),
                        .overlayFooterAction("select"),
                    ])
                }
            } else if session.selectedModule == .playlist {
                if let libraryStore = session.libraryStore {
                    if let detail = libraryStore.detail, !detail.videos.isEmpty {
                        for video in detail.videos {
                            targets.append(.overlayVideoCard(video.id))
                            targets.append(.overlayVideoCardActionButton(video.id))
                        }
                    }
                    targets.append(.overlayFooterAction("play"))
                } else if session.playlistWindow != nil {
                    targets.append(contentsOf: [
                        .overlayFooterAction("excerpt"),
                        .overlayFooterAction("copy-cue-text"),
                        .overlayFooterAction("copy-deep-link"),
                        .overlayFooterAction("play"),
                    ])
                }
            }
            return targets

        case .commandPanel(let page):
            guard let presentation = playback.commandPanelPresentation else {
                return []
            }
            var targets: [PlaybackAccessibilityTarget] = []
            switch page {
            case .root:
                targets.append(.commandPanelSearchField)
                if !presentation.query.isEmpty {
                    targets.append(.commandPanelSearchClearButton)
                }
                let itemCount = playbackCommandPanelItemCount(for: .root)
                for ordinal in 0..<itemCount {
                    targets.append(.commandPanelRootOption(ordinal))
                }
                targets.append(.commandPanelFooterAction("open"))

            case .recentVideos:
                targets.append(.commandPanelBackButton)
                for item in playbackCommandPanelRecentVideos {
                    targets.append(.commandPanelRecentCard(item.id))
                    targets.append(.commandPanelRecentCardActionButton(item.id))
                }
                targets.append(.commandPanelFooterAction("open"))

            case .recentExcerpts:
                targets.append(.commandPanelBackButton)
                for summary in playbackCommandPanelRecentExcerpts {
                    let cardID = String(summary.id)
                    targets.append(.commandPanelRecentCard(cardID))
                    targets.append(.commandPanelRecentCardActionButton(cardID))
                }
                targets.append(.commandPanelFooterAction("open"))

            case .searchResults:
                targets.append(contentsOf: [
                    .commandPanelBackButton,
                    .commandPanelFilterButton,
                    .commandPanelSortButton,
                    .commandPanelFooterAction("excerpt"),
                    .commandPanelFooterAction("copy-cue-text"),
                    .commandPanelFooterAction("copy-deep-link"),
                    .commandPanelFooterAction("play"),
                ])
            }
            return targets
        }
    }

    func clearPlaybackAccessibilityFocus(keepTextInputFocus: Bool = true) {
        _ = workbenchAccessibility.clearPlayback(keepTextInputFocus: keepTextInputFocus)
        playback.chromeVisibility.setAccessibilityFocused(false)
    }

    func applyPlaybackAccessibilityFocus(
        _ target: PlaybackAccessibilityTarget?,
        surface: PlaybackAccessibilitySurface
    ) {
        guard let target else {
            clearPlaybackAccessibilityFocus()
            return
        }
        workbenchAccessibility.setPlaybackFocus(target, surface: surface)
        playback.chromeVisibility.setAccessibilityFocused(surface == .playerStage)

        if let cardID = target.overlayVideoCardID {
            _ = playback.subtitleFocusSession?.libraryStore?.selectFromAccessibility(cardID)
        } else if let ordinal = target.commandPanelRootOptionOrdinal {
            PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
            selectPlaybackCommandPanelItem(at: ordinal)
        } else if let cardID = target.commandPanelRecentCardID {
            selectPlaybackCommandPanelRecentCardFromAccessibility(cardID)
        }
    }

    func reconcilePlaybackAccessibilityFocus() {
        let hasOpenPlaybackMenu = interfaceLayers.hasUncoveredOpenMenu
            || playback.isSpeedMenuOpen
            || playback.subtitleMenu != nil
            || playback.moreMenu != nil
            || playback.excerptDestinationMenu != nil
        if hasOpenPlaybackMenu {
            if workbenchAccessibility.isPlaybackActive || playback.chromeVisibility.isAccessibilityFocused {
                clearPlaybackAccessibilityFocus(keepTextInputFocus: true)
            }
            return
        }

        guard let surface = activePlaybackAccessibilitySurface() else {
            if workbenchAccessibility.isPlaybackActive || playback.chromeVisibility.isAccessibilityFocused {
                clearPlaybackAccessibilityFocus(keepTextInputFocus: true)
            }
            if workbenchAccessibility.activePlaybackSurface != nil {
                workbenchAccessibility.activePlaybackSurface = nil
            }
            return
        }

        if workbenchAccessibility.activePlaybackSurface != surface {
            clearPlaybackAccessibilityFocus(keepTextInputFocus: true)
            workbenchAccessibility.activePlaybackSurface = surface
            return
        }

        guard let focused = workbenchAccessibility.focusedPlaybackTarget else {
            if playback.chromeVisibility.isAccessibilityFocused {
                playback.chromeVisibility.setAccessibilityFocused(false)
            }
            return
        }

        let targets = currentPlaybackAccessibilityTargets()
        if !targets.contains(focused) {
            clearPlaybackAccessibilityFocus(keepTextInputFocus: true)
        } else {
            playback.chromeVisibility.setAccessibilityFocused(surface == .playerStage)
        }
    }

    @discardableResult
    func movePlaybackAccessibilityFocus(forward: Bool) -> Bool {
        reconcilePlaybackAccessibilityFocus()
        guard let surface = activePlaybackAccessibilitySurface() else {
            return false
        }
        let targets = currentPlaybackAccessibilityTargets()
        guard !targets.isEmpty else {
            clearPlaybackAccessibilityFocus()
            return true
        }

        if let current = workbenchAccessibility.focusedPlaybackTarget,
           let index = targets.firstIndex(of: current)
        {
            let nextIndex = forward
                ? (index + 1) % targets.count
                : (index - 1 + targets.count) % targets.count
            applyPlaybackAccessibilityFocus(targets[nextIndex], surface: surface)
        } else {
            applyPlaybackAccessibilityFocus(forward ? targets.first : targets.last, surface: surface)
        }
        return true
    }

    @discardableResult
    func movePlaybackOverlayVideoCardSelection(
        _ direction: PlaybackMediaSelectionDirection
    ) -> Bool {
        guard let session = playback.subtitleFocusSession,
              session.selectedModule == .playlist,
              let libraryStore = session.libraryStore
        else {
            return false
        }
        _ = session.requestMediaSelectionNavigation(direction)
        if let selectedID = libraryStore.selection.selectedItemID {
            applyPlaybackAccessibilityFocus(
                .overlayVideoCard(selectedID),
                surface: .playbackOverlay
            )
        }
        return true
    }

    @discardableResult
    func moveCommandPanelRootSelectionFromAccessibility(_ offset: Int) -> Bool {
        guard playback.commandPanelPresentation?.page == .root else {
            return false
        }
        _ = movePlaybackCommandPanelSelection(offset)
        if let ordinal = playback.commandPanelPresentation?.selectedOrdinal {
            applyPlaybackAccessibilityFocus(
                .commandPanelRootOption(ordinal),
                surface: .commandPanel(.root)
            )
        }
        return true
    }

    @discardableResult
    func moveCommandPanelRecentCardSelectionFromAccessibility(
        _ direction: PlaybackMediaSelectionDirection
    ) -> Bool {
        guard let page = playback.commandPanelPresentation?.page,
              page.showsRecentCardGrid
        else {
            return false
        }
        _ = movePlaybackCommandPanelRecentCardSelection(direction)
        if let ordinal = playback.commandPanelPresentation?.selectedOrdinal {
            let itemIDs = playbackCommandPanelRecentCardItemIDs(for: page)
            if itemIDs.indices.contains(ordinal) {
                applyPlaybackAccessibilityFocus(
                    .commandPanelRecentCard(itemIDs[ordinal]),
                    surface: .commandPanel(page)
                )
            }
        }
        return true
    }

    func selectPlaybackCommandPanelRecentCardFromAccessibility(_ cardID: String) {
        guard var presentation = playback.commandPanelPresentation,
              presentation.page.showsRecentCardGrid
        else {
            return
        }
        let itemIDs = playbackCommandPanelRecentCardItemIDs(for: presentation.page)
        guard let ordinal = itemIDs.firstIndex(of: cardID) else {
            return
        }
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        guard presentation.selectedOrdinal != ordinal else {
            return
        }
        presentation.selectedOrdinal = ordinal
        playback.noteCommandPanelRecentCardSelectionMoved()
        playback.presentCommandPanel(presentation)
    }

    @discardableResult
    func activatePlaybackAccessibilityTarget(_ target: PlaybackAccessibilityTarget) -> Bool {
        switch target {
        case .playerReturn:
            workbenchLayout.clearSearchFocus()
            stopPlayback()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .overlayReturn:
            _ = dismissPlaybackSubtitleFocusFromUser()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerCommandPanel, .overlayCommandPanel:
            _ = presentPlaybackCommandPanel()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerTask, .overlayTask:
            tasks.openPanel()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerSettings, .overlaySettings:
            performUserInitiatedAppCommand {
                NotificationCenter.default.post(name: .cueSeekerShowSettings, object: nil)
            }
            return true

        case .playerAutoPause:
            guard playback.chromeSnapshot.isCueQueuePlayback || isCueQueuePlaybackActive else { return true }
            settings.autoPauseAfterCueFinishesEnabled.toggle()
            return true

        case .playerAutoSwitch:
            guard playback.chromeSnapshot.isCueQueuePlayback || isCueQueuePlaybackActive,
                  settings.autoPauseAfterCueFinishesEnabled
            else {
                return true
            }
            settings.autoSwitchToNextCuesInPlaylistEnabled.toggle()
            return true

        case .playerAutoSwitchGapDecrease:
            guard playback.chromeSnapshot.isCueQueuePlayback || isCueQueuePlaybackActive,
                  settings.autoPauseAfterCueFinishesEnabled,
                  settings.autoSwitchToNextCuesInPlaylistEnabled,
                  settings.canDecreaseAutoSwitchCueSequenceGap
            else {
                return true
            }
            settings.decreaseAutoSwitchCueSequenceGapMilliseconds()
            return true

        case .playerAutoSwitchGapIncrease:
            guard playback.chromeSnapshot.isCueQueuePlayback || isCueQueuePlaybackActive,
                  settings.autoPauseAfterCueFinishesEnabled,
                  settings.autoSwitchToNextCuesInPlaylistEnabled,
                  settings.canIncreaseAutoSwitchCueSequenceGap
            else {
                return true
            }
            settings.increaseAutoSwitchCueSequenceGapMilliseconds()
            return true

        case .playerPlayPause:
            togglePlaybackFromUser()
            return true

        case .playerPrevious:
            guard playback.chromeSnapshot.canGoPrevious || canGoPrevious else { return true }
            goPrevious()
            return true

        case .playerNext:
            guard playback.chromeSnapshot.canGoNext || canGoNext else { return true }
            goNext()
            return true

        case .playerMute:
            playback.playbackViewModel?.toggleMute()
            return true

        case .playerPlaybackOverlay:
            _ = openPlaybackSubtitleFocusFromUser()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerRepeat:
            _ = repeatCurrentPlaylistCue()
            return true

        case .playerCopyScreenshot:
            playback.playbackViewModel?.copyCurrentFrameScreenshot()
            return true

        case .playerSubtitlesMenu:
            togglePlaybackSubtitleMenu()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerSpeedMenu:
            if playback.isSpeedMenuOpen {
                playback.closeSpeedMenu()
            } else if let viewModel = playback.playbackViewModel {
                playback.openSpeedMenu(
                    defaultPosition: PlaybackViewModel.speedPresetIndex(
                        for: viewModel.playbackSpeed
                    )
                )
            }
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerMoreMenu:
            togglePlaybackMoreMenu()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .playerFullscreen:
            let isDisabled = !(playback.chromeSnapshot.hasPlaybackSelection || hasPlaybackSelection)
                || workbenchLayout.isVideoSizeTransitionInProgress
                || playbackFullscreenManager.isTransitioning
            guard !isDisabled else { return true }
            togglePlaybackFullscreenFromUser()
            return true

        case .overlayTab(let module):
            guard let session = playback.subtitleFocusSession else { return false }
            if session.selectedModule != module {
                _ = session.selectModule(module)
            }
            reconcilePlaybackAccessibilityFocus()
            return true

        case .overlayVideoCard(let id):
            guard let session = playback.subtitleFocusSession,
                  let libraryStore = session.libraryStore
            else {
                return false
            }
            _ = libraryStore.selectFromAccessibility(id)
            if let video = libraryStore.primaryActionVideo(itemID: id) {
                _ = openPlaybackLibraryEpisodeFromOverlay(video)
            }
            reconcilePlaybackAccessibilityFocus()
            return true

        case .overlayVideoCardActionButton(let id):
            _ = playback.subtitleFocusSession?.libraryStore?.selectFromAccessibility(id)
            let opened = workbenchAccessibility.activatePlaybackOverlayCardAction(id: id)
            reconcilePlaybackAccessibilityFocus()
            return opened

        case .overlayFooterAction(let actionID):
            guard let session = playback.subtitleFocusSession else { return false }
            switch actionID {
            case "excerpt":
                _ = requestPlaybackSubtitleFocusAction(.excerpt)
                reconcilePlaybackAccessibilityFocus()
                return true
            case "copy-cue-text":
                _ = requestPlaybackSubtitleFocusAction(.copyCueText)
                return true
            case "copy-deep-link":
                _ = requestPlaybackSubtitleFocusAction(.copyCueMarkdownLink)
                return true
            case "play":
                if session.selectedModule == .playlist, session.libraryStore != nil {
                    _ = requestPlaybackLibraryPrimaryAction()
                } else {
                    _ = requestPlaybackSubtitleFocusAction(.playFromThisCue)
                }
                reconcilePlaybackAccessibilityFocus()
                return true
            case "copy-collage":
                _ = session.copyCurrentCollage()
                return true
            case "export-collage":
                _ = session.exportCurrentCollage()
                return true
            case "select":
                _ = session.toggleFocusedCollageCueSelection()
                return true
            default:
                return false
            }

        case .commandPanelSearchField:
            workbenchAccessibility.activeCommandPanelSearchTextField?.focusFromAccessibility()
            return true

        case .commandPanelSearchClearButton:
            workbenchAccessibility.activeCommandPanelSearchTextField?.clearTextAndFocus()
            updatePlaybackCommandPanelQuery("")
            reconcilePlaybackAccessibilityFocus()
            return true

        case .commandPanelRootOption(let ordinal):
            selectPlaybackCommandPanelItem(at: ordinal)
            _ = openSelectedPlaybackCommandPanelItem()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .commandPanelBackButton:
            _ = returnPlaybackCommandPanelToRoot()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .commandPanelFilterButton:
            if let openFilter = workbenchAccessibility.onOpenCommandPanelFilterDialog {
                openFilter()
            } else {
                filterDialog.session = CueFacetFilterDialogSession(
                    source: .search,
                    filter: search.searchFacetFilter,
                    apply: { [weak self] newFilter in
                        self?.applySearchFacetFilter(newFilter)
                    }
                )
            }
            reconcilePlaybackAccessibilityFocus()
            return true

        case .commandPanelSortButton:
            guard let toggleSort = workbenchAccessibility.onToggleCommandPanelSortMenu else {
                return false
            }
            toggleSort()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .commandPanelRecentCard(let id):
            selectPlaybackCommandPanelRecentCardFromAccessibility(id)
            _ = openSelectedPlaybackCommandPanelItem()
            reconcilePlaybackAccessibilityFocus()
            return true

        case .commandPanelRecentCardActionButton(let id):
            selectPlaybackCommandPanelRecentCardFromAccessibility(id)
            let opened = workbenchAccessibility.activateCommandPanelCardAction(id: id)
            reconcilePlaybackAccessibilityFocus()
            return opened

        case .commandPanelFooterAction(let actionID):
            switch actionID {
            case "open":
                _ = openSelectedPlaybackCommandPanelItem()
                reconcilePlaybackAccessibilityFocus()
                return true
            case "excerpt":
                _ = requestPlaybackCommandPanelSearchAction(.excerpt)
                reconcilePlaybackAccessibilityFocus()
                return true
            case "copy-cue-text":
                _ = requestPlaybackCommandPanelSearchAction(.copyCueText)
                return true
            case "copy-deep-link":
                _ = requestPlaybackCommandPanelSearchAction(.copyCueMarkdownLink)
                return true
            case "play":
                _ = requestPlaybackCommandPanelSearchAction(.playFromThisCue)
                reconcilePlaybackAccessibilityFocus()
                return true
            default:
                return false
            }
        }
    }
}
