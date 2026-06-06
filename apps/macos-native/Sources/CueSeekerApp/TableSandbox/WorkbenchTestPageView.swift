import SwiftUI
import CueSeekerCore

/// Table-style UI sandbox pages, reachable only through the top-bar test icons
/// so production views stay untouched. Library stays blank per requirement;
/// Search/Shiori host the AppKit table on real data. Play reuses the production
/// open entries; the table uses virtual result metadata so the UI does not
/// materialize every possible search hit before rendering.
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
    @StateObject private var visibleHydrator = TableSandboxVisibleSearchHydrator()
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
                rowCount: rowStore.snapshot.totalRowCount,
                rowProvider: { rowStore.snapshot.row(at: $0) },
                rowsVersion: rowStore.snapshot.version,
                rowsUpdate: rowStore.snapshot.update,
                onVisibleRowsChange: hydrateVisibleRows,
                onPlay: play
            )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .onAppear { updateRows(search.searchResults) }
        .onReceive(search.$searchResults) { updateRows($0) }
        .onChange(of: search.searchResultTotalCount) { _ in updateRows(search.searchResults) }
        .onDisappear { visibleHydrator.cancel() }
    }

    private func updateRows(_ results: [SubtitleSearchResult]) {
        rowStore.updateSearchRows(
            results,
            totalRowCount: search.searchResultTotalCount,
            tableName: "test-search"
        )
    }

    private func play(_ row: SubtitleTableRow) {
        guard let result = search.searchResults.first(where: { Int($0.entryID) == row.id }) else { return }
        appState.openSearchResult(result)
    }

    private func hydrateVisibleRows(_ visibleRows: Range<Int>) {
        visibleHydrator.schedule(
            visibleRows: visibleRows,
            totalRowCount: rowStore.snapshot.totalRowCount,
            isRowLoaded: { rowStore.snapshot.row(at: $0) != nil },
            load: { range in
                await appState.loadTableSandboxSearchRows(range: range)
            },
            apply: { page in
                rowStore.hydrateSearchRows(
                    page.results,
                    startIndex: page.range.lowerBound,
                    totalRowCount: page.totalRowCount,
                    tableName: "test-search"
                )
            }
        )
    }
}

private struct WorkbenchTestShioriView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var shiori: ShioriStore
    @StateObject private var rowStore = TableSandboxRowModelStore()

    var body: some View {
        SubtitleTableView(
            tableName: "test-shiori",
            rowCount: rowStore.snapshot.totalRowCount,
            rowProvider: { rowStore.snapshot.row(at: $0) },
            rowsVersion: rowStore.snapshot.version,
            rowsUpdate: rowStore.snapshot.update,
            onVisibleRowsChange: { _ in },
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
