import AppKit
import CueSeekerCore
import SwiftUI

/// The File primary page. It owns the indexed root folders and the indexing
/// controls that used to live in the Settings window's Library category.
struct WorkbenchFileView: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @State private var isChoosingFolder = false

    var body: some View {
        GeometryReader { geometry in
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    WorkbenchPageTitle(L("sidebar.file"))

                    pageDescription
                        .padding(.top, WorkbenchControlMetrics.redesignSpacing2)

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
                systemImage: "folder.badge.plus",
                isRedesign: true
            ) {
                chooseFolder()
            }
            .disabled(indexing.isLibraryFolderOperationActive || isChoosingFolder)

            WorkbenchButton(
                title: L("settings.library.index_now"),
                systemImage: "arrow.clockwise",
                isRedesign: true
            ) {
                appState.indexAllFolders()
            }
            .disabled(
                indexing.selectedFolders.isEmpty
                    || indexing.isLibraryFolderOperationActive
            )
        }
    }

    @ViewBuilder
    private var folderRegion: some View {
        if indexing.selectedFolders.isEmpty {
            EmptyStateView(
                title: L("settings.library.empty_title"),
                systemImage: "folder",
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
                systemImage: "minus.circle"
            ) {
                requestRemoval(of: folder)
            }
            .disabled(indexing.isLibraryFolderOperationActive)
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
                    systemImage: "exclamationmark.triangle",
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
                    systemImage: "checkmark.circle",
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
                            systemImage: "exclamationmark.triangle",
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
                    systemImage: "exclamationmark.triangle",
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
                systemImage: "checkmark.circle",
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
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Image(systemName: systemImage)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignControlIconSize,
                    weight: WorkbenchControlMetrics.redesignControlIconWeight
                ))

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
