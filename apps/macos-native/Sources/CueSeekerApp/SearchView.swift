import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @State private var libraryPanelDragStartWidth: Double?
    @State private var isLibraryPanelDividerHovered = false
    @State private var isLibraryPanelDividerDragging = false
    @State private var searchPanelDragStartWidth: Double?
    @State private var isSearchPanelDividerHovered = false
    @State private var isSearchPanelDividerDragging = false

    var body: some View {
        GeometryReader { geometry in
            let libraryPanelWidth = libraryPanelWidth(for: geometry.size.width)
            let searchPanelWidth = clampedSearchPanelWidth(for: geometry.size.width)

            HStack(spacing: 0) {
                DrawerPanel(
                    edge: .leading,
                    isVisible: appState.isLibraryPanelVisible,
                    width: libraryPanelWidth
                ) {
                    libraryPanel
                } divider: {
                    libraryPanelResizeDivider(availableWidth: geometry.size.width)
                }

                playbackArea
                    .frame(minWidth: SearchLayout.playbackAreaMinimumWidth, maxWidth: .infinity)

                DrawerPanel(
                    edge: .trailing,
                    isVisible: appState.isSearchPanelVisible,
                    width: searchPanelWidth
                ) {
                    searchPanel
                } divider: {
                    searchPanelResizeDivider(availableWidth: geometry.size.width)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(.easeInOut(duration: 0.18), value: appState.isLibraryPanelVisible)
            .animation(.easeInOut(duration: 0.18), value: appState.isSearchPanelVisible)
        }
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            libraryHeader

            if appState.selectedFolders.isEmpty {
                EmptyStateView(
                    title: "No Library",
                    systemImage: "folder",
                    message: "Add subtitle folders in CueSeeker > Settings..., then reindex."
                )
                .font(.system(size: SearchTypography.bodySize))
            } else if case .loading = appState.libraryStatus, appState.libraryVideos.isEmpty {
                EmptyStateView(
                    title: "Loading Library",
                    systemImage: "folder",
                    message: "Reading indexed videos."
                )
                .font(.system(size: SearchTypography.bodySize))
                .overlay {
                    ProgressView()
                        .offset(y: 72)
                }
            } else if case .failed(let message) = appState.libraryStatus {
                EmptyStateView(
                    title: "Library Failed",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
                .font(.system(size: SearchTypography.bodySize))
            } else if appState.libraryVideos.isEmpty {
                EmptyStateView(
                    title: "No Videos",
                    systemImage: "play.rectangle",
                    message: "Reindex subtitle folders to populate Library videos."
                )
                .font(.system(size: SearchTypography.bodySize))
            } else {
                libraryList
            }

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, AppShellLayout.contentTopPadding)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var libraryHeader: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if appState.hasLibraryFolderGroups {
                Button {
                    appState.clearSearchFocus()
                    appState.toggleAllLibraryFolderGroups()
                } label: {
                    Text(appState.libraryGroupToggleTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(height: 36)
    }

    private var libraryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.libraryFolderGroups) { group in
                    LibraryFolderGroupView(
                        group: group,
                        selectedVideoPath: appState.currentPlaybackVideoPath,
                        onToggle: {
                            appState.clearSearchFocus()
                            appState.toggleLibraryFolderGroup(group.folderPath)
                        },
                        onOpenVideo: { video in
                            appState.clearSearchFocus()
                            appState.openLibraryVideo(video)
                        }
                    )
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private var searchPanel: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 6) {
                searchHeader

                if appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyStateView(
                        title: "No Search Query",
                        systemImage: "text.magnifyingglass",
                        message: "Add subtitle folders in CueSeeker > Settings..., then search indexed subtitle text."
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
        .background(Color(nsColor: .textBackgroundColor))
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

    private var playbackArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.hasPlaybackSelection {
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
                            },
                            isFullscreenToggleDisabled: appState.isVideoSizeTransitionInProgress,
                            onToggleFullscreen: {
                                appState.clearSearchFocus()
                                appState.togglePlaybackFullscreenFromUser {
                                    appState.copyCurrentSubtitleToClipboard()
                                }
                            }
                        )
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if case .failed(let message) = appState.playbackStatus {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.system(size: SearchTypography.detailSize))
                                .foregroundStyle(.red)
                        }

                        HStack(spacing: 12) {
                            Button {
                                appState.clearSearchFocus()
                                appState.revealCurrentVideoFile()
                            } label: {
                                Label("Video Folder", systemImage: "folder")
                            }

                            if appState.currentPlaybackSubtitlePath != nil {
                                Button {
                                    appState.clearSearchFocus()
                                    appState.revealCurrentSubtitleFile()
                                } label: {
                                    Label("Subtitle Folder", systemImage: "folder")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, AppShellLayout.contentTopPadding)
                    .padding([.horizontal, .bottom], 20)
                }
            } else {
                EmptyStateView(
                    title: "No Selection",
                    systemImage: "play.rectangle",
                    message: "Select a Library video or subtitle result to preview playback."
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

    private func searchPanelResizeDivider(availableWidth: CGFloat) -> some View {
        let isActive = isSearchPanelDividerHovered || isSearchPanelDividerDragging

        return ZStack(alignment: .leading) {
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
                        isSearchPanelDividerHovered = isHovered
                    },
                    onDragStarted: {
                        appState.clearSearchFocus()
                        isSearchPanelDividerDragging = true
                        searchPanelDragStartWidth = appState.searchPanelWidth
                    },
                    onDragChanged: { translationX in
                        let startWidth = searchPanelDragStartWidth ?? appState.searchPanelWidth
                        let proposedWidth = startWidth - Double(translationX)
                        appState.updateSearchPanelWidth(
                            clampedSearchPanelWidth(proposedWidth, availableWidth: availableWidth)
                        )
                    },
                    onDragEnded: {
                        searchPanelDragStartWidth = nil
                        isSearchPanelDividerDragging = false
                    }
                )
            )
    }

    private func libraryPanelResizeDivider(availableWidth: CGFloat) -> some View {
        let isActive = isLibraryPanelDividerHovered || isLibraryPanelDividerDragging

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
                        isLibraryPanelDividerHovered = isHovered
                    },
                    onDragStarted: {
                        appState.clearSearchFocus()
                        isLibraryPanelDividerDragging = true
                        libraryPanelDragStartWidth = appState.libraryPanelWidth
                    },
                    onDragChanged: { translationX in
                        let startWidth = libraryPanelDragStartWidth ?? appState.libraryPanelWidth
                        let proposedWidth = startWidth + Double(translationX)
                        appState.updateLibraryPanelWidth(
                            clampedLibraryPanelWidth(proposedWidth, availableWidth: availableWidth)
                        )
                    },
                    onDragEnded: {
                        libraryPanelDragStartWidth = nil
                        isLibraryPanelDividerDragging = false
                    }
                )
            )
    }

    private func libraryPanelWidth(for availableWidth: CGFloat) -> CGFloat {
        CGFloat(
            clampedLibraryPanelWidth(
                appState.libraryPanelWidth,
                availableWidth: availableWidth
            )
        )
    }

    private func clampedLibraryPanelWidth(_ width: Double, availableWidth: CGFloat) -> Double {
        let reservedSearchPanelWidth = appState.isSearchPanelVisible
            ? SearchLayout.searchPanelMinimumWidth
            : 0
        let availableLibraryPanelWidth = Double(
            availableWidth
                - reservedSearchPanelWidth
                - SearchLayout.playbackAreaMinimumWidth
        )
        let maxWidth = max(
            SearchLayout.libraryPanelMinimumWidth,
            availableLibraryPanelWidth
        )

        return min(
            max(width, SearchLayout.libraryPanelMinimumWidth),
            maxWidth
        )
    }

    private func clampedSearchPanelWidth(for availableWidth: CGFloat) -> CGFloat {
        CGFloat(
            clampedSearchPanelWidth(
                appState.searchPanelWidth,
                availableWidth: availableWidth
            )
        )
    }

    private func clampedSearchPanelWidth(_ width: Double, availableWidth: CGFloat) -> Double {
        let availableSearchPanelWidth = Double(
            availableWidth
                - (appState.isLibraryPanelVisible ? libraryPanelWidth(for: availableWidth) : 0)
                - SearchLayout.playbackAreaMinimumWidth
        )
        let maxWidth = max(
            SearchLayout.searchPanelMinimumWidth,
            availableSearchPanelWidth
        )

        return min(
            max(width, SearchLayout.searchPanelMinimumWidth),
            Double(maxWidth)
        )
    }
}

private enum DrawerPanelEdge {
    case leading
    case trailing

    var alignment: Alignment {
        switch self {
        case .leading:
            return .topLeading
        case .trailing:
            return .topTrailing
        }
    }

    func hiddenOffset(for width: CGFloat) -> CGFloat {
        switch self {
        case .leading:
            return -width
        case .trailing:
            return width
        }
    }

    var dividerAlignment: Alignment {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        }
    }
}

private struct DrawerPanel<Content: View, Divider: View>: View {
    let edge: DrawerPanelEdge
    let isVisible: Bool
    let width: CGFloat
    let content: Content
    let divider: Divider

    init(
        edge: DrawerPanelEdge,
        isVisible: Bool,
        width: CGFloat,
        @ViewBuilder content: () -> Content,
        @ViewBuilder divider: () -> Divider
    ) {
        self.edge = edge
        self.isVisible = isVisible
        self.width = width
        self.content = content()
        self.divider = divider()
    }

    var body: some View {
        Color.clear
            .frame(width: isVisible ? width : 0)
            .frame(maxHeight: .infinity)
            .overlay(alignment: edge.alignment) {
                content
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: edge.dividerAlignment) {
                        divider
                    }
                    .offset(x: isVisible ? 0 : edge.hiddenOffset(for: width))
            }
            .clipped()
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
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

private struct LibraryFolderGroupHeader: View {
    let group: LibraryFolderGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(headerText)
                .font(.system(size: SearchTypography.groupHeaderSize))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.vertical, 7)
                .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
                .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
    }

    private var headerText: AttributedString {
        var title = AttributedString(group.folderTitle)
        title.foregroundColor = isSelected ? .primary : Color.primary.opacity(0.76)

        var count = AttributedString("  \(videoCountText)")
        count.foregroundColor = Color.secondary

        title.append(count)
        return title
    }

    private var videoCountText: String {
        "\(group.videos.count) \(group.videos.count == 1 ? "video" : "videos")"
    }
}

private struct LibraryFolderGroupView: View {
    let group: LibraryFolderGroup
    let selectedVideoPath: String?
    let onToggle: () -> Void
    let onOpenVideo: (LibraryVideo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LibraryFolderGroupHeader(
                group: group,
                isSelected: group.videos.contains { $0.video.videoPath == selectedVideoPath },
                onToggle: onToggle
            )

            if !group.isCollapsed {
                ForEach(group.videos) { row in
                    Button {
                        onOpenVideo(row.video)
                    } label: {
                        LibraryVideoRowView(
                            row: row,
                            isSelected: selectedVideoPath == row.video.videoPath
                        )
                    }
                    .buttonStyle(StaticButtonStyle())
                    .focusable(false)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            SearchResultGroupRail(
                isCollapsed: group.isCollapsed,
                showsLine: !group.isCollapsed && !group.videos.isEmpty,
                onToggle: onToggle
            )
        }
    }
}

private struct LibraryVideoRowView: View {
    let row: LibraryVideoRow
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

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(rowTitle)
                .font(.system(size: SearchTypography.bodySize))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(rowTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatDuration(row.duration))
                .font(.system(size: SearchTypography.detailSize))
                .monospacedDigit()
                .foregroundStyle(rowTextColor)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
        .padding(.leading, SearchLayout.resultTextLeadingPadding)
        .padding(.trailing, SearchLayout.resultTextHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
        .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var rowTitle: String {
        guard !row.fileExtension.isEmpty else {
            return row.displayTitle
        }

        return "\(row.displayTitle)  \(row.fileExtension)"
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
        .focusable(false)
    }

    private var headerText: AttributedString {
        var displayTitle = AttributedString(displayTitleWithSoftWrapOpportunities(group.subtitleDisplayTitle))
        displayTitle.foregroundColor = isSelected ? .primary : Color.primary.opacity(0.76)

        var count = AttributedString("  \(resultCountText)")
        count.foregroundColor = Color.secondary

        displayTitle.append(count)
        return displayTitle
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
                    .focusable(false)
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
            let lineTop = SearchLayout.groupRailChevronTopPadding
                + SearchLayout.groupRailChevronSize
                + SearchLayout.groupRailLineTopSpacing
            let lineHeight = max(CGFloat.zero, geometry.size.height - lineTop)
            let lineX = SearchLayout.resultOuterHorizontalPadding
                + SearchLayout.groupDisclosureWidth / 2

            ZStack(alignment: .topLeading) {
                if showsLine && lineHeight > 0 {
                    Rectangle()
                        .fill(.tertiary)
                        .opacity(0.55)
                        .frame(width: SearchLayout.groupRailLineWidth, height: lineHeight)
                        .offset(
                            x: lineX - SearchLayout.groupRailLineWidth / 2,
                            y: lineTop
                        )
                }

                Button(action: onToggle) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: SearchLayout.groupRailChevronSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(
                            width: SearchLayout.groupDisclosureWidth,
                            height: SearchLayout.groupRailChevronSize,
                            alignment: .center
                        )
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .offset(
                    x: SearchLayout.resultOuterHorizontalPadding,
                    y: SearchLayout.groupRailChevronTopPadding
                )
            }
        }
        .frame(width: SearchLayout.resultSelectionLeadingPadding)
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
            .padding(.trailing, SearchLayout.resultTextHorizontalPadding)
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
}

private enum SearchLayout {
    static let contentWidth: CGFloat = 860
    static let minimumHorizontalMargin: CGFloat = 24
    static let libraryPanelMinimumWidth: Double = 310
    static let playbackAreaMinimumWidth: CGFloat = 520
    static let searchPanelMinimumWidth: Double = 420
    static let dividerHitWidth: CGFloat = 6
    static let dividerLineWidth: CGFloat = 1
    static let dividerActiveLineWidth: CGFloat = 3
    static let resultOuterHorizontalPadding: CGFloat = 12
    static let groupDisclosureWidth: CGFloat = 16
    static let groupRailChevronSize: CGFloat = 10
    static let groupRailChevronTopPadding: CGFloat = 9
    static let groupRailLineTopSpacing: CGFloat = 8
    static let groupRailLineWidth: CGFloat = 1.5
    static let resultContentLeadingOffset: CGFloat = 5
    static let resultSelectionLeadingPadding: CGFloat = resultOuterHorizontalPadding + groupDisclosureWidth + resultContentLeadingOffset
    static let resultTextHorizontalPadding: CGFloat = 14
    static let resultTextLeadingPadding: CGFloat = resultTextHorizontalPadding
}

private func displayTitleWithSoftWrapOpportunities(_ displayTitle: String) -> String {
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

private func formatDuration(_ seconds: Double?) -> String {
    guard let seconds, seconds.isFinite, seconds > 0 else {
        return "--:--"
    }

    let totalSeconds = Int(seconds.rounded())
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let remainingSeconds = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }

    return String(format: "%02d:%02d", minutes, remainingSeconds)
}
