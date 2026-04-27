import AppKit
import SwiftUI
import SubFinderXCore

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subtitle Folders")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    chooseFolder()
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .disabled(appState.indexingStatus.isIndexing)
            }

            statusView

            if appState.selectedFolders.isEmpty {
                EmptyStateView(
                    title: "No Subtitle Folders",
                    systemImage: "folder",
                    message: "Choose a local folder containing .srt files."
                )
            } else {
                List {
                    ForEach(appState.selectedFolders, id: \.self) { folder in
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
                                appState.indexFolder(folder)
                            } label: {
                                Label("Index Now", systemImage: "arrow.clockwise")
                            }
                            .disabled(appState.indexingStatus.isIndexing)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: appState.removeFolders)
                }
            }

            Spacer()
        }
        .padding(.top, AppShellLayout.contentTopPadding)
        .padding([.horizontal, .bottom], 24)
        .navigationTitle("Settings")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Subtitle Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let folder = panel.url else {
            return
        }

        appState.addFolder(folder)
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

            switch appState.indexingStatus {
            case .idle:
                EmptyView()
            case .indexing(let folder):
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Indexing \(folder.lastPathComponent)...")
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
