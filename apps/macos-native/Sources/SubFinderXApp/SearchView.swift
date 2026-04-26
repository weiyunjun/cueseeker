import SwiftUI

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Search subtitles", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: "No Search Query",
                    systemImage: "text.magnifyingglass",
                    message: "Add subtitle folders in Settings, then search indexed subtitle text."
                )
            } else {
                EmptyStateView(
                    title: "Search Index Not Ready",
                    systemImage: "tray",
                    message: "Subtitle scanning, SQLite indexing, and FTS search will be added next."
                )
            }

            Spacer()
        }
        .padding(24)
        .navigationTitle("Search")
    }
}
