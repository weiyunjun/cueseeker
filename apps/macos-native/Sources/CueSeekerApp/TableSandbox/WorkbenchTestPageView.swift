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
    @StateObject private var rowStore = TableSandboxRowModelStore()
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

            SubtitleTableView(
                tableName: "test-search",
                rows: rowStore.snapshot.rows,
                rowsVersion: rowStore.snapshot.version,
                rowsUpdate: rowStore.snapshot.update,
                onPlay: play
            )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        // Eagerly load every page (Excel-style: all rows loaded, only the
        // visible ones rendered), so the table reaches results beyond page 1.
        .onAppear { updateRows(search.searchResults) }
        .onReceive(search.$searchResults) { updateRows($0) }
        .onChange(of: search.isSearching) { _ in loadAllRemaining() }
        .onChange(of: search.searchResults.count) { _ in loadAllRemaining() }
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        rowStore.updateSearchRows(results, tableName: "test-search")
    }

    private func loadAllRemaining() {
        guard search.hasMoreSearchResults, !search.isSearching else { return }
        appState.loadMoreSearchResultsIfNeeded()
    }

    private func play(_ row: SubtitleTableRow) {
        guard let result = search.searchResults.first(where: { Int($0.entryID) == row.id }) else { return }
        appState.openSearchResult(result)
    }
}

private struct WorkbenchTestShioriView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shiori: ShioriStore
    @StateObject private var rowStore = TableSandboxRowModelStore()

    var body: some View {
        SubtitleTableView(
            tableName: "test-shiori",
            rows: rowStore.snapshot.rows,
            rowsVersion: rowStore.snapshot.version,
            rowsUpdate: rowStore.snapshot.update,
            onPlay: play
        )
            .padding(16)
            .onAppear { updateRows(shiori.shioris) }
            .onReceive(shiori.$shioris) { updateRows($0) }
            .task { appState.hydrateShiorisAsync() }
    }

    private func updateRows(_ shioris: [Shiori]) {
        rowStore.updateShioriRows(shioris, tableName: "test-shiori")
    }

    private func play(_ row: SubtitleTableRow) {
        guard let item = shiori.shioris.first(where: { Int($0.id) == row.id }) else { return }
        appState.openShiori(item)
    }
}
