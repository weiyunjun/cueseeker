import Foundation
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
            SearchField(
                text: Binding(
                    get: { appState.searchQuery },
                    set: { appState.updateSearchQuery($0) }
                )
            )

            if appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: "No Search Query",
                    systemImage: "text.magnifyingglass",
                    message: "Add subtitle folders in Settings, then search indexed subtitle text."
                )
                .font(.system(size: SearchTypography.bodySize))
            } else if case .searching = appState.searchStatus, appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "Searching",
                    systemImage: "magnifyingglass",
                    message: "Looking through indexed subtitle text."
                )
                .font(.system(size: SearchTypography.bodySize))
                .overlay {
                    ProgressView()
                        .offset(y: 72)
                }
            } else if case .failed(let message) = appState.searchStatus {
                EmptyStateView(
                    title: "Search Failed",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
                .font(.system(size: SearchTypography.bodySize))
            } else if appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "tray",
                    message: "No indexed subtitle entries matched this query."
                )
                .font(.system(size: SearchTypography.bodySize))
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
                    SearchResultRow(
                        result: result,
                        query: appState.searchQuery
                    )
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
                .font(.system(size: SearchTypography.controlSize))

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
                        .font(.system(size: SearchTypography.playbackSubtitleSize))
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
                .font(.system(size: SearchTypography.detailSize))
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(24)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                "Search subtitles",
                text: Binding(
                    get: { text },
                    set: { text = $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: SearchTypography.searchFieldSize))
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

private struct SearchResultRow: View {
    let result: SubtitleSearchResult
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(highlightedContent(result.content, query: query))
                .font(.system(size: SearchTypography.bodySize))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(URL(fileURLWithPath: result.subtitlePath).lastPathComponent)
                .font(.system(size: SearchTypography.detailSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

private enum SearchTypography {
    static let searchFieldSize: CGFloat = 24
    static let bodySize: CGFloat = 20
    static let playbackSubtitleSize: CGFloat = 22
    static let detailSize: CGFloat = 16
    static let controlSize: CGFloat = 17
}

private func highlightedContent(_ content: String, query: String) -> AttributedString {
    var highlighted = AttributedString(content)
    let terms = highlightTerms(from: query)

    for term in terms {
        var searchRange = content.startIndex..<content.endIndex

        while let match = content.range(
            of: term,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            if let lowerBound = AttributedString.Index(match.lowerBound, within: highlighted),
               let upperBound = AttributedString.Index(match.upperBound, within: highlighted) {
                highlighted[lowerBound..<upperBound].backgroundColor = Color.yellow.opacity(0.55)
                highlighted[lowerBound..<upperBound].foregroundColor = Color.primary
            }

            guard match.upperBound < content.endIndex else {
                break
            }

            searchRange = match.upperBound..<content.endIndex
        }
    }

    return highlighted
}

private func highlightTerms(from query: String) -> [String] {
    Array(
        Set(
            query.unicodeScalars
                .split(whereSeparator: { !$0.properties.isAlphabetic && $0.properties.numericType == nil })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    )
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
