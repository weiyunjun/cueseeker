import AppKit
import CueSeekerCore
import SwiftUI

/// The File primary page: the Index tab owns the indexed root folders and the
/// indexing controls; the Edit tab shows every indexed folder and renames
/// folders and file groups in place.
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
        // The menu belongs to the page, not to one tab of it, so the page
        // hosts it; switching tabs closes it.
        LibraryCardContextMenuHost(
            interfaceID: routeState.selectedFileSection.rawValue
        ) { _ in
        GeometryReader { geometry in
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTabs

                    switch routeState.selectedFileSection {
                    case .index:
                        indexContent
                            .padding(.top, WorkbenchControlMetrics.redesignSpacing4)
                    case .edit:
                        editContent
                            .padding(.top, WorkbenchControlMetrics.redesignSpacing4)
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
        }
        .background(WorkbenchRedesignColors.bgSurface)
    }

    /// The same Tabs as the Recent page, flush with the content's left edge.
    private var sectionTabs: some View {
        WorkbenchTabs(
            items: WorkbenchFileSection.allCases.map {
                .init(
                    value: $0,
                    label: $0.label,
                    accessibilityIdentifier: "file-segment-\($0.rawValue)"
                )
            },
            selection: routeState.selectedFileSection,
            isLeadingEdgeAligned: true
        ) { section in
            appState.workbenchLayout.selectFileSection(section)
        }
    }

    // MARK: - Index

    private var indexContent: some View {
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
            LazyVStack(spacing: 0) {
                ForEach(indexing.selectedFolders, id: \.self) { folder in
                    folderRow(folder)

                    Rectangle()
                        .fill(WorkbenchRedesignColors.borderDivider)
                        .frame(height: WorkbenchControlMetrics.hairlineWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func folderRow(_ folder: URL) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            VStack(
                alignment: .leading,
                spacing: WorkbenchControlMetrics.redesignSpacing1
            ) {
                Text(folder.lastPathComponent)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                Text(folder.path)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeCaption,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            WorkbenchDestructiveButton(
                title: L("common.remove"),
                icon: .minusCircle
            ) {
                requestRemoval(of: folder)
            }
            .disabled(isFolderOperationBlocked)
        }
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing3)
    }

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

    // MARK: - Edit

    /// Every indexed folder at its full path, in the order the Metadata tree
    /// lists them with the root level removed. A root that holds pairs of its
    /// own is a folder like any other here. The roots are the outermost root
    /// of each group, and a group stands where its earliest-added root stands
    /// in the list.
    private var editFolders: [IndexedContentFolder] {
        let groupOrder = LibraryRootGroups.representatives(of: indexing.selectedFolders)
            .map(\.standardizedFileURL.path)
        return library.fileTreeRoots
            .enumerated()
            .sorted { lhs, rhs in
                let lhsOrder = groupOrder.firstIndex(of: lhs.element.path) ?? groupOrder.count
                let rhsOrder = groupOrder.firstIndex(of: rhs.element.path) ?? groupOrder.count
                return (lhsOrder, lhs.offset) < (rhsOrder, rhs.offset)
            }
            .flatMap(\.element.folders)
    }

    @ViewBuilder
    private var editContent: some View {
        Group {
            if case .loading = library.fileTreeStatus, library.fileTreeRoots.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if case .failed(let message) = library.fileTreeStatus {
                WorkbenchEmptyHint(message: message)
            } else if editFolders.isEmpty {
                WorkbenchEmptyHint(message: L("library.file.empty"))
            } else {
                LibraryFileTree(
                    scope: .editFolders(editFolders),
                    renameActions: LibraryFileTreeRenameActions(
                        isEnabled: !isFolderOperationBlocked,
                        renameFolder: appState.requestFolderRename,
                        renameFiles: appState.requestFileGroupRename
                    )
                )
            }
        }
        .task {
            appState.hydrateCompleteLibraryAsync()
        }
        .task(id: library.completeLibraryRevision) {
            appState.hydrateLibraryFileTreeAsync()
        }
    }
}
