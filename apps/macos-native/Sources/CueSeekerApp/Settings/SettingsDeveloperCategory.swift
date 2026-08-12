import CueSeekerCore
import SwiftUI

struct SettingsDeveloperCategory: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var indexing: IndexingStore
    @EnvironmentObject private var search: SearchStore

    var body: some View {
        WorkbenchScrollView {
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
}
