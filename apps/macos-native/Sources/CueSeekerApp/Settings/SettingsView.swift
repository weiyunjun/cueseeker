import AppKit
import SwiftUI
import CueSeekerCore
import CueSeekerPlayback

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case library
    case appearance
    case decode
    case maintenance
    case developer
    case experimentalFeatures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library:
            "Library"
        case .appearance:
            "Appearance"
        case .decode:
            "Decode"
        case .maintenance:
            "Maintenance"
        case .developer:
            "Developer"
        case .experimentalFeatures:
            "Experimental Features"
        }
    }

    var systemImage: String {
        switch self {
        case .library:
            "folder"
        case .appearance:
            "circle.lefthalf.filled"
        case .decode:
            "play.rectangle"
        case .maintenance:
            "externaldrive"
        case .developer:
            "hammer"
        case .experimentalFeatures:
            "sparkles"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedCategory: SettingsCategory = .library
    @State private var folderPendingRemoval: URL?
    @State private var isChoosingFolder = false
    @State private var isShowingCompactConfirmation = false

    private let categoryColumnWidth: CGFloat = 184
    private let sidebarBackground = Color(
        red: 0.942,
        green: 0.942,
        blue: 0.936
    )
    private let contentBackground = Color.white

    var body: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: categoryColumnWidth)

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 1)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 420)
        .background(contentBackground)
        .preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)
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
        .alert("Compact Database?", isPresented: $isShowingCompactConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Compact", role: .destructive) {
                appState.compactDatabaseStorage()
            }
        } message: {
            Text("CueSeeker will reclaim unused SQLite space. Search and indexing are paused while compaction runs.")
        }
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.title, systemImage: category.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundStyle(
                            selectedCategory == category ? .white : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
            }

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 12)
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedCategory {
        case .library:
            librarySettingsContent
        case .appearance:
            appearanceSettingsContent
        case .decode:
            decodeSettingsContent
        case .maintenance:
            maintenanceSettingsContent
        case .developer:
            developerSettingsContent
        case .experimentalFeatures:
            experimentalFeaturesSettingsContent
        }
    }

    private var librarySettingsContent: some View {
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
                    .disabled(indexing.indexingStatus.isIndexing || isChoosingFolder)

                    Button {
                        appState.indexAllFolders()
                    } label: {
                        Label("Index Now", systemImage: "arrow.clockwise")
                    }
                    .disabled(indexing.selectedFolders.isEmpty || indexing.indexingStatus.isIndexing)
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
        .background(contentBackground)
    }

    private var appearanceSettingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Appearance")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose how CueSeeker follows light and dark mode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appearance Mode")
                        .font(.headline)
                    Text("Auto follows the current macOS system appearance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AppearanceModeSegmentedControl(selection: $settingsStore.appAppearanceMode)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(contentBackground)
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
                    .disabled(indexing.indexingStatus.isIndexing)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }

    private var decodeSettingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Decode")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose the video decode mode used by playback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decoder")
                        .font(.headline)
                    Text("Applies to newly opened playback sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DecodeModeSegmentedControl(selection: $settingsStore.playbackDecodeMode)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(contentBackground)
    }

    private var experimentalFeaturesSettingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Experimental Features")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Try unstable features that may change or be removed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(contentBackground)
    }

    private var maintenanceSettingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Maintenance")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Review local database storage and reclaim unused space.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                maintenanceStatusView

                if let stats = indexing.databaseStorageStats {
                    VStack(alignment: .leading, spacing: 8) {
                        storageRow("Database Size", bytes: stats.databaseFileBytes)
                        storageRow("Used Estimate", bytes: stats.usedBytesEstimate)
                        storageRow("Reclaimable Space", bytes: stats.freelistBytes)
                        storageRow("WAL Size", bytes: stats.walFileBytes)
                        storageRow("SHM Size", bytes: stats.shmFileBytes)
                    }
                    .padding(.vertical, 4)

                    if appState.isDatabaseCompactionRecommended {
                        Label("Compaction recommended", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("Database storage is within the maintenance threshold", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Storage stats unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    appState.refreshDatabaseStorageStats()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(indexing.databaseMaintenanceStatus.isCompacting)

                Button {
                    isShowingCompactConfirmation = true
                } label: {
                    Label("Compact Database", systemImage: "arrow.down.doc")
                }
                .disabled(!appState.canCompactDatabase)
            }

            Text("Database: \(appState.databaseURL.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(contentBackground)
        .onAppear {
            appState.refreshDatabaseStorageStats()
        }
    }

    private var developerSettingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure local diagnostics used during development.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search E2E JSON Logs")
                            .font(.headline)
                        Text("Record each Search run as JSONL under logs/search-e2e/.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settingsStore.searchE2ELoggingEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FTS Vocabulary Diagnostics")
                            .font(.headline)
                        Text("Enable fts5vocab diagnostics for local developer tools.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settingsStore.searchFTSVocabularyDiagnosticsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                ftsVocabularyDiagnosticsPanel
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(contentBackground)
        .onAppear {
            if settingsStore.searchFTSVocabularyDiagnosticsEnabled {
                appState.refreshSearchFTSVocabularyDiagnostics()
            }
        }
    }

    private var ftsVocabularyDiagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("FTS Vocabulary Data")
                    .font(.headline)

                Spacer()

                Button {
                    appState.refreshSearchFTSVocabularyDiagnostics()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(
                    !settingsStore.searchFTSVocabularyDiagnosticsEnabled
                        || indexing.searchFTSVocabularyDiagnosticsStatus.isLoading
                )
            }

            ftsVocabularyDiagnosticsStatusView

            if let diagnostics = indexing.searchFTSVocabularyDiagnostics,
               settingsStore.searchFTSVocabularyDiagnosticsEnabled {
                HStack(spacing: 18) {
                    ftsVocabularyMetricView(
                        title: "Terms",
                        value: diagnostics.uniqueTermCount
                    )
                    ftsVocabularyMetricView(
                        title: "Doc refs",
                        value: diagnostics.totalDocumentReferences
                    )
                    ftsVocabularyMetricView(
                        title: "Occurrences",
                        value: diagnostics.totalOccurrences
                    )
                }

                Divider()

                ftsVocabularyTermsSection(
                    title: currentQueryTermsTitle,
                    terms: diagnostics.queryTerms,
                    emptyMessage: "No query terms."
                )

                ftsVocabularyTermsSection(
                    title: "Most Frequent Terms",
                    terms: diagnostics.mostFrequentTerms,
                    emptyMessage: "No vocabulary data."
                )
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var ftsVocabularyDiagnosticsStatusView: some View {
        if !settingsStore.searchFTSVocabularyDiagnosticsEnabled {
            Text("Disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            switch indexing.searchFTSVocabularyDiagnosticsStatus {
            case .idle:
                Text("No data loaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading vocabulary data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .completed(let date):
                Text("Updated \(date.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var currentQueryTermsTitle: String {
        let query = search.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? "Query Terms" : "Query Terms: \(query)"
    }

    private func ftsVocabularyMetricView(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formattedCount(value))
                .font(.system(.body, design: .monospaced))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ftsVocabularyTermsSection(
        title: String,
        terms: [SubtitleFTSVocabularyTermDiagnostic],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            if terms.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(terms, id: \.term) { term in
                        HStack(spacing: 12) {
                            Text(term.term)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .frame(minWidth: 42, alignment: .leading)

                            Spacer()

                            Text("docs \(formattedCount(term.documentCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Text("occ \(formattedCount(term.occurrenceCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func formattedCount(_ value: Int) -> String {
        value.formatted(.number)
    }

    @ViewBuilder
    private var maintenanceStatusView: some View {
        switch indexing.databaseMaintenanceStatus {
        case .idle:
            EmptyView()
        case .loadingStats:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading storage stats...")
                    .font(.subheadline)
            }
        case .compacting:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Compacting database...")
                    .font(.subheadline)
            }
        case .completed(let message):
            Label(message, systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private func storageRow(_ title: String, bytes: Int64) -> some View {
        metricRow(title, value: Self.formattedBytes(bytes))
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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

private struct AppearanceModeSegmentedControl: View {
    @Binding var selection: AppAppearanceMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppAppearanceMode.allCases) { mode in
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
                .accessibilityLabel("Appearance \(mode.displayName)")
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
