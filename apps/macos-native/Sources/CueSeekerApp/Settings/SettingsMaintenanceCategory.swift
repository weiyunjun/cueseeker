import SwiftUI

/// Settings / Maintenance's group: the database's storage, how it stands, and
/// refreshing and compacting it.
struct SettingsMaintenanceCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var indexing: IndexingStore
    @State private var isShowingCompactConfirmation = false

    var body: some View {
        SettingsGroup(
            title: L("settings.category.maintenance"),
            description: L("settings.maintenance.description")
        ) {
            if let stats = indexing.databaseStorageStats {
                storageRow(L("settings.maintenance.database_size"), bytes: stats.databaseFileBytes)
                SettingsRowDivider()
                storageRow(L("settings.maintenance.used_estimate"), bytes: stats.usedBytesEstimate)
                SettingsRowDivider()
                storageRow(L("settings.maintenance.reclaimable"), bytes: stats.freelistBytes)
                SettingsRowDivider()
                storageRow(L("settings.maintenance.wal_size"), bytes: stats.walFileBytes)
                SettingsRowDivider()
                storageRow(L("settings.maintenance.shm_size"), bytes: stats.shmFileBytes)
                SettingsRowDivider()
            }

            SettingsRow {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    maintenanceStatusView
                    storageStateView
                }
            } trailing: {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    let isRefreshDisabled =
                        indexing.folderRemovalStatus.isRemoving
                        || indexing.databaseMaintenanceStatus.isCompacting

                    WorkbenchButton(
                        title: L("settings.maintenance.refresh"),
                        icon: .arrowClockwise,
                        isRedesign: true
                    ) {
                        appState.refreshDatabaseStorageStats()
                    }
                    .disabled(isRefreshDisabled)
                    .workbenchTooltip(
                        scenarioID: "disabled.settings.maintenance.actions",
                        surface: .settings,
                        isActive: isRefreshDisabled,
                        label: L("tooltip.disabled.settings.maintenance.actions")
                    )

                    WorkbenchButton(
                        title: L("settings.maintenance.compact"),
                        icon: .fileArrowDown,
                        isRedesign: true
                    ) {
                        isShowingCompactConfirmation = true
                    }
                    .disabled(!appState.canCompactDatabase)
                    .workbenchTooltip(
                        scenarioID: "disabled.settings.maintenance.actions",
                        surface: .settings,
                        isActive: !appState.canCompactDatabase,
                        label: L("tooltip.disabled.settings.maintenance.actions")
                    )
                }
            }

            SettingsRowDivider()

            SettingsRow {
                Text(L("settings.library.database_path", appState.databaseURL.path))
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } trailing: {
                EmptyView()
            }
        }
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

    /// What maintenance is doing, or last did.
    @ViewBuilder
    private var maintenanceStatusView: some View {
        switch indexing.databaseMaintenanceStatus {
        case .idle:
            EmptyView()
        case .loadingStats:
            progressLabel(L("settings.maintenance.loading_stats"))
        case .compacting:
            progressLabel(L("settings.maintenance.compacting"))
        case .completed(let message):
            statusLabel(message, icon: .checkCircle, color: WorkbenchRedesignColors.successText)
        case .failed(let message):
            statusLabel(message, icon: .warning, color: WorkbenchRedesignColors.dangerText)
        }
    }

    /// Whether the storage needs compacting.
    @ViewBuilder
    private var storageStateView: some View {
        if indexing.databaseStorageStats == nil {
            statusLabel(
                L("settings.maintenance.stats_unavailable"),
                icon: nil,
                color: WorkbenchRedesignColors.textSecondary
            )
        } else if appState.isDatabaseCompactionRecommended {
            statusLabel(
                L("settings.maintenance.compaction_recommended"),
                icon: .warningCircle,
                color: WorkbenchRedesignColors.warningText
            )
        } else {
            statusLabel(
                L("settings.maintenance.within_threshold"),
                icon: .checkCircle,
                color: WorkbenchRedesignColors.textSecondary
            )
        }
    }

    private func statusLabel(_ text: String, icon: AppIcon?, color: Color) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if let icon {
                AppIconImage(icon, size: WorkbenchControlMetrics.redesignButtonIconSize)
            }

            Text(text)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
    }

    private func progressLabel(_ text: String) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ProgressView()
                .controlSize(.small)

            Text(text)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(WorkbenchRedesignColors.textSecondary)
    }

    private func storageRow(_ title: String, bytes: Int64) -> some View {
        SettingsRow(title) {
            Text(Self.formattedBytes(bytes))
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .monospacedDigit()
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
        }
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
