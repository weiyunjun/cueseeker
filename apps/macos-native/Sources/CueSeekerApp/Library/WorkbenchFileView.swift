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

    /// Observed because any library task disables the folder controls and the
    /// rename menus.
    @ObservedObject var tasks: TaskQueueStore
    @State private var isChoosingFolder = false
    @State private var activeMenu: FileCardMenuState?
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
        .onChange(of: routeState.currentRoute) { newRoute in
            dismissMenu()
            if newRoute != .file {
                indexing.clearTransientNotice()
            } else if !indexing.isDatabaseOperationActive {
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
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    breadcrumbRow
                        .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)

                    content()
                }
                .workbenchPageInlinePadding()
                .padding(.top, WorkbenchControlMetrics.redesignWorkbenchPageTopPadding)
                .padding(.bottom, WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding)
                .frame(
                    width: max(
                        geometry.size.width,
                        AppShellLayout.pageContentMinimumWidth
                    ),
                    alignment: .topLeading
                )
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
            .id(id)
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
        let anchorForPlacement = CGRect(
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
        VStack(alignment: .leading, spacing: 0) {
            statusAndActionRow
                .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)

            folderRegion
        }
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

    private var actionRow: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchButton(
                title: L("settings.library.add_folder"),
                icon: .folderPlus,
                isRedesign: true
            ) {
                chooseFolder()
            }
            .disabled(isFolderOperationBlocked || isChoosingFolder)

            WorkbenchButton(
                title: L("settings.library.index_now"),
                icon: .arrowClockwise,
                isRedesign: true
            ) {
                appState.indexAllFolders()
            }
            .disabled(
                indexing.selectedFolders.isEmpty
                    || isFolderOperationBlocked
            )
        }
    }

    @ViewBuilder
    private var folderRegion: some View {
        if indexing.selectedFolders.isEmpty {
            EmptyStateView(
                title: L("settings.library.empty_title"),
                icon: .folder,
                message: L("settings.library.empty_message")
            )
            .frame(maxWidth: .infinity, alignment: .top)
        } else {
            LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                ForEach(indexing.selectedFolders, id: \.self) { folder in
                    let items = [
                        FileCardMenuItem(
                            title: L("rename.folder"),
                            icon: .pencilSimple,
                            isEnabled: !isFolderOperationBlocked,
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
                        icon: .folder,
                        title: folder.lastPathComponent,
                        subtitle: folder.path,
                        onTap: {
                            let rootPath = folder.standardizedFileURL.path
                            appState.loadFileSubfolders(rootPath: rootPath)
                            appState.workbenchLayout.navigate(
                                to: .fileFolder(rootPath: rootPath)
                            )
                        },
                        menuItems: items,
                        isMenuOpen: activeMenu?.cardID == folder.path,
                        onOpenMenu: { anchorFrame in
                            toggleMenu(for: folder.path, anchorFrame: anchorFrame, items: items)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Level 2: Subfolders

    @ViewBuilder
    private func subfolderContent(rootPath: String) -> some View {
        let folders = library.fileSubfolders(for: rootPath)
        let status = library.fileSubfolderStatus(for: rootPath)

        Group {
            if folders.isEmpty {
                if case .loading = status {
                    WorkbenchSpinner(size: 18)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    WorkbenchEmptyHint(message: L("file.empty_folder_items"))
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    ForEach(folders) { folder in
                        let isDirectContent = folder.relativePath.isEmpty || folder.folderPath == rootPath
                        let title = isDirectContent
                            ? (URL(fileURLWithPath: rootPath).lastPathComponent + L("file.direct_content_suffix"))
                            : URL(fileURLWithPath: folder.folderPath).lastPathComponent
                        let items = [
                            FileCardMenuItem(
                                title: L("rename.folder"),
                                icon: .pencilSimple,
                                isEnabled: !isFolderOperationBlocked,
                                isDestructive: false,
                                action: {
                                    appState.requestFolderRename(folder)
                                }
                            )
                        ]

                        WorkbenchFileCard(
                            icon: .folder,
                            title: title,
                            subtitle: folder.folderPath,
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
        }
        .task(id: "\(rootPath)|\(library.fileTreeRevision)") {
            appState.hydrateFileSubfoldersAsync(rootPath: rootPath)
        }
    }

    // MARK: - Level 3: Files

    @ViewBuilder
    private func filesContent(rootPath: String, folderPath: String) -> some View {
        let objects = library.fileObjects(for: folderPath)
        let status = library.fileObjectStatus(for: folderPath)
        let displayableItemsCount = objects.reduce(0) { count, object in
            count + (object.videoPath.isEmpty ? 0 : 1) + object.subtitles.count
        }

        Group {
            if displayableItemsCount == 0 {
                if case .loading = status {
                    WorkbenchSpinner(size: 18)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                } else {
                    WorkbenchEmptyHint(message: L("file.empty_folder_items"))
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    ForEach(objects) { object in
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
                                icon: .video,
                                title: object.videoName,
                                subtitle: FileSizeFormatter.format(bytes: object.fileSize),
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
                                    isEnabled: !isFolderOperationBlocked,
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
                                onTap: nil,
                                menuItems: subtitleItems,
                                isMenuOpen: activeMenu?.cardID == subtitle.path,
                                onOpenMenu: { anchorFrame in
                                    toggleMenu(for: subtitle.path, anchorFrame: anchorFrame, items: subtitleItems)
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .task(id: "\(folderPath)|\(library.fileTreeRevision)") {
            appState.hydrateFileObjectsAsync(folderPath: folderPath)
        }
    }

    // MARK: - Removal & Selection

    private func requestRemoval(of folder: URL) {
        appState.confirmation.session = WorkbenchConfirmationSession(
            title: L("settings.library.remove_folder_title"),
            message: L(
                "settings.library.remove_folder_message",
                folder.lastPathComponent
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
            homeTitle: L("file.breadcrumb.home"),
            directContentSuffix: L("file.direct_content_suffix")
        )
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
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            switch currentStatusInfo {
            case .completed(let text):
                AppIconImage(.checkCircle, size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.successText)
                Text(text)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.successText)
            case .inProgress(let text):
                WorkbenchSpinner(size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                Text(text)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
            case .failed(let text):
                AppIconImage(.warning, size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.dangerText)
                Text(text)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.dangerText)
            case .idle(let text):
                AppIconImage(.arrowClockwise, size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                Text(text)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
            }
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private var statusAndActionRow: some View {
        HStack(alignment: .center, spacing: 0) {
            statusIndicator

            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing4)

            actionRow
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }
}

private struct BreadcrumbLink: View {
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
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

typealias FileCardMenuItem = WorkbenchCardMenuItem
typealias FileCardMenuState = WorkbenchCardMenuState
typealias FileCardMenuPopover = WorkbenchCardMenuPopover


private struct WorkbenchFileCard: View {
    let icon: AppIcon
    let title: String
    let subtitle: String
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

struct FileBreadcrumbNode: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let destination: WorkbenchRoute?
}

enum FileBreadcrumbResolver {
    static func nodes(
        for route: WorkbenchRoute,
        homeTitle: String,
        directContentSuffix: String
    ) -> [FileBreadcrumbNode] {
        let homeNode = FileBreadcrumbNode(
            id: "home",
            title: homeTitle,
            destination: route == .file ? nil : .file
        )

        switch route {
        case .fileFolder(let rootPath):
            let rootName = URL(fileURLWithPath: rootPath).lastPathComponent
            let rootNode = FileBreadcrumbNode(
                id: "root",
                title: rootName,
                destination: nil
            )
            return [homeNode, rootNode]

        case .fileFiles(let rootPath, let folderPath):
            let rootName = URL(fileURLWithPath: rootPath).lastPathComponent
            let rootNode = FileBreadcrumbNode(
                id: "root",
                title: rootName,
                destination: .fileFolder(rootPath: rootPath)
            )

            let isDirectContent = folderPath == rootPath || folderPath.isEmpty
            let folderName = isDirectContent
                ? (rootName + directContentSuffix)
                : URL(fileURLWithPath: folderPath).lastPathComponent
            let folderNode = FileBreadcrumbNode(
                id: "folder",
                title: folderName,
                destination: nil
            )
            return [homeNode, rootNode, folderNode]

        default:
            return [homeNode]
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

