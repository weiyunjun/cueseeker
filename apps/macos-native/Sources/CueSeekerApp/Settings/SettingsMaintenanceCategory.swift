import SwiftUI

struct SettingsMaintenanceCategory: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @State private var isShowingCompactConfirmation = false

    var body: some View {
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
                .disabled(
                    indexing.folderRemovalStatus.isRemoving
                        || indexing.databaseMaintenanceStatus.isCompacting
                )

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
        .background(WorkbenchRedesignColors.bgSurface)
        .onAppear {
            appState.refreshDatabaseStorageStats()
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
}
