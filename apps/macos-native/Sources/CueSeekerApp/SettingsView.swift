import AppKit
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var folderPendingRemoval: URL?
    @State private var isChoosingFolder = false

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
                .disabled(appState.indexingStatus.isIndexing || isChoosingFolder)

                Button {
                    appState.indexAllFolders()
                } label: {
                    Label("Index Now", systemImage: "arrow.clockwise")
                }
                .disabled(appState.selectedFolders.isEmpty || appState.indexingStatus.isIndexing)
            }

            statusView

            decodeSettingsView

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
                                folderPendingRemoval = folder
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                            .disabled(appState.indexingStatus.isIndexing)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, AppShellLayout.contentTopPadding)
        .padding([.horizontal, .bottom], 24)
        .navigationTitle("Settings")
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

    private var decodeSettingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Decode Settings")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Text("Decoder")
                    .font(.subheadline)

                Spacer()

                DecodeModeSegmentedControl(selection: $appState.playbackDecodeMode)
            }

            HStack(spacing: 12) {
                Text("ASS Renderer")
                    .font(.subheadline)

                Spacer()

                Picker("", selection: $appState.assSubtitleRenderingMode) {
                    ForEach(ASSSubtitleRenderingMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
                .accessibilityLabel("ASS Renderer")
            }
        }
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

private struct DecodeModeSegmentedControl: View {
    @Binding var selection: PlaybackDecodeMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PlaybackDecodeMode.allCases) { mode in
                let isSelected = selection == mode

                Button {
                    selection = mode
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(width: 72, height: 26)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decoder \(mode.displayName)")
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
