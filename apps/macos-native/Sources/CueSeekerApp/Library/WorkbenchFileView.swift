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
    /// rename menus.
    @ObservedObject var tasks: TaskQueueStore
    @State private var isChoosingFolder = false

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
            if newRoute != .file {
                indexing.clearTransientNotice()
            } else if !indexing.isDatabaseOperationActive {
                indexing.clearTransientNotice()
            }
        }
        .task {
            appState.hydrateCompleteLibraryAsync()
        }
        .task(id: library.completeLibraryRevision) {
            appState.hydrateLibraryFileTreeAsync()
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
        }
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
                    WorkbenchFileCard(
                        icon: .folder,
                        title: folder.lastPathComponent,
                        subtitle: folder.path,
                        onTap: {
                            appState.workbenchLayout.navigate(
                                to: .fileFolder(rootPath: folder.standardizedFileURL.path)
                            )
                        }
                    ) {
                        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                            WorkbenchButton(
                                title: L("rename.folder"),
                                icon: .pencilSimple,
                                isRedesign: true
                            ) {
                                appState.requestRootFolderRename(folder)
                            }
                            .disabled(isFolderOperationBlocked)

                            WorkbenchDestructiveButton(
                                title: L("common.remove"),
                                icon: .minusCircle
                            ) {
                                requestRemoval(of: folder)
                            }
                            .disabled(isFolderOperationBlocked)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Level 2: Subfolders

    @ViewBuilder
    private func subfolderContent(rootPath: String) -> some View {
        let root = library.fileTreeRoots.first {
            $0.path == rootPath || URL(fileURLWithPath: $0.path).standardizedFileURL.path == URL(fileURLWithPath: rootPath).standardizedFileURL.path
        }
        let folders = root?.folders ?? []

        if folders.isEmpty {
            if case .loading = library.fileTreeStatus {
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

                    WorkbenchFileCard(
                        icon: .folder,
                        title: title,
                        subtitle: folder.folderPath,
                        onTap: {
                            appState.workbenchLayout.navigate(
                                to: .fileFiles(rootPath: rootPath, folderPath: folder.folderPath)
                            )
                        }
                    ) {
                        WorkbenchButton(
                            title: L("rename.folder"),
                            icon: .pencilSimple,
                            isRedesign: true
                        ) {
                            appState.requestFolderRename(folder)
                        }
                        .disabled(isFolderOperationBlocked)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Level 3: Files

    @ViewBuilder
    private func filesContent(rootPath: String, folderPath: String) -> some View {
        let folder = library.fileTreeRoots
            .first {
                $0.path == rootPath || URL(fileURLWithPath: $0.path).standardizedFileURL.path == URL(fileURLWithPath: rootPath).standardizedFileURL.path
            }?
            .folders
            .first { $0.folderPath == folderPath }

        let objects = folder?.objects ?? []
        let displayableItemsCount = objects.reduce(0) { count, object in
            count + (object.videoPath.isEmpty ? 0 : 1) + object.subtitles.count
        }

        if displayableItemsCount == 0 {
            if case .loading = library.fileTreeStatus {
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
                        WorkbenchFileCard(
                            icon: .video,
                            title: object.videoName,
                            subtitle: FileSizeFormatter.format(bytes: object.fileSize),
                            onTap: nil
                        ) {
                            WorkbenchButton(
                                title: L("rename.files"),
                                icon: .pencilSimple,
                                isRedesign: true
                            ) {
                                appState.requestFileGroupRename(object)
                            }
                            .disabled(isFolderOperationBlocked)
                        }
                    }

                    ForEach(object.subtitles) { subtitle in
                        WorkbenchFileCard(
                            icon: .subtitles,
                            title: subtitle.name,
                            subtitle: FileSizeFormatter.format(bytes: subtitle.fileSize),
                            onTap: nil
                        ) {
                            WorkbenchButton(
                                title: L("rename.files"),
                                icon: .pencilSimple,
                                isRedesign: true
                            ) {
                                appState.requestFileGroupRename(object)
                            }
                            .disabled(isFolderOperationBlocked)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
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

private struct WorkbenchFileCard<Trailing: View>: View {
    let icon: AppIcon
    let title: String
    let subtitle: String
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            AppIconImage(icon, size: WorkbenchControlMetrics.redesignSizeTaskCardIcon)
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)

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

            trailing()
        }
        .padding(WorkbenchControlMetrics.redesignSpacing4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgDialog)
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

