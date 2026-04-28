import AppKit
import Foundation
import SwiftUI
import SubFinderXCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inspectorDragStartWidth: Double?
    @State private var isInspectorDividerHovered = false
    @State private var isInspectorDividerDragging = false
    @State private var isSearchFocused = false

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
        .onReceive(appState.$selectedSection) { section in
            if section != .search {
                isSearchFocused = false
            }
        }
    }

    private var searchResultsPane: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 16) {
                SearchField(
                    text: Binding(
                        get: { appState.searchQuery },
                        set: { appState.updateSearchQuery($0) }
                    ),
                    isFocused: $isSearchFocused
                )
                .padding(.leading, 12)
                .padding(.trailing, 28) // 12 + 16px to account for the ScrollView scrollbar width

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
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, AppShellLayout.contentTopPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .contentShape(Rectangle()) // Global scroll capability
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(appState.searchResults.enumerated()), id: \.element.entryID) { index, result in
                    let isSelected = appState.selectedSearchResult?.entryID == result.entryID
                    let isNextSelected = index + 1 < appState.searchResults.count && appState.selectedSearchResult?.entryID == appState.searchResults[index + 1].entryID
                    let isLast = index == appState.searchResults.count - 1

                    Button {
                        isSearchFocused = false
                        appState.openSearchResult(result)
                    } label: {
                        SearchResultRow(
                            result: result,
                            query: appState.searchQuery,
                            isSelected: isSelected,
                            showDivider: !isSelected && !isNextSelected && !isLast
                        )
                    }
                    .buttonStyle(StaticButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var playbackInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let result = appState.selectedSearchResult {
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
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: isFocused ? 2 : 0)
        }
    }
}

private struct SearchResultRow: View {
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(highlightedContent(result.content, query: query, isSelected: isSelected))
                    .font(.system(size: SearchTypography.bodySize))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(URL(fileURLWithPath: result.subtitlePath).lastPathComponent)
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.accentColor : Color.clear
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            
            Rectangle()
                .fill(showDivider ? Color(nsColor: .separatorColor) : Color.clear)
                .frame(height: 1)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
}

private func highlightedContent(_ content: String, query: String, isSelected: Bool = false) -> AttributedString {
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
                if isSelected {
                    highlighted[lowerBound..<upperBound].foregroundColor = .white
                } else {
                    highlighted[lowerBound..<upperBound].backgroundColor = Color.yellow.opacity(0.55)
                    highlighted[lowerBound..<upperBound].foregroundColor = Color.primary
                }
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
