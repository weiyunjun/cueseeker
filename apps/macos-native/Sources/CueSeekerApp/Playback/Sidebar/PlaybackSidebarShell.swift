import CueSeekerCore
import SwiftUI

struct PlaybackSidebarShell: View {
    @ObservedObject var appState: AppCoordinator
    @Binding var activePanel: PlaybackDrawerKind
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var playback: PlaybackStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 2) {
                    sidebarTab(.results, title: "Search Results")
                    sidebarTab(.subtitles, title: "Subtitles")
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(0.08))
                )

                Text(summaryText)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .monospacedDigit()
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            content
        }
        // The opaque rounded surface, border, and shadow are owned by the
        // floating container in PlaybackPageView. The shell only renders
        // content; it no longer draws the old squeeze-era background or the
        // left divider.
    }

    @ViewBuilder
    private var content: some View {
        if playback.isPlaybackSidePanelVisible {
            switch activePanel {
            case .results:
                searchResultsList
            case .subtitles:
                if let viewModel = playback.playbackViewModel {
                    PlaybackSubtitlesList(appState: appState, viewModel: viewModel)
                } else {
                    Spacer(minLength: 0)
                }
            }
        } else {
            Spacer(minLength: 0)
        }
    }

    private var searchResultsList: some View {
        let rows = flattenedResultRows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows, id: \.result.entryID) { row in
                        PlaybackSidebarResultRow(
                            rank: row.rank,
                            result: row.result,
                            query: search.searchQuery,
                            isSelected: row.result.entryID
                                == search.selectedSearchResult?.entryID,
                            onOpen: { appState.openSearchResult(row.result) }
                        )
                        .id(row.result.entryID)
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 14, trailing: 8))
            }
            .background(ScrollViewIntrospector { scrollView in
                scrollView.drawsBackground = false
                scrollView.borderType = .noBorder
                scrollView.scrollerStyle = .overlay
                scrollView.hasVerticalScroller = false
                scrollView.verticalScroller = nil
                scrollView.appearance = NSAppearance(named: .darkAqua)
            })
            .onAppear { scrollSelectedIntoView(proxy) }
            .onChange(of: search.selectedSearchResult?.entryID) { _ in
                scrollSelectedIntoView(proxy)
            }
        }
    }

    private func scrollSelectedIntoView(_ proxy: ScrollViewProxy) {
        guard let id = search.selectedSearchResult?.entryID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    /// The complete active Search result order, flattened across file groups
    /// with a global one-based rank to mirror the prototype `.sidebar-list`.
    /// Reads only the published navigation groups, so result-to-result jumps
    /// never clear the list while the current Search result list is valid.
    private var flattenedResultRows: [(rank: Int, result: SubtitleSearchResult)] {
        var rows: [(rank: Int, result: SubtitleSearchResult)] = []
        var rank = 1
        for group in search.searchNavigationResultGroups {
            for result in group.results {
                rows.append((rank: rank, result: result))
                rank += 1
            }
        }
        return rows
    }

    private func sidebarTab(_ panel: PlaybackDrawerKind, title: String) -> some View {
        let isActive = activePanel == panel
        return Button {
            activePanel = panel
            switch panel {
            case .results:
                appState.refreshSearchNavigationSnapshot()
            case .subtitles:
                appState.refreshCurrentSubtitleEntries()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.60))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive ? Color.black.opacity(0.24) : Color.clear)
                        .shadow(
                            color: isActive ? Color.black.opacity(0.15) : Color.clear,
                            radius: 1,
                            y: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        switch activePanel {
        case .results:
            let groupedCount = search.searchNavigationResultGroups.reduce(0) { $0 + $1.results.count }
            let fallbackCount = search.searchResultTotalCount > 0
                ? search.searchResultTotalCount
                : search.searchResults.count
            let count = search.searchNavigationSnapshot?.totalCount
                ?? (groupedCount > 0 ? groupedCount : fallbackCount)
            return "\(count) \(count == 1 ? "result" : "results")"
        case .subtitles:
            let count = playback.currentSubtitleEntries.count
            return "\(count) \(count == 1 ? "subtitle" : "subtitles")"
        }
    }
}

/// Hosts the playback feedback HUD above the centered overlay panel so command
/// feedback is never occluded by it (doc 12 §11/§13.4, doc 11 §6). This is the
/// cinematic sidebar geometry: a right-aligned floating overlay that never
/// squeezes the video — `top: 46px; right: 20px; bottom: 104px;
/// width: min(300px, calc(100% - 40px))`.
enum PlaybackOverlayPanelMetrics {
    static let topInset: CGFloat = 46
    static let bottomInset: CGFloat = 104
    static let horizontalMargin: CGFloat = 24
    static let maxWidth: CGFloat = 300
}

struct ScrollViewIntrospector: NSViewRepresentable {
    let customize: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = findScrollView(for: view) {
                customize(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = findScrollView(for: nsView) {
                customize(scrollView)
            }
        }
    }

    private func findScrollView(for view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let next = current?.superview {
            if let scrollView = next as? NSScrollView {
                return scrollView
            }
            current = next
        }
        return nil
    }
}
