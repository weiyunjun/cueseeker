import SwiftUI
import SubFinderXCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
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
                HStack(alignment: .top, spacing: 16) {
                    resultsList
                    selectedResultView
                }
            }

            Spacer()
        }
        .padding(24)
        .navigationTitle("Search")
    }

    private var resultsList: some View {
        List {
            ForEach(appState.searchResults, id: \.entryID) { result in
                Button {
                    appState.selectSearchResult(result)
                } label: {
                    SearchResultRow(
                        result: result,
                        isSelected: appState.selectedSearchResult?.entryID == result.entryID
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 420)
    }

    @ViewBuilder
    private var selectedResultView: some View {
        if let result = appState.selectedSearchResult {
            VStack(alignment: .leading, spacing: 12) {
                PlaybackView { viewID in
                    appState.attachPlaybackView(id: viewID)
                }
                .frame(height: 220)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(result.videoName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(formatTimestamp(result.startMilliseconds))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(result.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button {
                        appState.play(result)
                    } label: {
                        Label("Play From Here", systemImage: "play.fill")
                    }
                    .disabled(appState.playbackStatus.isOpening)

                    Button {
                        appState.pausePlayback()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .disabled(appState.playbackStatus.isOpening)
                }

                playbackStatusView

                Divider()

                LabeledContent("Video Path") {
                    Text(result.videoPath)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                LabeledContent("Start ms") {
                    Text("\(result.startMilliseconds)")
                        .textSelection(.enabled)
                }

                LabeledContent("Subtitle Path") {
                    Text(result.subtitlePath)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer()
            }
            .padding(16)
            .frame(minWidth: 320, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            EmptyStateView(
                title: "No Result Selected",
                systemImage: "rectangle.and.text.magnifyingglass",
                message: "Select a result to inspect its video path and timestamp."
            )
            .frame(minWidth: 320, maxWidth: 420)
        }
    }

    @ViewBuilder
    private var playbackStatusView: some View {
        switch appState.playbackStatus {
        case .idle:
            EmptyView()
        case .opening(let result):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Opening \(result.videoName)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .playing(let result):
            Label("Playing \(result.videoName) at \(formatTimestamp(result.startMilliseconds))", systemImage: "play.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
        }
    }
}

private struct SearchResultRow: View {
    let result: SubtitleSearchResult
    let isSelected: Bool

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
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
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
