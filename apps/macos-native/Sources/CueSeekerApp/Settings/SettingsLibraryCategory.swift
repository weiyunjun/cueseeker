import AppKit
import CueSeekerCore
import SwiftUI

struct SettingsLibraryCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @State private var folderPendingRemoval: URL?
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.category.library"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(L("settings.library.description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        chooseFolder()
                    } label: {
                        Label(L("settings.library.add_folder"), systemImage: "folder.badge.plus")
                    }
                    .disabled(indexing.isLibraryFolderOperationActive || isChoosingFolder)

                    Button {
                        appState.indexAllFolders()
                    } label: {
                        Label(L("settings.library.index_now"), systemImage: "arrow.clockwise")
                    }
                    .disabled(indexing.selectedFolders.isEmpty || indexing.isLibraryFolderOperationActive)
                }
            }

            statusView

            if indexing.selectedFolders.isEmpty {
                EmptyStateView(
                    title: L("settings.library.empty_title"),
                    systemImage: "folder",
                    message: L("settings.library.empty_message")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                folderList
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
        .alert(
            L("settings.library.remove_folder_title"),
            isPresented: removalConfirmationBinding,
            presenting: folderPendingRemoval
        ) { folder in
            Button(L("common.cancel"), role: .cancel) {
                folderPendingRemoval = nil
            }
            Button(L("common.remove"), role: .destructive) {
                appState.removeFolder(folder)
                folderPendingRemoval = nil
            }
        } message: { folder in
            Text(L("settings.library.remove_folder_message", folder.lastPathComponent))
        }
    }

    private var folderList: some View {
        WorkbenchScrollView {
            LazyVStack(spacing: 0) {
                ForEach(indexing.selectedFolders, id: \.self) { folder in
                    folderRow(folder)

                    Divider()
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func folderRow(_ folder: URL) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.lastPathComponent)
                    .font(.headline)
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                folderPendingRemoval = folder
            } label: {
                Label(L("common.remove"), systemImage: "minus.circle")
            }
            .disabled(indexing.isLibraryFolderOperationActive)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
    }

    private var removalConfirmationBinding: Binding<Bool> {
        Binding {
            folderPendingRemoval != nil
        } set: { isPresented in
            if !isPresented {
                folderPendingRemoval = nil
            }
        }
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

    @ViewBuilder
    private var statusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let startupError = appState.startupError {
                Label(startupError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Text(L("settings.library.database_path", appState.databaseURL.path))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if case .removing(let folder) = indexing.folderRemovalStatus {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("settings.library.removing", folder.lastPathComponent))
                        .font(.subheadline)
                }
            } else if let removedFolder = indexing.removedFolderNotice {
                Label(L("settings.library.removed", removedFolder.lastPathComponent), systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                switch indexing.indexingStatus {
                case .idle:
                    EmptyView()
                case .indexing(let folder):
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L("settings.library.indexing", folder.lastPathComponent))
                            .font(.subheadline)
                    }
                case .indexingAll(let folder, let completedFolders, let totalFolders):
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L("settings.library.indexing_folder", completedFolders + 1, totalFolders, folder.lastPathComponent))
                            .font(.subheadline)
                    }
                case .completed(let folder, let result):
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L("settings.library.indexed", folder.lastPathComponent), systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text(indexingSummary(result))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !result.failedFiles.isEmpty {
                            Text(L("settings.library.files_failed", result.failedFiles.count, result.failedFiles[0].reason))
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                case .completedAll(let folderCount, let result):
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L("settings.library.indexed_folders", folderCount), systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text(indexingSummary(result))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !result.failedFiles.isEmpty {
                            Text(L("settings.library.files_failed", result.failedFiles.count, result.failedFiles[0].reason))
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                case .failed(let folder, let message):
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L("settings.library.index_failed", folder.lastPathComponent), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            ForEach(
                Array(indexing.auxiliaryFailures.enumerated()),
                id: \.offset
            ) { _, failure in
                Label(
                    failure.message,
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
            }
        }
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
