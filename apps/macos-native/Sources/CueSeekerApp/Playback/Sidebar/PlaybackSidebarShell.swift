import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackSidebarShell: View {
    private static let estimatedSearchResultRowHeight: CGFloat = 76

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
        PlaybackSidebarVirtualList(
            rowCount: searchNavigationTotalCount,
            rowHeight: Self.estimatedSearchResultRowHeight,
            rowsVersion: search.searchNavigationVisibleRowsVersion,
            scrollTargetRow: activeSearchRank,
            scrollTargetVersion: activeSearchScrollTargetVersion,
            onVisibleRowsChange: { rows in
                appState.loadSearchNavigationVisibleWindow(rows: rows)
            },
            rowContent: { row in
                searchResultRow(at: row)
            }
        )
    }

    private func searchResultRow(at row: Int) -> AnyView {
        guard let result = search.searchNavigationVisibleResult(at: row) else {
            return AnyView(Color.clear)
        }

        return AnyView(
            PlaybackSidebarResultRow(
                rank: row + 1,
                result: result,
                query: search.searchQuery,
                isSelected: isActiveSearchResult(result),
                onOpen: { appState.openSearchResult(result) }
            )
            .frame(height: Self.estimatedSearchResultRowHeight, alignment: .top)
            .clipped()
        )
    }

    private var searchNavigationTotalCount: Int {
        max(
            search.searchNavigationVisibleTotalCount,
            search.searchNavigationSnapshot?.totalCount ?? 0,
            search.searchResultTotalCount,
            search.searchResults.count
        )
    }

    private var activeSearchRank: Int? {
        if let currentIndex = search.searchNavigationSnapshot?.currentIndex {
            return currentIndex
        }

        guard let selected = search.selectedSearchResult,
              selected.searchRank >= 0
        else {
            return nil
        }
        return selected.searchRank
    }

    private var activeSearchScrollTargetVersion: Int {
        if let snapshot = search.searchNavigationSnapshot,
           let currentIndex = snapshot.currentIndex {
            let currentID = snapshot.current?.entryID ?? -1
            return currentIndex ^ Int(truncatingIfNeeded: currentID)
        }

        guard let selected = search.selectedSearchResult else {
            return 0
        }
        return selected.searchRank ^ Int(truncatingIfNeeded: selected.entryID)
    }

    private func isActiveSearchResult(_ result: SubtitleSearchResult) -> Bool {
        if let current = search.searchNavigationSnapshot?.current {
            return result.entryID == current.entryID
        }

        return result.entryID == search.selectedSearchResult?.entryID
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
            let count = playback.currentSubtitleEntryTotalCount > 0
                ? playback.currentSubtitleEntryTotalCount
                : playback.currentSubtitleEntries.count
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

@MainActor
func configurePlaybackSidebarScrollView(_ scrollView: NSScrollView) {
    let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    scrollView.drawsBackground = false
    scrollView.backgroundColor = .clear
    scrollView.contentView.drawsBackground = false
    scrollView.contentView.backgroundColor = .clear

    scrollView.borderType = .noBorder
    scrollView.scrollerStyle = .overlay
    scrollView.scrollerKnobStyle = .light
    scrollView.scrollerInsets = zeroInsets
    scrollView.contentInsets = zeroInsets
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentView.contentInsets = zeroInsets
    scrollView.contentView.automaticallyAdjustsContentInsets = false

    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    if !(scrollView.verticalScroller is PlaybackTransparentScroller) {
        let replacement = PlaybackTransparentScroller(
            frame: scrollView.verticalScroller?.frame ?? .zero
        )
        replacement.controlSize = scrollView.verticalScroller?.controlSize ?? .regular
        replacement.scrollerStyle = .overlay
        replacement.knobStyle = .light
        scrollView.verticalScroller = replacement
    }

    scrollView.verticalScroller?.isHidden = false
    scrollView.verticalScroller?.scrollerStyle = .overlay
    scrollView.verticalScroller?.knobStyle = .light
    scrollView.horizontalScroller?.isHidden = true

    let darkAppearance = NSAppearance(named: .darkAqua)
    scrollView.appearance = darkAppearance
    scrollView.verticalScroller?.appearance = darkAppearance
}

private final class PlaybackTransparentScroller: NSScroller {
    private static let fixedKnobWidth: CGFloat = 6
    private static let knobAlpha: CGFloat = 0.58

    override class var isCompatibleWithOverlayScrollers: Bool {
        true
    }

    override func drawKnob() {
        let knobRect = rect(for: .knob)
        guard !knobRect.isEmpty else {
            return
        }

        let width = min(Self.fixedKnobWidth, knobRect.width)
        let horizontalInset = max(0, (knobRect.width - width) / 2)
        let fixedRect = knobRect.insetBy(dx: horizontalInset, dy: 0)

        NSColor.white.withAlphaComponent(Self.knobAlpha).setFill()
        NSBezierPath(
            roundedRect: fixedRect,
            xRadius: width / 2,
            yRadius: width / 2
        )
        .fill()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Keep the system knob, but make the track/gutter transparent.
    }
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
