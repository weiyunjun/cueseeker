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
    @State private var isChoosingFolder = false
    @State private var activeMenu: FileCardMenuState?
    @State private var addFolderButtonAnchorFrame: CGRect = .zero
    @StateObject private var highlight = MenuHighlightModel()
    @State private var viewportSize: CGSize = .zero

    var body: some View {
        Group {
            switch routeState.currentRoute {
            case .fileFolder(let rootPath):
                fileScrollSurface(id: rootPath) {
                    subfolderContent(rootPath: rootPath)
                }
            case .fileFiles(let rootPath, let folderPath):
                fileScrollSurface(id: "\(rootPath)/\(folderPath)") {
                    filesContent(rootPath: rootPath, folderPath: folderPath)
                }
            default:
                fileScrollSurface(id: "root") {
                    rootContent
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
        }
    }

    private func fileScrollSurface<Content: View>(
        id: AnyHashable,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    statusAndActionRow
                        .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)

                    if !breadcrumbNodes.isEmpty {
                        breadcrumbRow
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                    } else if !indexing.selectedFolders.isEmpty {
                        rootFoldersHeaderRow
                            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                    }
                }
                .workbenchPageInlinePadding()
                .padding(.top, WorkbenchControlMetrics.redesignWorkbenchPageTopPadding)

                WorkbenchScrollView([.vertical]) {
                    content()
                        .workbenchPageInlinePadding()
                        .padding(.bottom, WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding)
                        .frame(width: geometry.size.width, alignment: .topLeading)
                }
                .id(id)
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
                                switch keyCode {
                                case 53:
                                    dismissMenu()
                                    return true
                                case 126:
                                    _ = highlight.moveHighlight(by: -1)
                                    return true
                                case 125:
                                    _ = highlight.moveHighlight(by: 1)
                                    return true
                                case 123, 124:
                                    return true
                                case 36, 76:
                                    return activateHighlightedItem(in: activeMenu)
                                default:
                                    return false
                                }
                            },
                            dismiss: { _ in
                                dismissMenu()
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
                    .zIndex(1000)
                }
            }
        }
    }

    private func toggleMenu(for cardID: String, anchorFrame: CGRect, items: [FileCardMenuItem]) {
        if activeMenu?.cardID == cardID {
            dismissMenu()
        } else {
            openMenu(for: cardID, anchorFrame: anchorFrame, items: items)
        }
    }

    private func openMenu(for cardID: String, anchorFrame: CGRect, items: [FileCardMenuItem]) {
        let naturalSize = measuredMenuSize(for: items)
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
        activeMenu = FileCardMenuState(
            cardID: cardID,
            anchorFrame: anchorFrame,
            menuFrame: openingFrame,
            items: items
        )
        highlight.open(
            selectablePositions: items.indices.filter { items[$0].isEnabled }
        )
    }

    private func dismissMenu() {
        activeMenu = nil
        highlight.close()
    }

    private func activateHighlightedItem(in menu: FileCardMenuState) -> Bool {
        guard let position = highlight.highlightedPosition,
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

    private var rootContent: some View {
        folderRegion
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
            )
        ]
    }

    private var actionRow: some View {
        let isAddFolderDisabled = isFolderOperationBlocked || isChoosingFolder
        let isIndexNowDisabled = indexing.selectedFolders.isEmpty || isFolderOperationBlocked

        return HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            WorkbenchButton(
                title: L("settings.library.add_folder"),
                icon: .folderPlus,
                isRedesign: true,
                isOpen: activeMenu?.cardID == Self.addFolderMenuID
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
            .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { anchors in
                if let frame = anchors[Self.addFolderMenuID], frame != .zero {
                    addFolderButtonAnchorFrame = frame
                }
            }

            WorkbenchButton(
                title: L("settings.library.index_now"),
                icon: .arrowClockwise,
                isRedesign: true
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
    private var folderRegion: some View {
        let folders = FileFolderGroupingResolver.rootFolders(for: indexing.selectedFolders)

        if folders.isEmpty {
            EmptyStateView(
                title: L("settings.library.empty_title"),
                icon: .folder,
                message: L("settings.library.empty_message")
            )
            .frame(maxWidth: .infinity, alignment: .top)
        } else {
            LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                ForEach(folders, id: \.self) { folder in
                    let rootPath = folder.mediaPath
                    let title = IndexingStore.displayName(for: folder)
                    let subtitle = FileFolderGroupingResolver.rootSubtitle(for: folder)
                    let items = [
                        FileCardMenuItem(
                            title: L("rename.folder"),
                            icon: .pencilSimple,
                            isEnabled: !isFolderOperationBlocked && !folder.isWebDAVURL,
                            isDestructive: false,
                            action: {
                                appState.requestRootFolderRename(folder)
                            }
                        ),
                        FileCardMenuItem(
                            title: L("common.remove"),
                            icon: .minusCircle,
                            isEnabled: !isFolderOperationBlocked,
                            isDestructive: true,
                            action: {
                                requestRemoval(of: folder)
                            }
                        )
                    ]

                    WorkbenchFileCard(
                        icon: FileFolderGroupingResolver.folderIcon(for: folder),
                        title: title,
                        subtitle: subtitle,
                        showsChevron: true,
                        onTap: {
                            appState.loadFileSubfolders(rootPath: rootPath)
                            appState.workbenchLayout.navigate(
                                to: .fileFolder(rootPath: rootPath)
                            )
                        },
                        menuItems: items,
                        isMenuOpen: activeMenu?.cardID == rootPath,
                        onOpenMenu: { anchorFrame in
                            toggleMenu(for: rootPath, anchorFrame: anchorFrame, items: items)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Level 2: Subfolders & Direct Content

    @ViewBuilder
    private func subfolderContent(rootPath: String) -> some View {
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
                WorkbenchEmptyHint(message: L("library.folder.not_found"))
                    .frame(maxWidth: .infinity, alignment: .top)
            } else if partition.subfolders.isEmpty && partition.directEpisodeGroups.isEmpty {
                if isLoading {
                    WorkbenchSpinner(size: 18)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    WorkbenchEmptyHint(message: L("file.empty_folder_items"))
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                    if !partition.subfolders.isEmpty {
                        LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                            ForEach(partition.subfolders) { folder in
                                let title = URL.fromMediaPath(folder.folderPath).lastPathComponent
                                let items = [
                                    FileCardMenuItem(
                                        title: L("rename.folder"),
                                        icon: .pencilSimple,
                                        isEnabled: !isFolderOperationBlocked && !folder.folderPath.isWebDAVPath,
                                        isDestructive: false,
                                        action: {
                                            appState.requestFolderRename(folder)
                                        }
                                    )
                                ]

                                WorkbenchFileCard(
                                    icon: FileFolderGroupingResolver.folderIcon(forFolderPath: folder.folderPath),
                                    title: title,
                                    subtitle: FileFolderGroupingResolver.subfolderSubtitle(for: folder.folderPath),
                                    showsChevron: true,
                                    onTap: {
                                        appState.loadFileObjects(folderPath: folder.folderPath)
                                        appState.workbenchLayout.navigate(
                                            to: .fileFiles(rootPath: rootPath, folderPath: folder.folderPath)
                                        )
                                    },
                                    menuItems: items,
                                    isMenuOpen: activeMenu?.cardID == folder.folderPath,
                                    onOpenMenu: { anchorFrame in
                                        toggleMenu(for: folder.folderPath, anchorFrame: anchorFrame, items: items)
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    if !partition.directEpisodeGroups.isEmpty {
                        episodeGroupsList(
                            objects: partition.directEpisodeGroups,
                            folderPath: rootPath
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
    private func filesContent(rootPath: String, folderPath: String) -> some View {
        let objects = library.fileObjects(for: folderPath)
        let episodeGroups = FileFolderGroupingResolver.displayableEpisodeGroups(from: objects)
        let status = library.fileObjectStatus(for: folderPath)

        Group {
            if appState.isWorkbenchRouteUnknown(.fileFiles(rootPath: rootPath, folderPath: folderPath)) {
                WorkbenchEmptyHint(message: L("library.folder.not_found"))
                    .frame(maxWidth: .infinity, alignment: .top)
            } else if episodeGroups.isEmpty {
                if case .loading = status {
                    WorkbenchSpinner(size: 18)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    WorkbenchEmptyHint(message: L("file.empty_folder_items"))
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                episodeGroupsList(objects: episodeGroups, folderPath: folderPath)
            }
        }
        .task(id: "\(folderPath)|\(library.fileTreeRevision)") {
            appState.hydrateFileObjectsAsync(folderPath: folderPath)
        }
    }

    // MARK: - Episode Groups (Display Title + Gray Rounded Container)

    private func episodeGroupsList(
        objects: [IndexedContentObject],
        folderPath: String
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            ForEach(objects) { object in
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Text(object.displayTitle)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: WorkbenchControlMetrics.redesignFontWeightControl
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
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
                                    isEnabled: !isFolderOperationBlocked && !object.videoPath.isWebDAVPath && !folderPath.isWebDAVPath,
                                    isDestructive: false,
                                    action: {
                                        appState.requestFileGroupRename(object)
                                    }
                                )
                            ]

                            WorkbenchFileCard(
                                icon: .video,
                                title: object.videoName,
                                subtitle: FileSizeFormatter.format(bytes: object.fileSize),
                                showsChevron: false,
                                onTap: nil,
                                menuItems: videoItems,
                                isMenuOpen: activeMenu?.cardID == object.videoPath,
                                onOpenMenu: { anchorFrame in
                                    toggleMenu(for: object.videoPath, anchorFrame: anchorFrame, items: videoItems)
                                }
                            )
                        }

                        ForEach(object.subtitles) { subtitle in
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
                                    isEnabled: !isFolderOperationBlocked && !subtitle.path.isWebDAVPath && !folderPath.isWebDAVPath,
                                    isDestructive: false,
                                    action: {
                                        appState.requestFileGroupRename(object)
                                    }
                                )
                            ]

                            WorkbenchFileCard(
                                icon: .subtitles,
                                title: subtitle.name,
                                subtitle: FileSizeFormatter.format(bytes: subtitle.fileSize),
                                showsChevron: false,
                                onTap: nil,
                                menuItems: subtitleItems,
                                isMenuOpen: activeMenu?.cardID == subtitle.path,
                                onOpenMenu: { anchorFrame in
                                    toggleMenu(for: subtitle.path, anchorFrame: anchorFrame, items: subtitleItems)
                                }
                            )
                        }
                    }
                    .padding(WorkbenchControlMetrics.redesignSpacing4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(
                            cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                            style: .continuous
                        )
                        .fill(WorkbenchRedesignColors.settingsGroupBg)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                            style: .continuous
                        )
                        .strokeBorder(
                            WorkbenchRedesignColors.borderDivider,
                            lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                        )
                    )
                }
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

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            isChoosingFolder = false
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

    private var breadcrumbRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ForEach(Array(breadcrumbNodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    AppIconImage(.caretRight, size: 12)
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                }

                if let destination = node.destination {
                    BreadcrumbLink(title: node.title) {
                        appState.workbenchLayout.navigate(to: destination)
                    }
                } else {
                    Text(node.title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                }
            }
        }
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

    @ViewBuilder
    private var statusIndicator: some View {
        switch currentStatusInfo {
        case .completed(let text):
            WorkbenchStatusIndicator(
                text,
                icon: .checkCircle,
                textColor: WorkbenchRedesignColors.successText,
                iconColor: WorkbenchRedesignColors.successText
            )
        case .inProgress(let text):
            WorkbenchStatusIndicator(
                text,
                iconCustomView: AnyView(
                    WorkbenchSpinner(size: WorkbenchControlMetrics.redesignButtonIconSize)
                        .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                ),
                textColor: WorkbenchRedesignColors.textSecondary
            )
        case .failed(let text):
            WorkbenchStatusIndicator(
                text,
                icon: .warning,
                textColor: WorkbenchRedesignColors.dangerText,
                iconColor: WorkbenchRedesignColors.dangerText
            )
        case .idle(let text):
            WorkbenchStatusIndicator(
                text,
                icon: .arrowClockwise,
                textColor: WorkbenchRedesignColors.textSecondary,
                iconColor: WorkbenchRedesignColors.textSecondary
            )
        }
    }

    private var statusAndActionRow: some View {
        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            actionRow

            statusIndicator

            Spacer(minLength: 0)
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }
}

struct BreadcrumbLink: View {
    let title: String
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
    let icon: AppIcon
    let title: String
    let subtitle: String
    let showsChevron: Bool
    let onTap: (() -> Void)?
    let menuItems: [FileCardMenuItem]
    let isMenuOpen: Bool
    let onOpenMenu: (CGRect) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchCardIcon(icon: icon)

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

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                GeometryReader { buttonProxy in
                    WorkbenchIconButton(
                        icon: .dotsThree,
                        isRedesign: true,
                        isOpen: isMenuOpen,
                        hoverBackground: WorkbenchRedesignColors.rowSelected,
                        action: {
                            let frame = buttonProxy.frame(in: .named(WorkbenchFileView.fileCardCoordinateSpaceName))
                            onOpenMenu(frame)
                        }
                    )
                }
                .frame(
                    width: WorkbenchControlMetrics.redesignIconButtonSize,
                    height: WorkbenchControlMetrics.redesignIconButtonSize
                )
                .opacity(isHovered || isMenuOpen ? 1 : 0)
                .allowsHitTesting(isHovered || isMenuOpen)

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
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(isHovered ? WorkbenchRedesignColors.rowHover : WorkbenchRedesignColors.tableBg)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderControl,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .contentShape(RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        ))
        .onPointerHover { isHovered = $0 }
        .onTapGesture {
            onTap?()
        }
    }
}

enum FileFolderGroupingResolver {
    static func rootFolders(for selectedFolders: [URL]) -> [URL] {
        selectedFolders
    }

    static func folderIcon(for folder: URL) -> AppIcon {
        folder.isWebDAVURL ? .folderWebdav : .folder
    }

    static func folderIcon(forFolderPath folderPath: String) -> AppIcon {
        folderPath.isWebDAVPath ? .folderWebdav : .folder
    }

    static func rootSubtitle(for folder: URL) -> String {
        if folder.isWebDAVURL {
            let rawAddress = WebDAVConfigurationStore.shared.config(for: folder)?.address ?? folder.mediaPath
            return WebDAVAddress.decodedDisplayAddress(rawAddress)
        }
        return folder.path
    }

    static func subfolderSubtitle(for folderPath: String) -> String {
        folderPath.isWebDAVPath
            ? WebDAVAddress.decodedDisplayAddress(folderPath)
            : folderPath
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
        formatter.dateFormat = "yy-MM-dd HH:mm"
        return formatter
    }()

    static func resolve(
        indexingStatus: IndexingStatus,
        folderRemovalStatus: LibraryFolderRemovalStatus,
        operationNotice: DatabaseOperationNotice?,
        lastUpdatedDate: Date?
    ) -> FileStatusInfo {
        if case .removing(let folder) = folderRemovalStatus {
            return .inProgress(L("file.status.removing", folder.lastPathComponent))
        }

        switch indexingStatus {
        case .indexing(let folder):
            return .inProgress(L("file.status.indexing", folder.lastPathComponent))
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

