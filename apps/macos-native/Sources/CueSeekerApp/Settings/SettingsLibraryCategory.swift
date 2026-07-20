import AppKit
import CueSeekerCore
import SwiftUI

struct SettingsLibraryCategory: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @State private var folderPendingRemoval: URL?
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Manage subtitle folders used for indexing and search.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        chooseFolder()
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                    .disabled(indexing.isLibraryFolderOperationActive || isChoosingFolder)

                    Button {
                        appState.indexAllFolders()
                    } label: {
                        Label("Index Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(indexing.selectedFolders.isEmpty || indexing.isLibraryFolderOperationActive)
                }
            }

            statusView

            if indexing.selectedFolders.isEmpty {
                EmptyStateView(
                    title: "No Subtitle Folders",
                    systemImage: "folder",
                    message: "Choose a local folder containing subtitle files."
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
            "Remove Folder?",
            isPresented: removalConfirmationBinding,
            presenting: folderPendingRemoval
        ) { folder in
            Button("Cancel", role: .cancel) {
                folderPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                appState.removeFolder(folder)
                folderPendingRemoval = nil
            }
        } message: { folder in
            Text("Remove \"\(folder.lastPathComponent)\" from CueSeeker? This will not delete local files.")
        }
    }

    private var folderList: some View {
        List {
            ForEach(indexing.selectedFolders, id: \.self) { folder in
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
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .disabled(indexing.isLibraryFolderOperationActive)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
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
        panel.title = "Choose Subtitle Folder"
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

            Text("Database: \(appState.databaseURL.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if case .removing(let folder) = indexing.folderRemovalStatus {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Removing \(folder.lastPathComponent)…")
                        .font(.subheadline)
                }
            } else {
                switch indexing.indexingStatus {
                case .idle:
                    EmptyView()
                case .indexing(let folder):
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Indexing \(folder.lastPathComponent)...")
                            .font(.subheadline)
                    }
                case .indexingAll(let folder, let completedFolders, let totalFolders):
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Indexing folder \(completedFolders + 1) of \(totalFolders): \(folder.lastPathComponent)...")
                            .font(.subheadline)
                    }
                case .completed(let folder, let result):
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Indexed \(folder.lastPathComponent)", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text(indexingSummary(result))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !result.failedFiles.isEmpty {
                            Text("\(result.failedFiles.count) file(s) failed. First: \(result.failedFiles[0].reason)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                case .completedAll(let folderCount, let result):
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Indexed \(folderCount) folder(s)", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text(indexingSummary(result))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !result.failedFiles.isEmpty {
                            Text("\(result.failedFiles.count) file(s) failed. First: \(result.failedFiles[0].reason)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                case .failed(let folder, let message):
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Failed to index \(folder.lastPathComponent)", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func indexingSummary(_ result: SubtitleIndexingResult) -> String {
        [
            "\(result.scannedSubtitleFiles) scanned",
            "\(result.indexedSubtitleFiles) indexed files",
            "\(result.indexedSubtitleEntries) entries",
            "\(result.skippedUnchangedSubtitleFiles) unchanged",
            "\(result.skippedMissingVideo) missing videos",
            "\(result.skippedUnreadableSubtitle) unreadable"
        ].joined(separator: " · ")
    }
}
