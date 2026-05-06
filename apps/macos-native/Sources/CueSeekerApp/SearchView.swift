import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inspectorDragStartWidth: Double?
    @State private var isInspectorDividerHovered = false
    @State private var isInspectorDividerDragging = false

    var body: some View {
        GeometryReader { geometry in
            let inspectorWidth = clampedInspectorWidth(for: geometry.size.width)

            HStack(spacing: 0) {
                searchResultsPane
                    .frame(minWidth: SearchLayout.searchPaneMinimumWidth, maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if appState.isPlaybackInspectorVisible {
                            inspectorResizeDivider(availableWidth: geometry.size.width)
                        }
                    }

                if appState.isPlaybackInspectorVisible {
                    playbackInspector
                        .frame(width: inspectorWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(.easeInOut(duration: 0.18), value: appState.isPlaybackInspectorVisible)
        }
    }

    private var searchResultsPane: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 6) {
                searchHeader

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
                } else if case .failed(let message) = appState.searchStatus, appState.searchResults.isEmpty {
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
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, AppShellLayout.contentTopPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .contentShape(Rectangle()) // Global scroll capability
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            SearchField(
                text: Binding(
                    get: { appState.searchQuery },
                    set: { appState.updateSearchQuery($0) }
                ),
                isFocused: $appState.isSearchFocused
            )
            .padding(.leading, 12)
            .padding(.trailing, 28) // 12 + 16px to account for the ScrollView scrollbar width

            if let searchResultSummaryText {
                HStack(spacing: 12) {
                    Text(searchResultSummaryText)
                        .font(.system(size: SearchTypography.detailSize))
                        .foregroundStyle(.secondary)

                    Text("Rendered \(appState.renderedSearchResultCount) results")
                        .font(.system(size: SearchTypography.detailSize))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if appState.hasSearchResultGroups {
                        Button {
                            appState.clearSearchFocus()
                            appState.toggleAllSearchResultGroups()
                        } label: {
                            Text(appState.searchResultGroupToggleTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 28)
            }
        }
    }

    private var searchResultSummaryText: String? {
        guard !appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        switch appState.searchStatus {
        case .idle:
            return nil
        case .searching where appState.searchResults.isEmpty:
            return nil
        case .failed where appState.searchResults.isEmpty:
            return nil
        case .searching, .completed, .failed:
            return "Found \(appState.searchResultTotalCount) results"
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.searchResultGroups) { group in
                    SearchResultGroupView(
                        group: group,
                        query: appState.searchQuery,
                        selectedResult: appState.selectedSearchResult,
                        onToggle: {
                            appState.clearSearchFocus()
                            appState.toggleSearchResultGroup(group.subtitlePath)
                        },
                        onOpenResult: { result in
                            appState.clearSearchFocus()
                            appState.openSearchResult(result)
                        },
                        onResultAppear: { result in
                            appState.loadMoreSearchResultsIfNeeded(currentResult: result)
                        }
                    )
                }

                if case .searching = appState.searchStatus, !appState.searchResults.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private var playbackInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let result = appState.selectedSearchResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PlaybackView(
                            player: appState.playbackPlayer,
                            viewModel: appState.playbackViewModel,
                            fullscreenManager: appState.playbackFullscreenManager,
                            onSurfaceTap: {
                                appState.clearSearchFocus()
                                appState.togglePlaybackFromUser()
                            },
                            onCopySubtitle: {
                                appState.clearSearchFocus()
                                appState.copyCurrentSubtitleToClipboard()
                            }
                        )
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if case .failed(let message) = appState.playbackStatus {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.system(size: SearchTypography.detailSize))
                                .foregroundStyle(.red)
                        }

                        MetadataField(
                            title: "Start Time",
                            value: formatTimestamp(result.startMilliseconds)
                        )

                        MetadataField(
                            title: "Video Path",
                            value: result.videoPath
                        )

                        MetadataField(
                            title: "Subtitle Path",
                            value: result.subtitlePath
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, AppShellLayout.contentTopPadding)
                    .padding([.horizontal, .bottom], 20)
                }
            } else {
                EmptyStateView(
                    title: "No Selection",
                    systemImage: "play.rectangle",
                    message: "Select a subtitle result to preview its matching video."
                )
                .font(.system(size: SearchTypography.detailSize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .simultaneousGesture(
            TapGesture().onEnded {
                appState.clearSearchFocus()
            }
        )
    }

    private func inspectorResizeDivider(availableWidth: CGFloat) -> some View {
        let isActive = isInspectorDividerHovered || isInspectorDividerDragging

        return ZStack(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.001))

            Rectangle()
                .fill(Color.black.opacity(isActive ? 0.18 : 0.08))
                .frame(width: isActive ? SearchLayout.dividerActiveLineWidth : SearchLayout.dividerLineWidth)
        }
            .frame(width: SearchLayout.dividerHitWidth)
            .overlay(
                ResizerView(
                    onHoverChanged: { isHovered in
                        isInspectorDividerHovered = isHovered
                    },
                    onDragStarted: {
                        appState.clearSearchFocus()
                        isInspectorDividerDragging = true
                        inspectorDragStartWidth = appState.playbackInspectorWidth
                    },
                    onDragChanged: { translationX in
                        let startWidth = inspectorDragStartWidth ?? appState.playbackInspectorWidth
                        let proposedWidth = startWidth - Double(translationX)
                        appState.updatePlaybackInspectorWidth(
                            clampedInspectorWidth(proposedWidth, availableWidth: availableWidth)
                        )
                    },
                    onDragEnded: {
                        inspectorDragStartWidth = nil
                        isInspectorDividerDragging = false
                    }
                )
            )
    }

    private func clampedInspectorWidth(for availableWidth: CGFloat) -> CGFloat {
        CGFloat(
            clampedInspectorWidth(
                appState.playbackInspectorWidth,
                availableWidth: availableWidth
            )
        )
    }

    private func clampedInspectorWidth(_ width: Double, availableWidth: CGFloat) -> Double {
        let availableInspectorWidth = Double(
            availableWidth
                - SearchLayout.searchPaneMinimumWidth
        )
        let maxWidth = max(
            SearchLayout.playbackInspectorMinimumWidth,
            availableInspectorWidth
        )

        return min(
            max(width, SearchLayout.playbackInspectorMinimumWidth),
            Double(maxWidth)
        )
    }
}

private struct SearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            SearchTextView(
                text: Binding(
                    get: { text },
                    set: { text = $0 }
                ),
                placeholder: "Search subtitles",
                isFocused: $isFocused
            )
            .frame(height: 22)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color(nsColor: .separatorColor).opacity(0.8) : Color.clear, lineWidth: isFocused ? 4 : 0)
        }
    }
}

private struct SearchResultGroupHeader: View {
    let group: SearchResultFileGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(headerText)
                .font(.system(size: SearchTypography.groupHeaderSize))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 7)
                .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
                .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
    }

    private var headerText: AttributedString {
        var filename = AttributedString(filenameWithSoftWrapOpportunities(group.subtitleFileName))
        filename.foregroundColor = isSelected ? .primary : Color.primary.opacity(0.76)

        var count = AttributedString("  \(resultCountText)")
        count.foregroundColor = Color.secondary

        filename.append(count)
        return filename
    }

    private var resultCountText: String {
        "\(group.totalCount) \(group.totalCount == 1 ? "result" : "results")"
    }
}

private struct SearchResultGroupView: View {
    let group: SearchResultFileGroup
    let query: String
    let selectedResult: SubtitleSearchResult?
    let onToggle: () -> Void
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchResultGroupHeader(
                group: group,
                isSelected: selectedResult?.subtitlePath == group.subtitlePath,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                ForEach(group.results, id: \.entryID) { result in
                    let isSelected = selectedResult?.entryID == result.entryID

                    Button {
                        onOpenResult(result)
                    } label: {
                        SearchResultRow(
                            result: result,
                            query: query,
                            isSelected: isSelected
                        )
                    }
                    .buttonStyle(StaticButtonStyle())
                    .onAppear {
                        onResultAppear(result)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            SearchResultGroupRail(
                isCollapsed: group.isCollapsed,
                showsLine: !group.isCollapsed && !group.results.isEmpty,
                onToggle: onToggle
            )
        }
    }
}

private struct SearchResultGroupRail: View {
    let isCollapsed: Bool
    let showsLine: Bool
    let onToggle: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let lineTop = SearchLayout.groupRailTriangleTopPadding
                + SearchLayout.groupRailTriangleSize
                + SearchLayout.groupRailLineTopSpacing
            let lineHeight = max(CGFloat.zero, geometry.size.height - lineTop)
            let lineX = SearchLayout.resultOuterHorizontalPadding
                + SearchLayout.groupDisclosureWidth / 2

            ZStack(alignment: .topLeading) {
                if showsLine && lineHeight > 0 {
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: SearchLayout.groupRailLineWidth, height: lineHeight)
                        .offset(
                            x: lineX - SearchLayout.groupRailLineWidth / 2,
                            y: lineTop
                        )
                }

                Button(action: onToggle) {
                    SearchResultDisclosureTriangle()
                        .stroke(
                            Color.secondary,
                            style: StrokeStyle(
                                lineWidth: SearchLayout.groupRailTriangleLineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(
                            width: SearchLayout.groupRailTriangleSize,
                            height: SearchLayout.groupRailTriangleSize
                        )
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .frame(
                            width: SearchLayout.groupDisclosureWidth,
                            height: SearchLayout.groupRailTriangleSize,
                            alignment: .center
                        )
                }
                .buttonStyle(StaticButtonStyle())
                .offset(
                    x: SearchLayout.resultOuterHorizontalPadding,
                    y: SearchLayout.groupRailTriangleTopPadding
                )
            }
        }
        .frame(width: SearchLayout.resultSelectionLeadingPadding)
    }
}

private struct SearchResultDisclosureTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct SearchResultRow: View {
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        let rowTextColor: Color = isSelected ? .primary : Color.primary.opacity(0.76)
        let rowBackgroundColor: Color = if isSelected {
            Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        } else if isHovered {
            Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.55)
        } else {
            Color.clear
        }

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(highlightedContent(line, query: query, textColor: rowTextColor, isSelected: isSelected))
                            .font(.system(size: SearchTypography.bodySize))
                            .foregroundStyle(rowTextColor)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatTimestamp(result.startMilliseconds))
                    .font(.system(size: SearchTypography.detailSize))
                    .monospacedDigit()
                    .foregroundStyle(rowTextColor)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .padding(.leading, SearchLayout.resultTextLeadingPadding)
            .padding(.trailing, SearchLayout.resultTimestampTrailingPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var displayLines: [String] {
        let lines = result.cueLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [result.content] : lines
    }
}

private struct MetadataField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: SearchTypography.metadataLabelSize, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: SearchTypography.detailSize))
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ResizerView: NSViewRepresentable {
    var onHoverChanged: (Bool) -> Void
    var onDragStarted: () -> Void
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> ResizerNSView {
        let view = ResizerNSView()
        view.onHoverChanged = onHoverChanged
        view.onDragStarted = onDragStarted
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: ResizerNSView, context: Context) {
        nsView.onHoverChanged = onHoverChanged
        nsView.onDragStarted = onDragStarted
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
    }
}

private final class ResizerNSView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?

    private var startLocation: NSPoint?
    private var trackingArea: NSTrackingArea?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        startLocation = event.locationInWindow
        onDragStarted?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startLocation = startLocation else { return }
        let delta = event.locationInWindow.x - startLocation.x
        onDragChanged?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        startLocation = nil
        onDragEnded?()
    }
}
private enum SearchTypography {
    static let searchFieldSize: CGFloat = 16
    static let groupHeaderSize: CGFloat = 13
    static let bodySize: CGFloat = 14
    static let detailSize: CGFloat = 12
    static let metadataLabelSize: CGFloat = 13
}

private enum SearchLayout {
    static let contentWidth: CGFloat = 860
    static let minimumHorizontalMargin: CGFloat = 24
    static let searchPaneMinimumWidth: CGFloat = 480
    static let playbackInspectorMinimumWidth: Double = 380
    static let dividerHitWidth: CGFloat = 6
    static let dividerLineWidth: CGFloat = 1
    static let dividerActiveLineWidth: CGFloat = 3
    static let resultOuterHorizontalPadding: CGFloat = 12
    static let resultTimestampTrailingPadding: CGFloat = 10
    static let groupDisclosureWidth: CGFloat = 16
    static let groupRailTriangleSize: CGFloat = 8
    static let groupRailTriangleLineWidth: CGFloat = 1.5
    static let groupRailTriangleTopPadding: CGFloat = 12
    static let groupRailLineTopSpacing: CGFloat = 2
    static let groupRailLineWidth: CGFloat = 1
    static let resultSelectionLeadingPadding: CGFloat = resultOuterHorizontalPadding + groupDisclosureWidth
    static let resultTextLeadingPadding: CGFloat = resultTimestampTrailingPadding
}

private func filenameWithSoftWrapOpportunities(_ filename: String) -> String {
    let zeroWidthSpace = "\u{200B}"
    let softBreakCharacters: Set<Character> = ["]", ".", "_", "-"]
    var wrapped = ""

    for character in filename {
        wrapped.append(character)
        if softBreakCharacters.contains(character) {
            wrapped.append(zeroWidthSpace)
        }
    }

    return wrapped
}

private func highlightedContent(_ content: String, query: String, textColor: Color, isSelected: Bool = false) -> AttributedString {
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
                highlighted[lowerBound..<upperBound].inlinePresentationIntent = .stronglyEmphasized
                highlighted[lowerBound..<upperBound].backgroundColor = Color.yellow.opacity(isSelected ? 0.7 : 0.4)
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
