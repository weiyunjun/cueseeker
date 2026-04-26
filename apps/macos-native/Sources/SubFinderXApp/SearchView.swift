import SwiftUI
import SubFinderXCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let result = appState.selectedSearchResult {
            playbackPage(for: result)
        } else {
            searchResultsPage
        }
    }

    private var searchResultsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(
                "Search subtitles",
                text: Binding(
                    get: { appState.searchQuery },
                    set: { appState.updateSearchQuery($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.title3)

            if appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: "No Search Query",
                    systemImage: "text.magnifyingglass",
                    message: "Add subtitle folders in Settings, then search indexed subtitle text."
                )
            } else if case .searching = appState.searchStatus, appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "Searching",
                    systemImage: "magnifyingglass",
                    message: "Looking through indexed subtitle text."
                )
                .overlay {
                    ProgressView()
                        .offset(y: 64)
                }
            } else if case .failed(let message) = appState.searchStatus {
                EmptyStateView(
                    title: "Search Failed",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
            } else if appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "tray",
                    message: "No indexed subtitle entries matched this query."
                )
            } else {
                resultsList
            }

            Spacer()
        }
        .padding(24)
    }

    private var resultsList: some View {
        List {
            ForEach(appState.searchResults, id: \.entryID) { result in
                Button {
                    appState.openSearchResult(result)
                } label: {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func playbackPage(for result: SubtitleSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    appState.closeSelectedSearchResult()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .keyboardShortcut(.cancelAction)

                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PlaybackView(player: appState.playbackPlayer)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.togglePlayback()
                        }

                    Text(result.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledContent("Start Time") {
                        Text(formatTimestamp(result.startMilliseconds))
                            .textSelection(.enabled)
                    }

                    LabeledContent("Video Path") {
                        Text(result.videoPath)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Subtitle Path") {
                        Text(result.subtitlePath)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(24)
    }
}

private struct SearchResultRow: View {
    let result: SubtitleSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.content)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                Label(formatTimestamp(result.startMilliseconds), systemImage: "clock")
                Label(result.videoName, systemImage: "film")
                Text(URL(fileURLWithPath: result.subtitlePath).lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

private func formatTimestamp(_ milliseconds: Int) -> String {
    let totalSeconds = milliseconds / 1_000
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}
