import SwiftUI

struct SettingsMaintenanceCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @State private var isShowingCompactConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.category.maintenance"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("settings.maintenance.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                maintenanceStatusView

                if let stats = indexing.databaseStorageStats {
                    VStack(alignment: .leading, spacing: 8) {
                        storageRow(L("settings.maintenance.database_size"), bytes: stats.databaseFileBytes)
                        storageRow(L("settings.maintenance.used_estimate"), bytes: stats.usedBytesEstimate)
                        storageRow(L("settings.maintenance.reclaimable"), bytes: stats.freelistBytes)
                        storageRow(L("settings.maintenance.wal_size"), bytes: stats.walFileBytes)
                        storageRow(L("settings.maintenance.shm_size"), bytes: stats.shmFileBytes)
                    }
                    .padding(.vertical, 4)

                    if appState.isDatabaseCompactionRecommended {
                        Label { Text(L("settings.maintenance.compaction_recommended")) } icon: { AppIconImage(.warningCircle, size: WorkbenchControlMetrics.redesignControlIconSize) }
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label { Text(L("settings.maintenance.within_threshold")) } icon: { AppIconImage(.checkCircle, size: WorkbenchControlMetrics.redesignControlIconSize) }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L("settings.maintenance.stats_unavailable"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    appState.refreshDatabaseStorageStats()
                } label: {
                    Label { Text(L("settings.maintenance.refresh")) } icon: { AppIconImage(.arrowClockwise, size: WorkbenchControlMetrics.redesignControlIconSize) }
                }
                .focusable(false)
                .disabled(
                    indexing.folderRemovalStatus.isRemoving
                        || indexing.databaseMaintenanceStatus.isCompacting
                )

                Button {
                    isShowingCompactConfirmation = true
                } label: {
                    Label { Text(L("settings.maintenance.compact")) } icon: { AppIconImage(.fileArrowDown, size: WorkbenchControlMetrics.redesignControlIconSize) }
                }
                .focusable(false)
                .disabled(!appState.canCompactDatabase)
            }

            Text(L("settings.library.database_path", appState.databaseURL.path))
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
        .alert(L("settings.maintenance.compact_title"), isPresented: $isShowingCompactConfirmation) {
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("settings.maintenance.compact_confirm"), role: .destructive) {
                appState.compactDatabaseStorage()
            }
        } message: {
            Text(L("settings.maintenance.compact_message"))
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
                Text(L("settings.maintenance.loading_stats"))
                    .font(.subheadline)
            }
        case .compacting:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L("settings.maintenance.compacting"))
                    .font(.subheadline)
            }
        case .completed(let message):
            Label { Text(message) } icon: { AppIconImage(.checkCircle, size: WorkbenchControlMetrics.redesignControlIconSize) }
                .font(.subheadline)
                .foregroundStyle(.green)
        case .failed(let message):
            Label { Text(message) } icon: { AppIconImage(.warning, size: WorkbenchControlMetrics.redesignControlIconSize) }
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
