import AppKit
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var folderPendingRemoval: URL?
    @State private var remoteSourcePendingRemoval: StoredMediaSource?
    @State private var isChoosingFolder = false
    @State private var isShowingRemoteSourceSheet = false
    @State private var remoteDisplayName = ""
    @State private var remoteRootURL = ""
    @State private var remoteUsername = ""
    @State private var remotePassword = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Media Sources")
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
                    isShowingRemoteSourceSheet = true
                } label: {
                    Label("Add WebDAV", systemImage: "network")
                }
                .disabled(appState.indexingStatus.isIndexing)

                Button {
                    appState.indexAllFolders()
                } label: {
                    Label("Index Now", systemImage: "arrow.clockwise")
                }
                .disabled(appState.selectedFolders.isEmpty || appState.indexingStatus.isIndexing)
            }

            statusView

            decodeSettingsView

            if appState.selectedFolders.isEmpty && appState.remoteSources.isEmpty {
                EmptyStateView(
                    title: "No Media Sources",
                    systemImage: "folder",
                    message: "Choose a local folder or add an AList WebDAV source."
                )
            } else {
                List {
                    if !appState.selectedFolders.isEmpty {
                        Section("Local Folders") {
                            localFoldersList
                        }
                    }
                    if !appState.remoteSources.isEmpty {
                        Section("Remote WebDAV") {
                            remoteSourcesList
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.top, AppShellLayout.contentTopPadding)
        .padding([.horizontal, .bottom], 24)
        .navigationTitle("Settings")
        .sheet(isPresented: $isShowingRemoteSourceSheet) {
            remoteSourceSheet
        }
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
        .alert(
            "Remove Remote Source?",
            isPresented: remoteRemovalConfirmationBinding,
            presenting: remoteSourcePendingRemoval
        ) { source in
            Button("Cancel", role: .cancel) {
                remoteSourcePendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                appState.removeRemoteSource(source)
                remoteSourcePendingRemoval = nil
            }
        } message: { source in
            Text("Remove \"\(source.displayName)\" from CueSeeker? This will not modify remote files.")
        }
    }

    @ViewBuilder
    private var localFoldersList: some View {
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

    @ViewBuilder
    private var remoteSourcesList: some View {
        ForEach(appState.remoteSources) { source in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.displayName)
                        .font(.headline)
                    Text(source.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    appState.indexRemoteSource(source)
                } label: {
                    Label("Index", systemImage: "arrow.clockwise")
                }
                .disabled(appState.indexingStatus.isIndexing)

                Button {
                    remoteSourcePendingRemoval = source
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                }
                .disabled(appState.indexingStatus.isIndexing)
            }
            .padding(.vertical, 4)
        }
    }

    private var remoteSourceSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add AList WebDAV Source")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("Display Name", text: $remoteDisplayName)
            TextField("WebDAV Root URL", text: $remoteRootURL)
            TextField("Username", text: $remoteUsername)
            SecureField("Password", text: $remotePassword)

            HStack {
                Spacer()
                Button("Cancel") {
                    resetRemoteSourceForm()
                    isShowingRemoteSourceSheet = false
                }
                Button("Add") {
                    appState.addAListRemoteSource(
                        displayName: remoteDisplayName,
                        rootURLString: remoteRootURL,
                        username: remoteUsername,
                        password: remotePassword
                    )
                    resetRemoteSourceForm()
                    isShowingRemoteSourceSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(remoteRootURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func resetRemoteSourceForm() {
        remoteDisplayName = ""
        remoteRootURL = ""
        remoteUsername = ""
        remotePassword = ""
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

    private var remoteRemovalConfirmationBinding: Binding<Bool> {
        Binding {
            remoteSourcePendingRemoval != nil
        } set: { isPresented in
            if !isPresented {
                remoteSourcePendingRemoval = nil
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
            case .validatingRemote(let name, let detail):
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Validating \(name)...")
                            .font(.subheadline)
                        if let detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            case .indexingRemote(let name, let detail):
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Indexing \(name)...")
                            .font(.subheadline)
                        if let detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
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
            case .completedRemote(let name, let result):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Indexed \(name)", systemImage: "checkmark.circle")
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
            case .failedRemote(let name, let message):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Failed to index \(name)", systemImage: "exclamationmark.triangle")
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
