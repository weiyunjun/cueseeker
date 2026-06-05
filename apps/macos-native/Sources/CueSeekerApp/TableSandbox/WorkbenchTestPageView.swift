import SwiftUI

/// Table-style UI sandbox pages, reachable only through the top-bar test icons
/// so production views stay untouched. Library stays blank per requirement;
/// Search/Shiori host the AppKit table. Phase B feeds the table static sample
/// data; Phase C will wire real search results / Shiori entries and playback.
struct WorkbenchTestPageView: View {
    let page: WorkbenchTestPage

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            switch page {
            case .library:
                EmptyView()
            case .search, .shiori:
                SubtitleTableView(
                    rows: SubtitleTableSampleData.rows,
                    onPlay: { row in
                        // Phase B: sample data only; real playback is wired in Phase C.
                        NSLog("[TableSandbox] play tapped for row: %@", row.name)
                    }
                )
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
