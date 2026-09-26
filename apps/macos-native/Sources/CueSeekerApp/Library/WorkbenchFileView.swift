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
        GeometryReader { geometry in
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    switch routeState.currentRoute {
                    case .fileFolder(let rootPath):
                        subfolderContent(rootPath: rootPath)
                    case .fileFiles(let rootPath, let folderPath):
                        filesContent(rootPath: rootPath, folderPath: folderPath)
                    default:
                        rootContent
                    }
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
        }
        .background(WorkbenchRedesignColors.bgSurface)
        .task {
            appState.hydrateCompleteLibraryAsync()
        }
        .task(id: library.completeLibraryRevision) {
            appState.hydrateLibraryFileTreeAsync()
        }
    }

    // MARK: - Level 1: Roots

    private var rootContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageDescription

            actionRow
                .padding(.top, WorkbenchControlMetrics.redesignSpacing4)

            // Nothing has been indexed yet: the status region takes no
            // room at all rather than reserving an empty band.
            if hasStatus {
                statusView
                    .padding(.top, WorkbenchControlMetrics.redesignSpacing4)
            }

            folderRegion
                .padding(.top, WorkbenchControlMetrics.redesignSpacing6)
        }
    }

    /// Only one library task exists at a time, so every control that would
    /// start one waits while one does. The developer-only compaction writes
    /// the same rows without being a task, so they wait for it too.
    private var isFolderOperationBlocked: Bool {
        tasks.hasLibraryTask || indexing.databaseMaintenanceStatus.isCompacting
    }

    private var pageDescription: some View {
        Text(L("file.description"))
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular
            ))
            .foregroundStyle(WorkbenchRedesignColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                                title: L("common.rename"),
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
            if case .loading = library.fileTreeStatus, library.fileTreeRoots.isEmpty {
                ProgressView()
                    .controlSize(.small)
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
                            title: L("common.rename"),
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

        if objects.isEmpty {
            if case .loading = library.fileTreeStatus, library.fileTreeRoots.isEmpty {
                ProgressView()
                    .controlSize(.small)
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
                                title: L("common.rename"),
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
                                title: L("common.rename"),
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

    // MARK: - Status

    private var hasStatus: Bool {
        if appState.startupError != nil {
            return true
        }

        if indexing.folderRemovalStatus != .idle {
            return true
        }

        if indexing.removedFolderNotice != nil {
            return true
        }

        if indexing.indexingStatus != .idle {
            return true
        }

        return !indexing.auxiliaryFailures.isEmpty
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing2
        ) {
            if let startupError = appState.startupError {
                statusLine(
                    startupError,
                    icon: .warning,
                    color: WorkbenchRedesignColors.dangerText
                )
            }

            if case .removing(let folder) = indexing.folderRemovalStatus {
                progressLine(
                    L("settings.library.removing", folder.lastPathComponent)
                )
            } else if let removedFolder = indexing.removedFolderNotice {
                statusLine(
                    L("settings.library.removed", removedFolder.lastPathComponent),
                    icon: .checkCircle,
                    color: WorkbenchRedesignColors.successText
                )
            } else {
                switch indexing.indexingStatus {
                case .idle:
                    EmptyView()
                case .indexing(let folder):
                    progressLine(
                        L("settings.library.indexing", folder.lastPathComponent)
                    )
                case .indexingAll(let folder, let completedFolders, let totalFolders):
                    progressLine(
                        L(
                            "settings.library.indexing_folder",
                            completedFolders + 1,
                            totalFolders,
                            folder.lastPathComponent
                        )
                    )
                case .completed(let folder, let result):
                    completionBlock(
                        title: L("settings.library.indexed", folder.lastPathComponent),
                        result: result
                    )
                case .completedAll(let folderCount, let result):
                    completionBlock(
                        title: L("settings.library.indexed_folders", folderCount),
                        result: result
                    )
                case .failed(let folder, let message):
                    VStack(
                        alignment: .leading,
                        spacing: WorkbenchControlMetrics.redesignSpacing1
                    ) {
                        statusLine(
                            L("settings.library.index_failed", folder.lastPathComponent),
                            icon: .warning,
                            color: WorkbenchRedesignColors.dangerText
                        )
                        detailLine(message)
                    }
                }
            }

            ForEach(
                Array(indexing.auxiliaryFailures.enumerated()),
                id: \.offset
            ) { _, failure in
                statusLine(
                    failure.message,
                    icon: .warning,
                    color: WorkbenchRedesignColors.dangerText
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func completionBlock(
        title: String,
        result: SubtitleIndexingResult
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing1
        ) {
            statusLine(
                title,
                icon: .checkCircle,
                color: WorkbenchRedesignColors.successText
            )

            detailLine(indexingSummary(result))

            if !result.failedFiles.isEmpty {
                detailLine(
                    L(
                        "settings.library.files_failed",
                        result.failedFiles.count,
                        result.failedFiles[0].reason
                    )
                )
            }
        }
    }

    private func statusLine(
        _ text: String,
        icon: AppIcon,
        color: Color
    ) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            AppIconImage(icon, size: WorkbenchControlMetrics.redesignControlIconSize)

            Text(text)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
    }

    private func progressLine(_ text: String) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ProgressView()
                .controlSize(.small)

            Text(text)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
        }
    }

    private func detailLine(_ text: String) -> some View {
        Text(text)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: .regular
            ))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(
                .leading,
                WorkbenchControlMetrics.redesignControlIconSize
                    + WorkbenchControlMetrics.redesignSpacing2
            )
    }

    private func indexingSummary(_ result: SubtitleIndexingResult) -> String {
        [
            L("settings.library.scanned", result.scannedSubtitleFiles),
            L("settings.library.indexed_files", result.indexedSubtitleFiles),
            L("settings.library.entries", result.indexedSubtitleEntries),
            L("settings.library.unchanged", result.skippedUnchangedSubtitleFiles),
            L("settings.library.missing_videos", result.skippedMissingVideo),
            L("settings.library.unreadable", result.skippedUnreadableSubtitle)
        ].joined(separator: " · ")
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
            .fill(WorkbenchRedesignColors.settingsGroupBg)
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
