import AppKit
import CueSeekerCore
import SwiftUI

/// The File page: a three-level card flow visualizing indexed roots, folders,
/// and video/subtitle file groups.
struct WorkbenchFileView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var routeState: WorkbenchRouteState
    @EnvironmentObject private var library: LibraryStore
    /// Observed because any library task disables the folder controls and the
    static let fileCardCoordinateSpaceName = "WorkbenchFileViewCoordinateSpace"
    private static let addFolderMenuID = "__add_folder_menu__"

    /// Observed because any library task disables the folder controls and the
    /// rename menus.
    @ObservedObject var tasks: TaskQueueStore
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    @State private var isChoosingFolder = false
    @State private var activeMenu: FileCardMenuState?
    @State private var addFolderButtonAnchorFrame: CGRect = .zero
    @StateObject private var highlight = MenuHighlightModel()
    @State private var viewportSize: CGSize = .zero

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            Group {
                switch routeState.currentRoute {
                case .fileFolder(let rootPath):
                    fileScrollSurface(id: rootPath, accessibility: accessibility) { emptyMinHeight in
                        subfolderContent(
                            rootPath: rootPath,
                            emptyMinHeight: emptyMinHeight,
                            accessibility: accessibility
                        )
                    }
                case .fileFiles(let rootPath, let folderPath):
                    fileScrollSurface(id: "\(rootPath)/\(folderPath)", accessibility: accessibility) { emptyMinHeight in
                        filesContent(
                            rootPath: rootPath,
                            folderPath: folderPath,
                            emptyMinHeight: emptyMinHeight,
                            accessibility: accessibility
                        )
                    }
                default:
                    fileScrollSurface(id: "root", accessibility: accessibility) { emptyMinHeight in
                        rootContent(
                            emptyMinHeight: emptyMinHeight,
                            accessibility: accessibility
                        )
                    }
                }
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .onChange(of: routeState.currentRoute) { _ in
            dismissMenu()
            if !indexing.isDatabaseOperationActive {
                indexing.clearTransientNotice()
            }
        }
        .onDisappear {
            dismissMenu()
            indexing.clearTransientNotice()
            workbenchAccessibility?.onToggleFileAddFolderMenu = nil
        }
    }

    private func fileScrollSurface<Content: View>(
        id: AnyHashable,
        accessibility: WorkbenchAccessibilityCoordinator?,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) -> some View {
        let topFocusClearance = WorkbenchControlMetrics.redesignSpacing1
        let hasSecondaryHeaderRow = !breadcrumbNodes.isEmpty || !indexing.selectedFolders.isEmpty

        return GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    statusAndActionRow(accessibility: accessibility)
                        .padding(
                            .bottom,
                            hasSecondaryHeaderRow
                                ? WorkbenchControlMetrics.redesignSpacing4
                                : (WorkbenchControlMetrics.redesignSpacing4 - topFocusClearance)
                        )

                    if !breadcrumbNodes.isEmpty {
                        breadcrumbRow(accessibility: accessibility)
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3 - topFocusClearance)
                    } else if !indexing.selectedFolders.isEmpty {
                        rootFoldersHeaderRow
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3 - topFocusClearance)
                    }
                }
                .workbenchPageInlinePadding()
                .padding(.top, WorkbenchControlMetrics.redesignWorkbenchPageTopPadding)

                GeometryReader { scrollGeometry in
                    let emptyMinHeight = max(
                        0,
                        scrollGeometry.size.height
                            - topFocusClearance
                            - WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                    )
                    WorkbenchScrollView([.vertical]) {
                        content(emptyMinHeight)
                            .padding(.top, topFocusClearance)
                            .workbenchPageInlinePadding()
                            .padding(.bottom, WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding)
                            .frame(width: scrollGeometry.size.width, alignment: .topLeading)
                    }
                    .id(id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .topLeading
            )
            .coordinateSpace(name: Self.fileCardCoordinateSpaceName)
            .onAppear {
                viewportSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                viewportSize = newSize
            }
            .overlay(alignment: .topLeading) {
                if let activeMenu {
                    let menuFrame = activeMenu.menuFrame
                    ZStack(alignment: .topLeading) {
                        MenuGateClientView(
                            gate: appState.interfaceLayers.menuGate,
                            owner: .workbenchPage,
                            kind: .cardMenu,
                            menuFrame: menuFrame,
                            anchorFrame: activeMenu.anchorFrame,
                            handleKey: { keyCode, _ in
                                highlight.handleStandardMenuKey(
                                    keyCode: keyCode,
                                    onActivate: { _ = activateHighlightedItem(in: activeMenu) },
                                    onDismiss: { dismissMenu() }
                                )
                            },
                            dismiss: { _ in
                                dismissMenu(openedAs: activeMenu.id)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        FileCardMenuPopover(
                            items: activeMenu.items,
                            highlight: highlight,
                            onDismiss: { dismissMenu() }
                        )
                        .offset(x: menuFrame.minX, y: menuFrame.minY)
                    }
                    .id(activeMenu.id)
                    .zIndex(1000)
                }
            }
        }
    }

    private func toggleMenu(for cardID: String, anchorFrame: CGRect, items: [FileCardMenuItem]) {
        if activeMenu?.cardID == cardID, activeMenu?.isButtonAnchored == true {
            dismissMenu()
        } else {
            openButtonMenu(for: cardID, anchorFrame: anchorFrame, items: items)
        }
    }

    private func openButtonMenu(for cardID: String, anchorFrame: CGRect, items: [FileCardMenuItem]) {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let measureStartedAt = ProcessInfo.processInfo.systemUptime
        let naturalSize = measuredMenuSize(for: items)
        let measureMs = max(0, (ProcessInfo.processInfo.systemUptime - measureStartedAt) * 1_000)
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: cardID == Self.addFolderMenuID ? "file_add_folder_menu" : "file_card_button_menu",
            trigger: "button_anchor",
            startedAt: startedAt,
            measureMs: measureMs
        )
        let container = CGRect(origin: .zero, size: viewportSize)
        let anchorForPlacement = cardID == Self.addFolderMenuID
            ? anchorFrame
            : CGRect(
                x: anchorFrame.maxX - naturalSize.width,
                y: anchorFrame.minY,
                width: naturalSize.width,
                height: anchorFrame.height
            )
        let openingFrame = MenuPlacement.openingFrame(
            anchor: anchorForPlacement,
            menuSize: naturalSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: false
        )
        PointerHoverSession.resyncHoverForMenuRelay(
            on: .workbenchPage,
            in: appState.interfaceLayers
        )
        workbenchAccessibility?.clear()
        activeMenu = FileCardMenuState(
            cardID: cardID,
            anchorFrame: anchorFrame,
            menuFrame: openingFrame,
            items: items
        )
        highlight.open(
            selectablePositions: items.indices.filter { items[$0].isEnabled },
            allPositions: Array(items.indices)
        )
    }

    private func openContextMenu(for cardID: String, at point: CGPoint, items: [FileCardMenuItem]) {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let measureStartedAt = ProcessInfo.processInfo.systemUptime
        let naturalSize = measuredMenuSize(for: items)
        let measureMs = max(0, (ProcessInfo.processInfo.systemUptime - measureStartedAt) * 1_000)
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "file_card_context_menu",
            trigger: "right_click",
            startedAt: startedAt,
            measureMs: measureMs
        )
        let container = CGRect(origin: .zero, size: viewportSize)
        let openingFrame = MenuPlacement.openingFrame(
            anchor: CGRect(origin: point, size: .zero),
            menuSize: naturalSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: false
        )
        PointerHoverSession.resyncHoverForMenuRelay(
            on: .workbenchPage,
            in: appState.interfaceLayers
        )
        workbenchAccessibility?.clear()
        activeMenu = FileCardMenuState(
            cardID: cardID,
            anchorFrame: nil,
            menuFrame: openingFrame,
            items: items
        )
        highlight.open(
            selectablePositions: items.indices.filter { items[$0].isEnabled },
            allPositions: Array(items.indices)
        )
    }

    private func dismissMenu(openedAs id: UUID? = nil) {
        if let id, activeMenu?.id != id {
            return
        }
        activeMenu = nil
        highlight.close()
    }

    private func activateHighlightedItem(in menu: FileCardMenuState) -> Bool {
        guard let position = highlight.activeTriggerPosition,
              menu.items.indices.contains(position),
              menu.items[position].isEnabled
        else {
            return false
        }
        let item = menu.items[position]
        dismissMenu()
        item.action()
        return true
    }

    private func measuredMenuSize(for items: [FileCardMenuItem]) -> CGSize {
        let host = NSHostingView(
            rootView: FileCardMenuPopover(
                items: items,
                highlight: highlight,
                onDismiss: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    // MARK: - Level 1: Roots

    private func rootContent(
        emptyMinHeight: CGFloat,
        accessibility: WorkbenchAccessibilityCoordinator?
    ) -> some View {
        folderRegion(emptyMinHeight: emptyMinHeight, accessibility: accessibility)
            .onAppear {
                if !indexing.isDatabaseOperationActive {
                    indexing.clearTransientNotice()
                }
            }
            .onDisappear {
                indexing.clearTransientNotice()
            }
    }

    /// Only one library task exists at a time, so every control that would
    /// start one waits while one does. The developer-only compaction writes
    /// the same rows without being a task, so they wait for it too.
    private var isFolderOperationBlocked: Bool {
        tasks.hasLibraryTask || indexing.databaseMaintenanceStatus.isCompacting
    }

    private var addFolderMenuItems: [FileCardMenuItem] {
        [
            FileCardMenuItem(
                title: L("file.add_folder.local"),
                icon: .folder,
                isEnabled: !isFolderOperationBlocked && !isChoosingFolder,
                isDestructive: false,
                action: {
                    chooseFolder()
                }
            ),
            FileCardMenuItem(
                title: L("file.add_folder.webdav"),
                icon: .folderWebdav,
                isEnabled: !isFolderOperationBlocked,
                isDestructive: false,
                action: {
                    appState.openWebDAVFolderDialog()
                }
            ),
            FileCardMenuItem(
                title: L("file.add_folder.smb"),
                icon: .folderSmb,
                isEnabled: !isFolderOperationBlocked,
                isDestructive: false,
                action: {
                    appState.openSMBFolderDialog()
                }
            ),
            FileCardMenuItem(
                title: L("file.add_folder.ftp"),
                icon: .folderFtp,
                isEnabled: !isFolderOperationBlocked,
                isDestructive: false,
                action: {
                    appState.openFTPFolderDialog()
                }
            ),
            FileCardMenuItem(
                title: L("file.add_folder.nfs"),
                icon: .folderNfs,
                isEnabled: !isFolderOperationBlocked,
                isDestructive: false,
                action: {
                    appState.openNFSFolderDialog()
                }
            )
        ]
    }

    private func actionRow(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        let isAddFolderDisabled = isFolderOperationBlocked || isChoosingFolder
        let isIndexNowDisabled = indexing.selectedFolders.isEmpty || isFolderOperationBlocked

        return HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchButton(
                title: L("settings.library.add_folder"),
                icon: .folderPlus,
                isOpen: activeMenu?.cardID == Self.addFolderMenuID,
                isFocused: accessibility?.isFocused(.fileAddFolderButton) == true
            ) {
                toggleMenu(
                    for: Self.addFolderMenuID,
                    anchorFrame: addFolderButtonAnchorFrame,
                    items: addFolderMenuItems
                )
            }
            .disabled(isAddFolderDisabled)
            .workbenchTooltip(
                scenarioID: "disabled.file.add_folder",
                isActive: isAddFolderDisabled,
                label: L("tooltip.disabled.file.task_or_compaction_running")
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: WorkbenchDropdownAnchorPreferenceKey.self,
                            value: [Self.addFolderMenuID: geo.frame(in: .named(Self.fileCardCoordinateSpaceName))]
                        )
                }
            )
            .onAppear {
                accessibility?.onToggleFileAddFolderMenu = {
                    guard !(isFolderOperationBlocked || isChoosingFolder) else { return }
                    toggleMenu(
                        for: Self.addFolderMenuID,
                        anchorFrame: addFolderButtonAnchorFrame,
                        items: addFolderMenuItems
                    )
                }
            }
            .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { anchors in
                if let frame = anchors[Self.addFolderMenuID], frame != .zero {
                    addFolderButtonAnchorFrame = frame
                    accessibility?.onToggleFileAddFolderMenu = {
                        guard !(isFolderOperationBlocked || isChoosingFolder) else { return }
                        toggleMenu(
                            for: Self.addFolderMenuID,
                            anchorFrame: frame,
                            items: addFolderMenuItems
                        )
                    }
                }
            }

            WorkbenchButton(
                title: L("settings.library.index_now"),
                icon: .arrowClockwise,
                isFocused: accessibility?.isFocused(.fileIndexNowButton) == true
            ) {
                appState.indexAllFolders()
            }
            .disabled(isIndexNowDisabled)
            .workbenchTooltip(
                scenarioID: "disabled.file.index_now",
                isActive: isIndexNowDisabled,
                label: isFolderOperationBlocked
                    ? L("tooltip.disabled.file.task_or_compaction_running")
                    : L("tooltip.disabled.file.index_now.no_folder")
            )
        }
    }

    @ViewBuilder
    private func folderRegion(
        emptyMinHeight: CGFloat,
        accessibility: WorkbenchAccessibilityCoordinator?
    ) -> some View {
        let folders = FileFolderGroupingResolver.rootFolders(for: indexing.selectedFolders)

        if folders.isEmpty {
            WorkbenchEmptyHint(
                icon: .folder,
                title: L("settings.library.empty_title"),
                message: L("settings.library.empty_message")
            )
            .frame(minHeight: emptyMinHeight)
        } else {
            VStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                ForEach(folders, id: \.self) { folder in
                    let rootPath = folder.mediaPath
                    let title = IndexingStore.displayName(for: folder)
                    let subtitle = FileFolderGroupingResolver.rootSubtitle(for: folder)
                    let items = [
                        FileCardMenuItem(
                            title: L("file_detail.get_info"),
                            icon: .info,
                            isEnabled: true,
                            isDestructive: false,
                            action: {
                                appState.requestRootFolderDetail(for: folder)
                            }
                        ),
                        FileCardMenuItem(
                            title: L("file.menu.rename_this_folder"),
                            icon: .pencilSimple,
                            isEnabled: !isFolderOperationBlocked,
                            isDestructive: false,
                            action: {
                                appState.requestRootFolderRename(folder)
                            }
                        ),
                        FileCardMenuItem(
                            title: L("file.menu.index_this_folder"),
                            icon: .arrowClockwise,
                            isEnabled: !isFolderOperationBlocked,
                            isDestructive: false,
                            action: {
                                appState.indexFolder(folder)
                            }
                        ),
                        FileCardMenuItem(
                            title: L("file.menu.remove_this_folder"),
                            icon: .folderMinus,
                            isEnabled: !isFolderOperationBlocked,
                            isDestructive: true,
                            action: {
                                requestRemoval(of: folder)
                            }
                        )
                    ]

                    WorkbenchFileCard(
                        cardID: rootPath,
                        icon: FileFolderGroupingResolver.folderIcon(for: folder),
                        title: title,
                        subtitle: subtitle,
                        showsChevron: true,
                        isCardFocused: accessibility?.isFocused(.fileCard(rootPath)) == true,
                        isActionFocused: accessibility?.isFocused(.fileCardActionButton(rootPath)) == true,
                        onTap: {
                            appState.loadFileSubfolders(rootPath: rootPath)
                            appState.workbenchLayout.navigate(
                                to: .fileFolder(rootPath: rootPath)
                            )
                        },
                        menuItems: items,
                        isCardMenuOpen: activeMenu?.cardID == rootPath,
                        isButtonMenuOpen: activeMenu?.cardID == rootPath && activeMenu?.isButtonAnchored == true,
                        onOpenButtonMenu: { anchorFrame in
                            toggleMenu(for: rootPath, anchorFrame: anchorFrame, items: items)
                        },
                        onOpenContextMenu: { point in
                            openContextMenu(for: rootPath, at: point, items: items)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Level 2: Subfolders & Direct Content

    @ViewBuilder
    private func subfolderContent(
        rootPath: String,
        emptyMinHeight: CGFloat,
        accessibility: WorkbenchAccessibilityCoordinator?
    ) -> some View {
        let allFolders = library.fileSubfolders(for: rootPath)
        let directObjects = library.fileObjects(for: rootPath)
        let partition = FileFolderGroupingResolver.level2Partition(
            folders: allFolders,
            objects: directObjects,
            rootPath: rootPath
        )
        let subfolderStatus = library.fileSubfolderStatus(for: rootPath)
        let directObjectStatus = library.fileObjectStatus(for: rootPath)
        let isLoading: Bool = {
            if case .loading = subfolderStatus { return true }
            if case .loading = directObjectStatus { return true }
            return false
        }()

        Group {
            if appState.isWorkbenchRouteUnknown(.fileFolder(rootPath: rootPath)) {
                WorkbenchEmptyHint(
                    icon: .folderQuestion,
                    message: L("library.folder.not_found")
                )
                .frame(minHeight: emptyMinHeight)
            } else if partition.subfolders.isEmpty && partition.directEpisodeGroups.isEmpty {
                if isLoading {
                    WorkbenchSpinner()
                        .frame(maxWidth: .infinity, minHeight: emptyMinHeight, alignment: .center)
                } else {
                    WorkbenchEmptyHint(
                        icon: .folder,
                        message: L("file.empty_folder_items")
                    )
                    .frame(minHeight: emptyMinHeight)
                }
            } else {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                    if !partition.subfolders.isEmpty {
                        VStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                            ForEach(partition.subfolders) { folder in
                                let title = URL.fromMediaPath(folder.folderPath).lastPathComponent
                                let items = [
                                    FileCardMenuItem(
                                        title: L("file_detail.get_info"),
                                        icon: .info,
                                        isEnabled: true,
                                        isDestructive: false,
                                        action: {
                                            appState.requestSubfolderDetail(for: folder.folderPath)
                                        }
                                    ),
                                    FileCardMenuItem(
                                        title: L("file.menu.rename_this_folder"),
                                        icon: .pencilSimple,
                                        isEnabled: !isFolderOperationBlocked,
                                        isDestructive: false,
                                        action: {
                                            appState.requestFolderRename(folder)
                                        }
                                    )
                                ]

                                WorkbenchFileCard(
                                    cardID: folder.folderPath,
                                    icon: FileFolderGroupingResolver.folderIcon(forFolderPath: folder.folderPath),
                                    title: title,
                                    subtitle: FileFolderGroupingResolver.subfolderSubtitle(for: folder.folderPath),
                                    showsChevron: true,
                                    isCardFocused: accessibility?.isFocused(.fileCard(folder.folderPath)) == true,
                                    isActionFocused: accessibility?.isFocused(.fileCardActionButton(folder.folderPath)) == true,
                                    onTap: {
                                        appState.loadFileObjects(folderPath: folder.folderPath)
                                        appState.workbenchLayout.navigate(
                                            to: .fileFiles(rootPath: rootPath, folderPath: folder.folderPath)
                                        )
                                    },
                                    menuItems: items,
                                    isCardMenuOpen: activeMenu?.cardID == folder.folderPath,
                                    isButtonMenuOpen: activeMenu?.cardID == folder.folderPath && activeMenu?.isButtonAnchored == true,
                                    onOpenButtonMenu: { anchorFrame in
                                        toggleMenu(for: folder.folderPath, anchorFrame: anchorFrame, items: items)
                                    },
                                    onOpenContextMenu: { point in
                                        openContextMenu(for: folder.folderPath, at: point, items: items)
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    if !partition.directEpisodeGroups.isEmpty {
                        episodeGroupsList(
                            objects: partition.directEpisodeGroups,
                            folderPath: rootPath,
                            accessibility: accessibility
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .task(id: "\(rootPath)|\(library.fileTreeRevision)") {
            appState.hydrateFileSubfoldersAsync(rootPath: rootPath)
        }
    }

    // MARK: - Level 3: Files

    @ViewBuilder
    private func filesContent(
        rootPath: String,
        folderPath: String,
        emptyMinHeight: CGFloat,
        accessibility: WorkbenchAccessibilityCoordinator?
    ) -> some View {
        let objects = library.fileObjects(for: folderPath)
        let episodeGroups = FileFolderGroupingResolver.displayableEpisodeGroups(from: objects)
        let status = library.fileObjectStatus(for: folderPath)

        Group {
            if appState.isWorkbenchRouteUnknown(.fileFiles(rootPath: rootPath, folderPath: folderPath)) {
                WorkbenchEmptyHint(
                    icon: .folderQuestion,
                    message: L("library.folder.not_found")
                )
                .frame(minHeight: emptyMinHeight)
            } else if episodeGroups.isEmpty {
                if case .loading = status {
                    WorkbenchSpinner()
                        .frame(maxWidth: .infinity, minHeight: emptyMinHeight, alignment: .center)
                } else {
                    WorkbenchEmptyHint(
                        icon: .folderQuestion,
                        message: L("file.empty_folder_items")
                    )
                    .frame(minHeight: emptyMinHeight)
                }
            } else {
                episodeGroupsList(
                    objects: episodeGroups,
                    folderPath: folderPath,
                    accessibility: accessibility
                )
            }
        }
        .task(id: "\(folderPath)|\(library.fileTreeRevision)") {
            appState.hydrateFileObjectsAsync(folderPath: folderPath)
        }
    }

    // MARK: - Episode Groups (Unified Card: Header Bar + Full-Width Dividers + File Rows)

    private func episodeGroupsList(
        objects: [IndexedContentObject],
        folderPath: String,
        accessibility: WorkbenchAccessibilityCoordinator?
    ) -> some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            ForEach(objects) { object in
                VStack(alignment: .leading, spacing: 0) {
                    Text(object.displayTitle)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: WorkbenchControlMetrics.redesignFontWeightControl
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
                        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: WorkbenchControlMetrics.redesignHeight,
                            alignment: .leading
                        )
                        .background(WorkbenchRedesignColors.fileGroupHeaderBg)

                    Rectangle()
                        .fill(WorkbenchRedesignColors.borderDivider)
                        .frame(height: WorkbenchControlMetrics.redesignControlBorderWidth)

                    if !object.videoPath.isEmpty {
                        let videoItems = [
                            FileCardMenuItem(
                                title: L("file_detail.get_info"),
                                icon: .info,
                                isEnabled: true,
                                isDestructive: false,
                                action: {
                                    appState.requestVideoDetail(for: object.videoPath)
                                }
                            ),
                            FileCardMenuItem(
                                title: L("rename.files"),
                                icon: .pencilSimple,
                                isEnabled: !isFolderOperationBlocked,
                                isDestructive: false,
                                action: {
                                    appState.requestFileGroupRename(object)
                                }
                            )
                        ]

                        WorkbenchFileCard(
                            cardID: object.videoPath,
                            icon: .video,
                            title: object.videoName,
                            subtitle: FileSizeFormatter.format(bytes: object.fileSize),
                            showsChevron: false,
                            showsCardChrome: false,
                            isCardFocused: false,
                            isActionFocused: accessibility?.isFocused(.fileRowActionButton(object.videoPath)) == true,
                            onTap: nil,
                            menuItems: videoItems,
                            isCardMenuOpen: activeMenu?.cardID == object.videoPath,
                            isButtonMenuOpen: activeMenu?.cardID == object.videoPath && activeMenu?.isButtonAnchored == true,
                            onOpenButtonMenu: { anchorFrame in
                                toggleMenu(for: object.videoPath, anchorFrame: anchorFrame, items: videoItems)
                            },
                            onOpenContextMenu: { point in
                                openContextMenu(for: object.videoPath, at: point, items: videoItems)
                            }
                        )
                    }

                    ForEach(Array(object.subtitles.enumerated()), id: \.element.id) { index, subtitle in
                        if !object.videoPath.isEmpty || index > 0 {
                            Rectangle()
                                .fill(WorkbenchRedesignColors.borderDivider)
                                .frame(height: WorkbenchControlMetrics.redesignControlBorderWidth)
                        }

                        let subtitleItems = [
                            FileCardMenuItem(
                                title: L("file_detail.get_info"),
                                icon: .info,
                                isEnabled: true,
                                isDestructive: false,
                                action: {
                                    appState.requestSubtitleDetail(for: subtitle.path)
                                }
                            ),
                            FileCardMenuItem(
                                title: L("rename.files"),
                                icon: .pencilSimple,
                                isEnabled: !isFolderOperationBlocked,
                                isDestructive: false,
                                action: {
                                    appState.requestFileGroupRename(object)
                                }
                            )
                        ]

                        WorkbenchFileCard(
                            cardID: subtitle.path,
                            icon: .subtitles,
                            title: subtitle.name,
                            subtitle: FileSizeFormatter.format(bytes: subtitle.fileSize),
                            showsChevron: false,
                            showsCardChrome: false,
                            isCardFocused: false,
                            isActionFocused: accessibility?.isFocused(.fileRowActionButton(subtitle.path)) == true,
                            onTap: nil,
                            menuItems: subtitleItems,
                            isCardMenuOpen: activeMenu?.cardID == subtitle.path,
                            isButtonMenuOpen: activeMenu?.cardID == subtitle.path && activeMenu?.isButtonAnchored == true,
                            onOpenButtonMenu: { anchorFrame in
                                toggleMenu(for: subtitle.path, anchorFrame: anchorFrame, items: subtitleItems)
                            },
                            onOpenContextMenu: { point in
                                openContextMenu(for: subtitle.path, at: point, items: subtitleItems)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(WorkbenchRedesignColors.tableBg)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        WorkbenchRedesignColors.borderControl,
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Removal & Selection

    private func requestRemoval(of folder: URL) {
        appState.confirmation.session = WorkbenchConfirmationSession(
            title: L("settings.library.remove_folder_title"),
            message: L(
                "settings.library.remove_folder_message",
                IndexingStore.displayName(for: folder)
            ),
            destructiveTitle: L("common.remove"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                appState.removeFolder(folder)
                appState.confirmation.session = nil
            },
            onCancel: {
                appState.confirmation.session = nil
            }
        )
    }

    private func chooseFolder() {
        let startedAt = DebugInteractionLatencyProbe.now()
        guard !isChoosingFolder else {
            return
        }

        isChoosingFolder = true
        let panel = NSOpenPanel()
        panel.title = L("settings.library.choose_folder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        let panelPresentedAt = DebugInteractionLatencyProbe.now()

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            isChoosingFolder = false
            DebugInteractionLatencyProbe.recordSystemFilePanel(
                panelType: "NSOpenPanel",
                trigger: "file_choose_local_folder",
                mode: "sheet_or_modal",
                startedAt: startedAt,
                panelPresentedAt: panelPresentedAt,
                didSelect: response == .OK
            )
            guard response == .OK, let folder = panel.url else {
                return
            }

            appState.addFolder(folder)
        }

        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
            return
        }

        completion(panel.runModal())
    }

    // MARK: - Breadcrumb & Status

    private var breadcrumbNodes: [FileBreadcrumbNode] {
        FileBreadcrumbResolver.nodes(
            for: routeState.currentRoute,
            folderCount: indexing.selectedFolders.count,
            singularRootTitle: L("file.all_folders.one"),
            pluralRootTitle: L("file.all_folders.other")
        )
    }

    private var rootFoldersHeaderRow: some View {
        let folders = FileFolderGroupingResolver.rootFolders(for: indexing.selectedFolders)

        return Text(
            FileBreadcrumbResolver.allFoldersTitle(
                folderCount: folders.count,
                singularTitle: L("file.all_folders.one"),
                pluralTitle: L("file.all_folders.other")
            )
        )
        .font(.system(
            size: WorkbenchControlMetrics.redesignFontSizeBody,
            weight: .semibold
        ))
        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func breadcrumbRow(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ForEach(Array(breadcrumbNodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    AppIconImage(
                        .caretRight,
                        size: WorkbenchControlMetrics.redesignBreadcrumbSeparatorSize
                    )
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                }

                if let destination = node.destination {
                    BreadcrumbLink(
                        title: node.title,
                        isFocused: accessibility?.isFocused(.fileBreadcrumb(node.id)) == true
                    ) {
                        appState.workbenchLayout.navigate(to: destination)
                    }
                } else {
                    Text(node.title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentStatusInfo: FileStatusInfo {
        FileStatusResolver.resolve(
            indexingStatus: indexing.indexingStatus,
            folderRemovalStatus: indexing.folderRemovalStatus,
            operationNotice: indexing.operationNotice,
            lastUpdatedDate: indexing.lastUpdatedDate
        )
    }

    private var statusTapAction: (() -> Void)? {
        if case .idle = currentStatusInfo, indexing.lastUpdatedDate == nil {
            return nil
        }
        let statusInfo = currentStatusInfo
        return {
            appState.openFileStatusTaskDetail(for: statusInfo)
        }
    }

    private func statusIndicator(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        let info = currentStatusInfo
        let text: String
        var icon: AppIcon?
        var iconCustomView: AnyView?
        let textColor: Color
        let iconColor: Color

        switch info {
        case .completed(let value):
            text = value
            icon = .checkCircle
            textColor = WorkbenchRedesignColors.successText
            iconColor = WorkbenchRedesignColors.successText
        case .inProgress(let value):
            text = value
            iconCustomView = AnyView(WorkbenchSpinner())
            textColor = WorkbenchRedesignColors.textSecondary
            iconColor = WorkbenchRedesignColors.textSecondary
        case .failed(let value):
            text = value
            icon = .warning
            textColor = WorkbenchRedesignColors.dangerText
            iconColor = WorkbenchRedesignColors.dangerText
        case .idle(let value):
            text = value
            textColor = WorkbenchRedesignColors.textSecondary
            iconColor = WorkbenchRedesignColors.textSecondary
        }

        return WorkbenchStatusIndicator(
            text: text,
            icon: icon,
            textColor: textColor,
            iconColor: iconColor,
            iconCustomView: iconCustomView,
            isTextFocused: accessibility?.isFocused(.fileStatusIndicatorText) == true,
            onTapText: statusTapAction
        )
    }

    private func statusAndActionRow(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            actionRow(accessibility: accessibility)

            statusIndicator(accessibility: accessibility)

            Spacer(minLength: 0)
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }
}

struct BreadcrumbLink: View {
    let title: String
    var isFocused: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(
                    isHovered
                        ? WorkbenchRedesignColors.textPrimary
                        : WorkbenchRedesignColors.textSecondary
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .workbenchAccessibilityFocusRing(
                    isFocused: isFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }
}

typealias FileCardMenuItem = WorkbenchCardMenuItem
typealias FileCardMenuState = WorkbenchCardMenuState
typealias FileCardMenuPopover = WorkbenchCardMenuPopover


private struct WorkbenchFileCard: View {
    var cardID: String = ""
    let icon: AppIcon
    let title: String
    let subtitle: String
    let showsChevron: Bool
    var showsCardChrome: Bool = true
    var isCardFocused: Bool = false
    var isActionFocused: Bool = false
    let onTap: (() -> Void)?
    let menuItems: [FileCardMenuItem]
    let isCardMenuOpen: Bool
    let isButtonMenuOpen: Bool
    let onOpenButtonMenu: (CGRect) -> Void
    let onOpenContextMenu: (CGPoint) -> Void

    @Environment(\.interfaceLayers) private var interfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    @State private var isHovered = false
    @State private var isPressed = false

    private var isLayerCovered: Bool {
        interfaceLayers?.isCovered(layerContext.layer) ?? layerContext.isCovered
    }

    private var rowCornerRadius: CGFloat {
        showsCardChrome ? WorkbenchControlMetrics.redesignCornerRadius : 0
    }

    private var cardBackgroundColor: Color {
        if onTap != nil && isPressed {
            return WorkbenchRedesignColors.fileFolderCardBgPressed
        }
        if isHovered || isCardMenuOpen {
            return WorkbenchRedesignColors.rowHover
        }
        return showsCardChrome ? WorkbenchRedesignColors.tableBg : Color.clear
    }

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchCardIcon(icon: icon)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(subtitle)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeCaption,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .allowsHitTesting(false)

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                GeometryReader { buttonProxy in
                    WorkbenchIconButton(
                        icon: .dotsThree,
                        isOpen: isButtonMenuOpen,
                        isFocused: isActionFocused,
                        hoverBackground: (isCardMenuOpen && !isButtonMenuOpen)
                            ? Color.clear
                            : WorkbenchRedesignColors.rowSelected,
                        pressedBackground: WorkbenchRedesignColors.rowActionBgPressed,
                        action: {
                            let frame = buttonProxy.frame(in: .named(WorkbenchFileView.fileCardCoordinateSpaceName))
                            onOpenButtonMenu(frame)
                        }
                    )
                    .onAppear {
                        guard !cardID.isEmpty else { return }
                        workbenchAccessibility?.registerFileCardAction(id: cardID) {
                            let frame = buttonProxy.frame(in: .named(WorkbenchFileView.fileCardCoordinateSpaceName))
                            onOpenButtonMenu(frame)
                        }
                    }
                    .onDisappear {
                        guard !cardID.isEmpty else { return }
                        workbenchAccessibility?.unregisterFileCardAction(id: cardID)
                    }
                }
                .frame(
                    width: WorkbenchControlMetrics.redesignIconButtonSize,
                    height: WorkbenchControlMetrics.redesignIconButtonSize
                )
                .opacity(isHovered || isCardMenuOpen || isActionFocused ? 1 : 0)
                .allowsHitTesting(isHovered || isCardMenuOpen || isActionFocused)

                if showsChevron {
                    AppIconImage(
                        .caretRight,
                        size: WorkbenchControlMetrics.redesignCardChevronSize
                    )
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .frame(
                        width: WorkbenchControlMetrics.redesignCardChevronSize,
                        height: WorkbenchControlMetrics.redesignIconButtonSize
                    )
                    .allowsHitTesting(false)
                }
            }
            .padding(.top, WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset)
        }
        .padding(WorkbenchControlMetrics.redesignSpacing4)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignCardBaselineHeight,
            alignment: .topLeading
        )
        .background {
            let shape = RoundedRectangle(
                cornerRadius: rowCornerRadius,
                style: .continuous
            )
            ZStack {
                shape.fill(cardBackgroundColor)

                WorkbenchAccessibilityScrollRevealProbe(isActive: isCardFocused || isActionFocused)

                if let onTap {
                    Button(action: onTap) {
                        Color.clear
                            .contentShape(shape)
                    }
                    .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
                    .focusable(false)
                }

                GeometryReader { cardProxy in
                    WorkbenchCardRightClickMonitor(
                        isEnabled: !isLayerCovered,
                        menuGate: interfaceLayers?.menuGate
                    ) { localPoint in
                        let frame = cardProxy.frame(in: .named(WorkbenchFileView.fileCardCoordinateSpaceName))
                        onOpenContextMenu(
                            CGPoint(
                                x: frame.minX + localPoint.x,
                                y: frame.minY + localPoint.y
                            )
                        )
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(
                cornerRadius: rowCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderControl,
                lineWidth: showsCardChrome ? WorkbenchControlMetrics.redesignControlBorderWidth : 0
            )
            .allowsHitTesting(false)
        )
        .workbenchAccessibilityFocusRing(
            isFocused: isCardFocused,
            cornerRadius: rowCornerRadius
        )
        .contentShape(RoundedRectangle(
            cornerRadius: rowCornerRadius,
            style: .continuous
        ))
        .onPointerHover { isHovered = $0 }
    }
}

enum FileFolderGroupingResolver {
    static func rootFolders(for selectedFolders: [URL]) -> [URL] {
        selectedFolders
    }

    static func folderIcon(for folder: URL) -> AppIcon {
        if folder.isWebDAVURL {
            return .folderWebdav
        }
        if folder.isSMBURL {
            return .folderSmb
        }
        if folder.isFTPURL {
            return .folderFtp
        }
        if folder.isNFSURL {
            return .folderNfs
        }
        return .folder
    }

    static func folderIcon(forFolderPath folderPath: String) -> AppIcon {
        if folderPath.isWebDAVPath {
            return .folderWebdav
        }
        if folderPath.isSMBPath {
            return .folderSmb
        }
        if folderPath.isFTPPath {
            return .folderFtp
        }
        if folderPath.isNFSPath {
            return .folderNfs
        }
        return .folder
    }

    static func rootSubtitle(for folder: URL) -> String {
        if folder.isWebDAVURL {
            let rawAddress = WebDAVConfigurationStore.shared.config(for: folder)?.address ?? folder.mediaPath
            return WebDAVAddress.decodedDisplayAddress(rawAddress)
        }
        if folder.isSMBURL {
            let rawAddress = SMBConfigurationStore.shared.config(for: folder)?.address ?? folder.mediaPath
            return SMBAddress.decodedDisplayAddress(rawAddress)
        }
        if folder.isFTPURL {
            let rawAddress = FTPConfigurationStore.shared.config(for: folder)?.address ?? folder.mediaPath
            return FTPAddress.decodedDisplayAddress(rawAddress)
        }
        if folder.isNFSURL {
            let rawAddress = NFSConfigurationStore.shared.config(for: folder)?.address ?? folder.mediaPath
            return NFSAddress.decodedDisplayAddress(rawAddress)
        }
        return folder.path
    }

    static func subfolderSubtitle(for folderPath: String) -> String {
        if folderPath.isWebDAVPath {
            return WebDAVAddress.decodedDisplayAddress(folderPath)
        }
        if folderPath.isSMBPath {
            return SMBAddress.decodedDisplayAddress(folderPath)
        }
        if folderPath.isFTPPath {
            return FTPAddress.decodedDisplayAddress(folderPath)
        }
        if folderPath.isNFSPath {
            return NFSAddress.decodedDisplayAddress(folderPath)
        }
        return folderPath
    }

    static func level2Partition(
        folders: [IndexedContentFolder],
        objects: [IndexedContentObject],
        rootPath: String
    ) -> (subfolders: [IndexedContentFolder], directEpisodeGroups: [IndexedContentObject]) {
        let standardizedRoot = URL.fromMediaPath(rootPath).mediaPath
        let subfolders = folders.filter { folder in
            !folder.relativePath.isEmpty
                && URL.fromMediaPath(folder.folderPath).mediaPath != standardizedRoot
        }
        let directEpisodeGroups = displayableEpisodeGroups(from: objects)
        return (subfolders: subfolders, directEpisodeGroups: directEpisodeGroups)
    }

    static func displayableEpisodeGroups(
        from objects: [IndexedContentObject]
    ) -> [IndexedContentObject] {
        objects.filter { !$0.videoPath.isEmpty || !$0.subtitles.isEmpty }
    }
}

struct FileBreadcrumbNode: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let destination: WorkbenchRoute?
}

enum FileBreadcrumbResolver {
    static func allFoldersTitle(
        folderCount: Int,
        singularTitle: String,
        pluralTitle: String
    ) -> String {
        folderCount > 1 ? pluralTitle : singularTitle
    }

    static func nodes(
        for route: WorkbenchRoute,
        folderCount: Int,
        singularRootTitle: String,
        pluralRootTitle: String
    ) -> [FileBreadcrumbNode] {
        let rootHeaderTitle = allFoldersTitle(
            folderCount: folderCount,
            singularTitle: singularRootTitle,
            pluralTitle: pluralRootTitle
        )
        switch route {
        case .fileFolder(let rootPath):
            let rootURL = URL.fromMediaPath(rootPath)
            let allNode = FileBreadcrumbNode(
                id: "all",
                title: rootHeaderTitle,
                destination: .file
            )
            let rootName = IndexingStore.displayName(for: rootURL)
            let rootNode = FileBreadcrumbNode(
                id: "root",
                title: rootName,
                destination: nil
            )
            return [allNode, rootNode]

        case .fileFiles(let rootPath, let folderPath):
            let rootURL = URL.fromMediaPath(rootPath)
            let allNode = FileBreadcrumbNode(
                id: "all",
                title: rootHeaderTitle,
                destination: .file
            )
            let rootName = IndexingStore.displayName(for: rootURL)
            let rootNode = FileBreadcrumbNode(
                id: "root",
                title: rootName,
                destination: .fileFolder(rootPath: rootPath)
            )
            let folderName = URL.fromMediaPath(folderPath).lastPathComponent
            let folderNode = FileBreadcrumbNode(
                id: "folder",
                title: folderName,
                destination: nil
            )
            return [allNode, rootNode, folderNode]

        default:
            return []
        }
    }
}

enum FileStatusInfo: Equatable {
    case completed(String)
    case inProgress(String)
    case failed(String)
    case idle(String)
}

enum FileStatusResolver {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func resolve(
        indexingStatus: IndexingStatus,
        folderRemovalStatus: LibraryFolderRemovalStatus,
        operationNotice: DatabaseOperationNotice?,
        lastUpdatedDate: Date?
    ) -> FileStatusInfo {
        if case .removing(let folder) = folderRemovalStatus {
            return .inProgress(L("file.status.removing", IndexingStore.displayName(for: folder)))
        }

        switch indexingStatus {
        case .indexing(let folder):
            return .inProgress(L("file.status.indexing", IndexingStore.displayName(for: folder)))
        case .indexingAll:
            return .inProgress(L("file.status.indexing_all"))
        default:
            break
        }

        if let notice = operationNotice {
            switch notice {
            case .indexed(let folderName):
                return .completed(L("file.status.indexed", folderName))
            case .indexedAll:
                return .completed(L("file.status.indexed_all"))
            case .removed(let folderName):
                return .completed(L("file.status.removed", folderName))
            case .indexFailed(let folderName):
                return .failed(L("file.status.failed", folderName))
            case .removalFailed(let folderName):
                return .failed(L("file.status.removal_failed", folderName))
            }
        }

        if let date = lastUpdatedDate {
            return .idle(L("file.status.last_updated", dateFormatter.string(from: date)))
        } else {
            return .idle(L("file.status.last_updated_never"))
        }
    }
}

