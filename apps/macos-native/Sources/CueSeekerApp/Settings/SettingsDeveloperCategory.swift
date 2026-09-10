import CueSeekerCore
import SwiftUI

struct SettingsDeveloperCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var search: SearchStore

    var body: some View {
        WorkbenchScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.category.developer"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(L("settings.developer.description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("settings.developer.e2e_logs"))
                            .font(.headline)
                        Text(L("settings.developer.e2e_logs_note"))
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
                        Text(L("settings.developer.fts_diagnostics"))
                            .font(.headline)
                        Text(L("settings.developer.fts_diagnostics_note"))
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
        .background(WorkbenchRedesignColors.bgSurface)
        .onAppear {
            if settingsStore.searchFTSVocabularyDiagnosticsEnabled {
                appState.refreshSearchFTSVocabularyDiagnostics()
            }
        }
    }

    private var ftsVocabularyDiagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(L("settings.developer.fts_data"))
                    .font(.headline)

                Spacer()

                Button {
                    appState.refreshSearchFTSVocabularyDiagnostics()
                } label: {
                    Label { Text(L("settings.maintenance.refresh")) } icon: { AppIconImage(.arrowClockwise, size: WorkbenchControlMetrics.redesignControlIconSize) }
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
                        title: L("settings.developer.terms"),
                        value: diagnostics.uniqueTermCount
                    )
                    ftsVocabularyMetricView(
                        title: L("settings.developer.doc_refs"),
                        value: diagnostics.totalDocumentReferences
                    )
                    ftsVocabularyMetricView(
                        title: L("settings.developer.occurrences"),
                        value: diagnostics.totalOccurrences
                    )
                }

                Divider()

                ftsVocabularyTermsSection(
                    title: currentQueryTermsTitle,
                    terms: diagnostics.queryTerms,
                    emptyMessage: L("settings.developer.no_query_terms")
                )

                ftsVocabularyTermsSection(
                    title: L("settings.developer.most_frequent"),
                    terms: diagnostics.mostFrequentTerms,
                    emptyMessage: L("settings.developer.no_vocabulary")
                )
            }
        }
        .padding(12)
        .background(diagnosticsPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var diagnosticsPanelBackground: Color {
        colorScheme == .dark
            ? WorkbenchRedesignColors.bgHover
            : Color.black.opacity(0.035)
    }

    @ViewBuilder
    private var ftsVocabularyDiagnosticsStatusView: some View {
        if !settingsStore.searchFTSVocabularyDiagnosticsEnabled {
            Text(L("settings.developer.disabled"))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            switch indexing.searchFTSVocabularyDiagnosticsStatus {
            case .idle:
                Text(L("settings.developer.no_data"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("settings.developer.loading"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .completed(let date):
                Text(L("settings.developer.updated", date.formatted(date: .omitted, time: .standard)))
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
        return query.isEmpty ? L("settings.developer.query_terms") : L("settings.developer.query_terms_value", query)
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

                            Text(L("settings.developer.docs", formattedCount(term.documentCount)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Text(L("settings.developer.occ", formattedCount(term.occurrenceCount)))
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
}
