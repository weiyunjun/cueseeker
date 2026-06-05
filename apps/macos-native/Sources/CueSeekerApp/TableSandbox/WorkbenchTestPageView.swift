import SwiftUI
import CueSeekerCore

/// Table-style UI sandbox pages, reachable only through the top-bar test icons
/// so production views stay untouched. Library stays blank per requirement;
/// Search/Shiori host the AppKit table on real data. Play reuses the production
/// open entries; the table renders results as they arrive (no lazy loading).
struct WorkbenchTestPageView: View {
    let page: WorkbenchTestPage

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            switch page {
            case .library:
                EmptyView()
            case .search:
                WorkbenchTestSearchView()
            case .shiori:
                WorkbenchTestShioriView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WorkbenchTestSearchView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var search: SearchStore
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search subtitles", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit { appState.submitTopbarSearch(query) }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .padding(16)

            SubtitleTableView(rows: rows, onPlay: play)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    private var rows: [SubtitleTableRow] {
        search.searchResults.map { result in
            SubtitleTableRow(
                id: Int(result.entryID),
                name: SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: result.subtitlePath),
                cues: subtitleDisplayLines(content: result.content, cueLines: result.cueLines).joined(separator: "\n")
            )
        }
    }

    private func play(_ row: SubtitleTableRow) {
        guard let result = search.searchResults.first(where: { Int($0.entryID) == row.id }) else { return }
        appState.openSearchResult(result)
    }
}

private struct WorkbenchTestShioriView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shiori: ShioriStore

    var body: some View {
        SubtitleTableView(rows: rows, onPlay: play)
            .padding(16)
    }

    private var rows: [SubtitleTableRow] {
        shiori.shioris.map { item in
            SubtitleTableRow(
                id: Int(item.id),
                name: SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: item.subtitlePath),
                cues: subtitleDisplayLines(content: item.content, cueLines: item.cueLines).joined(separator: "\n")
            )
        }
    }

    private func play(_ row: SubtitleTableRow) {
        guard let item = shiori.shioris.first(where: { Int($0.id) == row.id }) else { return }
        appState.openShiori(item)
    }
}
