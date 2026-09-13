import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var routeState: WorkbenchRouteState
    // Observed so a Excerpt detail turns into the unknown page when its list
    // leaves the overview.
    @EnvironmentObject private var excerptStore: ExcerptStore
    @EnvironmentObject private var playback: PlaybackStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppPerformanceProbe.measure("SearchView.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.Workbench.body",
                scope: appState.uiProbeScope
            )

            return GeometryReader { geometry in
                let showsPlaybackRoute = appState.isPlaybackPageVisible

                ZStack {
                    mainContent
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipped()
                        .allowsHitTesting(!showsPlaybackRoute)

                    if showsPlaybackRoute {
                        PlaybackPageView(
                            playbackSurface: AnyView(playbackSurface),
                            appState: appState,
                            onClose: {
                                appState.workbenchLayout.clearSearchFocus()
                                appState.stopPlayback()
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .zIndex(10)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(LayoutPerformanceProbe(name: "SearchView.root.layout"))
                // This is where the playback page is routed over the whole
                // workbench, so this is where that layer is registered.
                .onAppear {
                    appState.interfaceLayers.setOpen(
                        .playbackPage,
                        showsPlaybackRoute
                    )
                }
                .onChange(of: showsPlaybackRoute) { isOpen in
                    appState.interfaceLayers.setOpen(.playbackPage, isOpen)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        AppPerformanceProbe.measure("SearchView.mainContent.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.WorkbenchMainContent.body",
                scope: appState.uiProbeScope,
                details: "mode=\(routeState.panelMode.rawValue)"
            )

            return Group {
                switch routeState.panelMode {
                case .excerpt:
                    workbenchExcerptSurface
                case .recentWatching:
                    WorkbenchRecentView()
                case .testLibrary:
                    WorkbenchTestLibraryView()
                case .file:
                    WorkbenchFileView(tasks: appState.tasks)
                case .search:
                    workbenchSearchSurface
                }
            }
        }
    }

    private var playbackSurface: some View {
        PlaybackView(
            player: appState.playbackPlayer,
            viewModel: playback.playbackViewModel,
            uiProbeScope: appState.uiProbeScope,
            onSurfaceTap: {
                appState.workbenchLayout.clearSearchFocus()
                appState.togglePlaybackFromUser()
            }
        )
    }

    private var workbenchSearchSurface: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            WorkbenchTestSearchView(
                rowStore: appState.search.tableRowStore,
                isTableResponseActive: !appState.isPlaybackPageVisible
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workbenchExcerptSurface: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            if let listID = routeState.selectedExcerptListID {
                if appState.isWorkbenchRouteUnknown(.excerptList(id: listID)) {
                    WorkbenchUnknownPage()
                } else {
                    WorkbenchExcerptTableView(
                        isTableResponseActive: !appState.isPlaybackPageVisible
                    )
                }
            } else {
                ExcerptListOverviewView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private extension View {
    func listRowAction(_ action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text(L("library.activate")), action)
    }
}






enum SearchHighlightState {
    case `default`
    case hover
    case selected
}

enum SearchHighlightTokens {
    static let `default` = Color(red: 1.0, green: 224.0 / 255.0, blue: 102.0 / 255.0)
    static let hover = Color(red: 1.0, green: 203.0 / 255.0, blue: 31.0 / 255.0)
    static let onSelected = Color.white.opacity(0.30)
}

func displayTitleWithSoftWrapOpportunities(_ displayTitle: String) -> String {
    let zeroWidthSpace = "\u{200B}"
    let softBreakCharacters: Set<Character> = ["]", ".", "_", "-"]
    var wrapped = ""

    for character in displayTitle {
        wrapped.append(character)
        if softBreakCharacters.contains(character) {
            wrapped.append(zeroWidthSpace)
        }
    }

    return wrapped
}

func highlightedContent(
    _ content: String,
    query: String,
    textColor: Color,
    state: SearchHighlightState,
    highlightBackgroundColor: Color? = nil
) -> AttributedString {
    var highlighted = AttributedString(content)
    let terms = highlightTerms(from: query)

    let bg: Color
    if let customBg = highlightBackgroundColor {
        bg = customBg
    } else {
        switch state {
        case .default:
            bg = SearchHighlightTokens.default
        case .hover:
            bg = SearchHighlightTokens.hover
        case .selected:
            bg = SearchHighlightTokens.onSelected
        }
    }

    for term in terms {
        var searchRange = content.startIndex..<content.endIndex

        while let match = content.range(
            of: term,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            if let lowerBound = AttributedString.Index(match.lowerBound, within: highlighted),
               let upperBound = AttributedString.Index(match.upperBound, within: highlighted) {
                highlighted[lowerBound..<upperBound].inlinePresentationIntent = .stronglyEmphasized
                highlighted[lowerBound..<upperBound].backgroundColor = bg
                highlighted[lowerBound..<upperBound].foregroundColor = textColor
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

func formatTimestamp(_ milliseconds: Int) -> String {
    let totalSeconds = milliseconds / 1_000
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

func subtitleDisplayLines(content: String, cueLines: [String]) -> [String] {
    let lines = (cueLines.isEmpty ? content.components(separatedBy: .newlines) : cueLines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    return lines.isEmpty ? [content] : lines
}
