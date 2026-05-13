import AppKit
import Foundation
import SwiftUI
import CueSeekerCore

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @State private var contentPanelDragStartWidth: Double?
    @State private var isContentPanelDividerHovered = false
    @State private var isContentPanelDividerDragging = false
    @State private var collapsedLibraryFolderPaths: Set<String> = []

    var body: some View {
        AppPerformanceProbe.measure("SearchView.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.Workbench.body")

            return GeometryReader { geometry in
                let modeRailWidth = SearchLayout.modeRailWidth
                let contentPanelWidth = contentPanelWidth(for: geometry.size.width)
                let isSidebarOnLeft = layoutState.sidebarPosition == .left

                HStack(spacing: 0) {
                    if isSidebarOnLeft {
                        modeRail
                            .frame(width: modeRailWidth, height: geometry.size.height)
                            .zIndex(2)

                        contentPanelSlot(
                            width: contentPanelWidth,
                            availableWidth: geometry.size.width,
                            isSidebarOnLeft: true
                        )
                        .zIndex(1)

                        playbackArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        playbackArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        contentPanelSlot(
                            width: contentPanelWidth,
                            availableWidth: geometry.size.width,
                            isSidebarOnLeft: false
                        )
                        .zIndex(1)

                        modeRail
                            .frame(width: modeRailWidth, height: geometry.size.height)
                            .zIndex(2)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(LayoutPerformanceProbe(name: "SearchView.root.layout"))
            }
            .onAppear {
                resetCollapsedLibraryFolders()
            }
            .onChange(of: appState.libraryPresentationRevision) { _ in
                resetCollapsedLibraryFolders()
            }
        }
    }

    private var modeRail: some View {
        AppPerformanceProbe.measure("SearchView.modeRail.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.WorkbenchModeRail.body")

            return VStack(spacing: 12) {
                modeRailButton(
                    mode: .library,
                    systemImage: "folder",
                    selectedSystemImage: "folder.fill",
                    help: "Library"
                )

                modeRailButton(
                    mode: .shiori,
                    systemImage: "bookmark",
                    selectedSystemImage: "bookmark.fill",
                    help: "Shiori"
                )

                Spacer()

                settingsRailButton
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: layoutState.sidebarPosition == .left ? .trailing : .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 1)
            }
            .background(LayoutPerformanceProbe(name: "SearchView.modeRail.layout"))
        }
    }

    private func modeRailButton(
        mode: WorkbenchPanelMode,
        systemImage: String,
        selectedSystemImage: String,
        help: String
    ) -> some View {
        let isSelected = layoutState.panelMode == mode
        let markerAlignment: Alignment = layoutState.sidebarPosition == .left ? .leading : .trailing

        return Button {
            appState.performUserInitiatedAppCommand {
                appState.activateWorkbenchPanelMode(mode)
            }
        } label: {
            ZStack(alignment: markerAlignment) {
                if isSelected {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 30)
                        .offset(
                            x: layoutState.sidebarPosition == .left
                                ? -SearchLayout.modeRailButtonHorizontalPadding
                                : SearchLayout.modeRailButtonHorizontalPadding
                        )
                }

                Image(systemName: isSelected ? selectedSystemImage : systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .frame(
                        width: SearchLayout.modeRailButtonSize,
                        height: SearchLayout.modeRailButtonSize
                    )
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(ModeRailButtonStyle(isSelected: isSelected))
        .allowsHitTesting(!layoutState.isVideoSizeTransitionInProgress)
        .focusable(false)
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .help(help)
        .accessibilityLabel(help)
        .frame(
            width: SearchLayout.modeRailButtonSize,
            height: SearchLayout.modeRailButtonSize
        )
    }

    private var settingsRailButton: some View {
        Button {
            appState.performUserInitiatedAppCommand {
                NotificationCenter.default.post(
                    name: .cueSeekerShowSettings,
                    object: nil
                )
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .medium))
                .frame(
                    width: SearchLayout.modeRailButtonSize,
                    height: SearchLayout.modeRailButtonSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(ModeRailButtonStyle(isSelected: false))
        .allowsHitTesting(!layoutState.isVideoSizeTransitionInProgress)
        .focusable(false)
        .foregroundStyle(Color.secondary)
        .help("Settings")
        .accessibilityLabel("Settings")
        .frame(
            width: SearchLayout.modeRailButtonSize,
            height: SearchLayout.modeRailButtonSize
        )
    }

    private func contentPanelSlot(
        width: CGFloat,
        availableWidth: CGFloat,
        isSidebarOnLeft: Bool
    ) -> some View {
        let visibleWidth = layoutState.isContentPanelVisible ? width : 0
        let panelAlignment: Alignment = isSidebarOnLeft ? .leading : .trailing
        let dividerAlignment: Alignment = isSidebarOnLeft ? .trailing : .leading

        return contentPanel
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .overlay(alignment: dividerAlignment) {
                contentPanelResizeDivider(
                    availableWidth: availableWidth,
                    isSidebarOnLeft: isSidebarOnLeft
                )
            }
            .allowsHitTesting(layoutState.isContentPanelVisible)
            .accessibilityHidden(!layoutState.isContentPanelVisible)
            .frame(width: visibleWidth, alignment: panelAlignment)
            .frame(maxHeight: .infinity)
            .clipped()
    }

    @ViewBuilder
    private var contentPanel: some View {
        AppPerformanceProbe.measure("SearchView.contentPanel.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.WorkbenchContentPanel.body",
                details: "mode=\(layoutState.panelMode.rawValue)"
            )

            return Group {
                switch layoutState.panelMode {
                case .library:
                    libraryPanel
                case .search:
                    searchPanel
                case .shiori:
                    shioriPanel
                }
            }
        }
    }

    private var libraryPanel: some View {
        AppPerformanceProbe.measure("SearchView.libraryPanel.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.LibraryPanel.body")

            return VStack(alignment: .leading, spacing: 6) {
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
            .background(LayoutPerformanceProbe(name: "SearchView.libraryPanel.layout"))
        }
    }

    private var libraryHeader: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.leading, 12)
        .padding(.trailing, 28) // 12 + 16px to account for the ScrollView scrollbar width
        .frame(height: 36)
    }

    private var libraryList: some View {
        let rowCount = appState.libraryFolderGroups.reduce(0) { $0 + $1.videos.count }
        UIInvalidationProbe.count(
            "UI.LibraryRows.rendered",
            details: "groups=\(appState.libraryFolderGroups.count) rows=\(rowCount)"
        )

        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.libraryFolderGroups) { group in
                            let isCollapsed = collapsedLibraryFolderPaths.contains(group.folderPath)
                            LibraryFolderGroupView(
                                group: group,
                                isCollapsed: isCollapsed,
                                selectedLibraryVideoPath: appState.selectedLibraryVideo?.videoPath,
                                onToggle: {
                                    appState.clearSearchFocus()
                                    toggleLibraryFolderGroup(group.folderPath, proxy: proxy)
                                },
                                onOpenVideo: { video in
                                    appState.clearSearchFocus()
                                    appState.openLibraryVideo(video)
                                }
                            )
                        }
                    }
                    .frame(width: max(0, geo.size.width - 16), alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func resetCollapsedLibraryFolders() {
        collapsedLibraryFolderPaths = Set(appState.libraryFolderGroups.map(\.id))
    }

    private func toggleLibraryFolderGroup(_ folderPath: String, proxy: ScrollViewProxy) {
        let wasCollapsed = collapsedLibraryFolderPaths.contains(folderPath)
        UIInvalidationProbe.mark(
            "ACTION UI.LibraryFolder.toggled",
            details: "collapsedBefore=\(wasCollapsed)"
        )
        if wasCollapsed {
            collapsedLibraryFolderPaths.remove(folderPath)
            if let selectedVideoPath = appState.selectedLibraryVideo?.videoPath,
               let group = appState.libraryFolderGroups.first(where: { $0.folderPath == folderPath }),
               group.videos.contains(where: { $0.video.videoPath == selectedVideoPath }) {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(selectedVideoPath, anchor: .center)
                    }
                }
            }
        } else {
            collapsedLibraryFolderPaths.insert(folderPath)
        }
    }

    private var shioriPanel: some View {
        AppPerformanceProbe.measure("SearchView.shioriPanel.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.ShioriPanel.body")

            return GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 6) {
                    shioriHeader

                    if appState.shioris.isEmpty {
                        EmptyStateView(
                            title: "No Shiori",
                            systemImage: "bookmark",
                            message: "Save subtitles from playback to collect Shiori."
                        )
                        .font(.system(size: SearchTypography.bodySize))
                    } else {
                        shioriList
                    }

                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, AppShellLayout.contentTopPadding)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .contentShape(Rectangle())
            }
            .background(Color(nsColor: .textBackgroundColor))
            .background(LayoutPerformanceProbe(name: "SearchView.shioriPanel.layout"))
        }
    }

    private var searchPanel: some View {
        AppPerformanceProbe.measure("SearchView.searchPanel.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.SearchPanel.body")

            return GeometryReader { geometry in
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
            .background(LayoutPerformanceProbe(name: "SearchView.searchPanel.layout"))
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

                    Spacer()

                    if appState.hasSearchResultGroups {
                        Button {
                            appState.clearSearchFocus()
                            appState.collapseAllSearchResultGroups()
                        } label: {
                            Text("Collapse All")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 28)
            }
        }
    }

    private var shioriHeader: some View {
        HStack(spacing: 12) {
            Text(shioriSummaryText)
                .font(.system(size: SearchTypography.detailSize))
                .foregroundStyle(.secondary)

            Spacer()

            if appState.hasShioriFileGroups {
                Button {
                    appState.clearSearchFocus()
                    appState.collapseAllShioriGroups()
                } label: {
                    Text("Collapse All")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 28)
        .frame(height: 36)
    }

    private var shioriSummaryText: String {
        "\(appState.shioriCount) shioris in \(appState.shioriFileCount) files"
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
            let fileText = appState.searchResultFileCount == 1 ? "file" : "files"
            return "Found \(appState.searchResultTotalCount) results in \(appState.searchResultFileCount) \(fileText)"
        }
    }

    private var shioriList: some View {
        UIInvalidationProbe.count(
            "UI.ShioriRows.rendered",
            details: "groups=\(appState.shioriFileGroups.count) rows=\(appState.shioriCount)"
        )

        return GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.shioriFileGroups) { group in
                        ShioriGroupView(
                            group: group,
                            selectedShiori: appState.selectedShiori,
                            onToggle: {
                                appState.clearSearchFocus()
                                appState.toggleShioriGroup(group.subtitlePath)
                            },
                            onOpenShiori: { shiori in
                                appState.clearSearchFocus()
                                appState.openShiori(shiori)
                            }
                        )
                    }
                }
                .frame(width: max(0, geo.size.width - 16), alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private var resultsList: some View {
        UIInvalidationProbe.count(
            "UI.SearchRows.rendered",
            details: "groups=\(appState.searchResultGroups.count) rows=\(appState.renderedSearchResultCount)"
        )

        return GeometryReader { geo in
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
                                appState.markSearchResultVisible(result)
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
                .frame(width: max(0, geo.size.width - 16), alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
    }

    private var playbackArea: some View {
        AppPerformanceProbe.measure("SearchView.playbackArea.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.PlaybackArea.body")

            return Group {
                switch appState.topbarSearchContentMode {
                case .workbench:
                    legacyPlaybackArea
                case .results:
                    topbarSearchResultsArea
                case .playback:
                    topbarSearchPlaybackArea
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .background(LayoutPerformanceProbe(name: "SearchView.playbackArea.layout"))
            .simultaneousGesture(
                TapGesture().onEnded {
                    appState.clearSearchFocus()
                }
            )
        }
    }

    private var legacyPlaybackArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.hasPlaybackSelection {
                VStack(alignment: .leading, spacing: 16) {
                    playbackSurface
                        .aspectRatio(
                            CGFloat(appState.playbackViewModel?.videoAspectRatio ?? 16 / 9),
                            contentMode: .fit
                        )
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

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, AppShellLayout.contentTopPadding)
                .padding([.horizontal, .bottom], 20)
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
    }

    private var playbackSurface: some View {
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
            onSaveShiori: {
                appState.clearSearchFocus()
                appState.toggleCurrentShiori()
            },
            isFullscreenToggleDisabled: layoutState.isVideoSizeTransitionInProgress,
            onToggleFullscreen: {
                appState.clearSearchFocus()
                appState.togglePlaybackFullscreenFromUser(
                    onCopySubtitle: {
                        appState.copyCurrentSubtitleToClipboard()
                    },
                    onSaveShiori: {
                        appState.toggleCurrentShiori()
                    }
                )
            }
        )
    }

    private var topbarSearchResultsArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(searchResultSummaryText ?? "Search")
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(.secondary)

                Spacer()

                if appState.hasSearchResultGroups {
                    Button {
                        appState.clearSearchFocus()
                        appState.collapseAllSearchResultGroups()
                    } label: {
                        Text("Collapse All")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, AppShellLayout.contentTopPadding)

            if appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyStateView(
                    title: "No Search Query",
                    systemImage: "text.magnifyingglass",
                    message: "Type a query in the topbar Search field and press Return."
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .searching = appState.searchStatus, appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "Searching",
                    systemImage: "magnifyingglass",
                    message: "Looking through indexed subtitle text."
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.searchResults.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "tray",
                    message: "No indexed subtitle entries matched this query."
                )
                .font(.system(size: SearchTypography.bodySize))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                resultsList
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var topbarSearchPlaybackArea: some View {
        SearchPlaybackPage(
            playbackSurface: AnyView(playbackSurface),
            appState: appState
        )
    }

    private func contentPanelResizeDivider(
        availableWidth: CGFloat,
        isSidebarOnLeft: Bool
    ) -> some View {
        let isActive = isContentPanelDividerHovered || isContentPanelDividerDragging
        let lineAlignment: Alignment = isSidebarOnLeft ? .trailing : .leading

        return ZStack(alignment: lineAlignment) {
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
                        isContentPanelDividerHovered = isHovered
                    },
                    onDragStarted: {
                        appState.clearSearchFocus()
                        isContentPanelDividerDragging = true
                        contentPanelDragStartWidth = layoutState.contentPanelWidth
                    },
                    onDragChanged: { translationX in
                        let startWidth = contentPanelDragStartWidth ?? layoutState.contentPanelWidth
                        let delta = isSidebarOnLeft ? translationX : -translationX
                        let proposedWidth = startWidth + Double(delta)
                        appState.updateWorkbenchContentPanelWidth(
                            clampedContentPanelWidth(proposedWidth, availableWidth: availableWidth)
                        )
                    },
                    onDragEnded: {
                        contentPanelDragStartWidth = nil
                        isContentPanelDividerDragging = false
                    }
                )
            )
    }

    private func contentPanelWidth(for availableWidth: CGFloat) -> CGFloat {
        CGFloat(
            clampedContentPanelWidth(
                layoutState.contentPanelWidth,
                availableWidth: availableWidth
            )
        )
    }

    private func clampedContentPanelWidth(_ width: Double, availableWidth: CGFloat) -> Double {
        let availableContentPanelWidth = Double(
            availableWidth
                - SearchLayout.modeRailWidth
                - SearchLayout.playbackAreaMinimumWidth
        )
        let maxWidth = max(
            SearchLayout.contentPanelMinimumWidth,
            availableContentPanelWidth
        )

        return min(
            max(width, SearchLayout.contentPanelMinimumWidth),
            maxWidth
        )
    }
}

private enum SearchPlaybackDrawer {
    case results
    case subtitles
}

private struct SearchPlaybackPage: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppState
    @State private var activeDrawer: SearchPlaybackDrawer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottom) {
                playbackSurface
                    .aspectRatio(
                        CGFloat(appState.playbackViewModel?.videoAspectRatio ?? 16 / 9),
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let activeDrawer {
                    drawerView(activeDrawer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if case .failed(let message) = appState.playbackStatus {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(.red)
            }

            commandRow
        }
        .padding(.top, AppShellLayout.contentTopPadding)
        .padding([.horizontal, .bottom], 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var commandRow: some View {
        HStack(spacing: 10) {
            Button {
                appState.clearSearchFocus()
                appState.revealCurrentVideoFile()
            } label: {
                Label("Video Folder", systemImage: "folder")
            }

            Button {
                appState.clearSearchFocus()
                appState.revealCurrentSubtitleFile()
            } label: {
                Label("Subtitle Folder", systemImage: "folder")
            }
            .disabled(appState.currentPlaybackSubtitlePath == nil)

            Divider()
                .frame(height: 20)

            Button {
                appState.clearSearchFocus()
                appState.openAdjacentSearchResult(.previous)
            } label: {
                Label("Previous Result", systemImage: "chevron.left")
            }

            Button {
                appState.clearSearchFocus()
                appState.openAdjacentSearchResult(.next)
            } label: {
                Label("Next Result", systemImage: "chevron.right")
            }

            Spacer(minLength: 0)

            drawerButton(title: "Results", drawer: .results)
            drawerButton(title: "Subtitles", drawer: .subtitles)
                .disabled(appState.currentPlaybackSubtitlePath == nil)
        }
    }

    private func drawerButton(title: String, drawer: SearchPlaybackDrawer) -> some View {
        let isOpen = activeDrawer == drawer
        return Button {
            appState.clearSearchFocus()
            toggleDrawer(drawer)
        } label: {
            HStack(spacing: 6) {
                Text(title)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(isOpen ? -90 : 0))
                    .animation(.easeInOut(duration: 0.16), value: isOpen)
            }
        }
    }

    @ViewBuilder
    private func drawerView(_ drawer: SearchPlaybackDrawer) -> some View {
        switch drawer {
        case .results:
            resultsDrawer
        case .subtitles:
            subtitlesDrawer
        }
    }

    private var resultsDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(searchNavigationTitle)
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if appState.searchResultGroups.isEmpty, appState.searchNavigationSnapshot == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.searchResultGroups) { group in
                                SearchResultGroupView(
                                    group: group,
                                    query: appState.searchQuery,
                                    selectedResult: selectedSearchNavigationResult,
                                    onToggle: {
                                        appState.clearSearchFocus()
                                        appState.toggleSearchResultGroup(group.subtitlePath)
                                    },
                                    onOpenResult: { result in
                                        appState.clearSearchFocus()
                                        appState.openSearchResult(result)
                                    },
                                    onResultAppear: { result in
                                        appState.markSearchResultVisible(result)
                                        appState.loadMoreSearchResultsIfNeeded(currentResult: result)
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .onAppear {
                        scrollToSelectedResult(using: proxy)
                    }
                    .onChange(of: selectedSearchNavigationEntryID) { _ in
                        scrollToSelectedResult(using: proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var subtitlesDrawer: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.currentSubtitleEntries, id: \.id) { entry in
                        SubtitleEntryRow(
                            entry: entry,
                            isSelected: entry.id == selectedSubtitleEntryID
                        )
                        .id(entry.id)
                        .listRowAction {
                            appState.clearSearchFocus()
                            appState.playbackViewModel?.seek(
                                to: Double(entry.startMilliseconds) / 1_000
                            )
                        }
                        .focusable(false)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onAppear {
                scrollToSelectedSubtitle(using: proxy)
            }
            .onChange(of: selectedSubtitleEntryID) { _ in
                scrollToSelectedSubtitle(using: proxy)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var searchNavigationTitle: String {
        guard let snapshot = appState.searchNavigationSnapshot else {
            return "Loading nearby results"
        }

        if let position = snapshot.currentPosition {
            return "Result \(position) of \(snapshot.totalCount)"
        }

        return "\(snapshot.totalCount) results"
    }

    private var selectedSearchNavigationResult: SubtitleSearchResult? {
        appState.searchNavigationSnapshot?.current ?? appState.selectedSearchResult
    }

    private var selectedSearchNavigationEntryID: Int64? {
        selectedSearchNavigationResult?.entryID
    }

    private var selectedSubtitleEntryID: Int64? {
        let milliseconds = max(
            0,
            Int(((appState.playbackViewModel?.displayedCurrentTime ?? 0) * 1_000).rounded(.down))
        )
        if let active = appState.currentSubtitleEntries.first(where: {
            $0.startMilliseconds <= milliseconds && milliseconds < $0.endMilliseconds
        }) {
            return active.id
        }

        return appState.currentSubtitleEntries.last(where: {
            $0.startMilliseconds <= milliseconds
        })?.id
    }

    private func scrollToSelectedResult(using proxy: ScrollViewProxy) {
        guard let selectedSearchNavigationEntryID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            proxy.scrollTo(selectedSearchNavigationEntryID, anchor: .center)
        }
    }

    private func scrollToSelectedSubtitle(using proxy: ScrollViewProxy) {
        guard let selectedSubtitleEntryID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            proxy.scrollTo(selectedSubtitleEntryID, anchor: .center)
        }
    }

    private func toggleDrawer(_ drawer: SearchPlaybackDrawer) {
        if activeDrawer == drawer {
            withAnimation(.easeInOut(duration: 0.16)) {
                activeDrawer = nil
            }
            return
        }

        switch drawer {
        case .results:
            appState.refreshSearchNavigationSnapshot()
        case .subtitles:
            appState.refreshCurrentSubtitleEntries()
        }

        appState.pausePlayback()
        withAnimation(.easeInOut(duration: 0.16)) {
            activeDrawer = drawer
        }
    }
}

private struct SubtitleEntryRow: View {
    let entry: SubtitleDatabaseEntry
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: SearchTypography.bodySize))
                    .foregroundStyle(rowTextColor)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
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

    private var displayLines: [String] {
        let lines = entry.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [entry.content] : lines
    }

    private var rowTextColor: Color {
        isSelected ? .white : Color.primary.opacity(0.86)
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }
}

private struct ModeRailButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(configuration: configuration))
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if configuration.isPressed {
            return Color.primary.opacity(0.12)
        }
        if isSelected {
            return Color.primary.opacity(0.10)
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return .clear
    }
}

private struct SearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
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
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isFocused ? Color.accentColor : Color.primary.opacity(0.08),
                    lineWidth: isFocused ? 2 : 1
                )
        )
    }
}

private extension View {
    func listRowAction(_ action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("Activate"), action)
    }
}

private struct LibraryFolderGroupView: View {
    let group: LibraryFolderGroup
    let isCollapsed: Bool
    let selectedLibraryVideoPath: String?
    let onToggle: () -> Void
    let onOpenVideo: (LibraryVideo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LibraryFolderHeader(
                folderTitle: group.folderTitle,
                episodeCount: group.videos.count,
                playingRank: playingRank,
                isCollapsed: isCollapsed,
                onToggle: onToggle
            )

            if !isCollapsed {
                LibraryEpisodeGrid(
                    rows: group.videos,
                    selectedLibraryVideoPath: selectedLibraryVideoPath,
                    onOpenVideo: onOpenVideo
                )
            }
        }
    }

    private var playingRank: Int? {
        guard let path = selectedLibraryVideoPath,
              let index = group.videos.firstIndex(where: { $0.video.videoPath == path })
        else {
            return nil
        }
        return index + 1
    }
}

private struct LibraryFolderHeader: View {
    let folderTitle: String
    let episodeCount: Int
    let playingRank: Int?
    let isCollapsed: Bool
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14, alignment: .center)
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                .animation(.easeInOut(duration: 0.16), value: isCollapsed)

            VStack(alignment: .leading, spacing: 2) {
                Text(folderTitle)
                    .font(.system(size: SearchTypography.bodySize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitleText)
                    .font(.system(size: SearchTypography.detailSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LibraryLayout.folderRowInnerHorizontalPadding)
        .padding(.vertical, LibraryLayout.folderRowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .padding(.leading, LibraryLayout.folderRowOuterLeadingPadding)
        .padding(.trailing, LibraryLayout.folderRowOuterTrailingPadding)
        .onHover { isHovered = $0 }
        .listRowAction(onToggle)
        .focusable(false)
    }

    private var subtitleText: String {
        let label = episodeCount == 1 ? "episode" : "episodes"
        if let rank = playingRank {
            return "\(episodeCount) \(label) · Playing \(rank)"
        }
        return "\(episodeCount) \(label)"
    }
}

private struct LibraryEpisodeGrid: View {
    let rows: [LibraryVideoRow]
    let selectedLibraryVideoPath: String?
    let onOpenVideo: (LibraryVideo) -> Void

    private let columns: [GridItem] = [
        GridItem(
            .adaptive(minimum: LibraryLayout.episodeButtonMinimumWidth),
            spacing: LibraryLayout.episodeGridHorizontalSpacing,
            alignment: .top
        )
    ]

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .center,
            spacing: LibraryLayout.episodeGridVerticalSpacing
        ) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LibraryEpisodeButton(
                    rank: index + 1,
                    isSelected: row.video.videoPath == selectedLibraryVideoPath,
                    action: { onOpenVideo(row.video) }
                )
                .id(row.video.videoPath)
            }
        }
        .padding(.leading, LibraryLayout.episodeGridLeadingPadding)
        .padding(.trailing, LibraryLayout.episodeGridTrailingPadding)
        .padding(.top, LibraryLayout.episodeGridTopPadding)
        .padding(.bottom, LibraryLayout.episodeGridBottomPadding)
    }
}

private struct LibraryEpisodeButton: View {
    let rank: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text("\(rank)")
            .font(.system(size: SearchTypography.bodySize, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .frame(width: LibraryLayout.episodeButtonMinimumWidth, height: LibraryLayout.episodeButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .listRowAction(action)
            .focusable(false)
            .accessibilityLabel("Episode \(rank)")
    }

    private var textColor: Color {
        isSelected ? .white : .primary
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovered {
            return Color.primary.opacity(0.08)
        }
        return Color.primary.opacity(0.04)
    }
}

private enum LibraryLayout {
    static let folderRowInnerHorizontalPadding: CGFloat = 12
    static let folderRowVerticalPadding: CGFloat = 8
    static let folderRowOuterLeadingPadding: CGFloat = 12
    static let folderRowOuterTrailingPadding: CGFloat = 12
    static let episodeButtonMinimumWidth: CGFloat = 44
    static let episodeButtonHeight: CGFloat = 36
    static let episodeGridHorizontalSpacing: CGFloat = 8
    static let episodeGridVerticalSpacing: CGFloat = 8
    static let episodeGridLeadingPadding: CGFloat = 32
    static let episodeGridTrailingPadding: CGFloat = 32
    static let episodeGridTopPadding: CGFloat = 6
    static let episodeGridBottomPadding: CGFloat = 10
}

private struct SearchResultGroupHeader: View {
    let group: SearchResultFileGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Text(headerText)
            .font(.system(size: SearchTypography.groupHeaderSize))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 7)
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowAction(onToggle)
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

                    SearchResultRow(
                        result: result,
                        query: query,
                        isSelected: isSelected
                    )
                    .listRowAction {
                        onOpenResult(result)
                    }
                    .id(result.entryID)
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

private struct ShioriGroupHeader: View {
    let group: ShioriFileGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Text(headerText)
            .font(.system(size: SearchTypography.groupHeaderSize))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 7)
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowAction(onToggle)
        .focusable(false)
    }

    private var headerText: AttributedString {
        var displayTitle = AttributedString(displayTitleWithSoftWrapOpportunities(group.subtitleDisplayTitle))
        displayTitle.foregroundColor = isSelected ? .primary : Color.primary.opacity(0.76)

        var count = AttributedString("  \(shioriCountText)")
        count.foregroundColor = Color.secondary

        displayTitle.append(count)
        return displayTitle
    }

    private var shioriCountText: String {
        "\(group.totalCount) \(group.totalCount == 1 ? "shiori" : "shioris")"
    }
}

private struct ShioriGroupView: View {
    let group: ShioriFileGroup
    let selectedShiori: Shiori?
    let onToggle: () -> Void
    let onOpenShiori: (Shiori) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShioriGroupHeader(
                group: group,
                isSelected: selectedShiori?.subtitlePath == group.subtitlePath,
                onToggle: onToggle
            )

            if !group.isCollapsed {
                ForEach(group.shioris) { shiori in
                    ShioriRowView(
                        shiori: shiori,
                        isSelected: selectedShiori?.id == shiori.id
                    )
                    .listRowAction {
                        onOpenShiori(shiori)
                    }
                    .focusable(false)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            SearchResultGroupRail(
                isCollapsed: group.isCollapsed,
                showsLine: !group.isCollapsed && !group.shioris.isEmpty,
                onToggle: onToggle
            )
        }
    }
}

private struct ShioriRowView: View {
    let shiori: Shiori
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        let rowTextColor: Color = isSelected ? .white : Color.primary.opacity(0.86)
        let rowBackgroundColor: Color = if isSelected {
            Color.accentColor
        } else if isHovered {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: SearchTypography.bodySize))
                        .foregroundStyle(rowTextColor)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        shiori.cueLines.isEmpty ? [shiori.content] : shiori.cueLines
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

                Image(systemName: "chevron.right")
                    .font(.system(size: SearchLayout.groupRailChevronSize, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: SearchLayout.groupDisclosureWidth,
                        height: SearchLayout.groupRailChevronSize,
                        alignment: .center
                    )
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.16), value: isCollapsed)
                    .listRowAction(onToggle)
                    .accessibilityLabel(isCollapsed ? "Expand group" : "Collapse group")
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
    @State private var thumbnailImage: NSImage?
    @State private var isThumbnailFailed = false

    var body: some View {
        let rowTextColor: Color = isSelected ? .white : Color.primary.opacity(0.86)
        let rowBackgroundColor: Color = if isSelected {
            Color.accentColor
        } else if isHovered {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }
        let highlightState: SearchHighlightState = isSelected
            ? .selected
            : (isHovered ? .hover : .default)

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                thumbnailView

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                        Text(highlightedContent(
                            line,
                            query: query,
                            textColor: rowTextColor,
                            state: highlightState
                        ))
                        .font(.system(size: SearchTypography.bodySize))
                        .foregroundStyle(rowTextColor)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, SearchLayout.resultTextLeadingPadding)
            .padding(.trailing, SearchLayout.resultTextHorizontalPadding)
            .background(rowBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.leading, SearchLayout.resultSelectionLeadingPadding)
            .padding(.trailing, SearchLayout.resultOuterHorizontalPadding)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .task(id: result.entryID) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: result.videoPath)
            let fileSize = attrs?[.size] as? Int64
            let modifiedAt = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970
            let request = ThumbnailRequest(
                videoPath: result.videoPath,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                timestampMilliseconds: (result.startMilliseconds + result.endMilliseconds) / 2,
                priority: result.searchRank
            )
            let cacheKey = await ThumbnailCache.shared.cacheKey(for: request)
            if let imageData = await ThumbnailGenerator.shared.generate(request: request, cacheKey: cacheKey) {
                if !Task.isCancelled {
                    self.thumbnailImage = NSImage(data: imageData)
                }
            } else if !Task.isCancelled {
                self.isThumbnailFailed = true
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isThumbnailFailed {
                VStack {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.1))
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
            }
        }
        .frame(width: 160, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 6)
    }

    private var displayLines: [String] {
        let lines = result.cueLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [result.content] : lines
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
    static let modeRailWidth: CGFloat = 56
    static let modeRailButtonSize: CGFloat = 40
    static let modeRailButtonHorizontalPadding: CGFloat = (modeRailWidth - modeRailButtonSize) / 2
    static let contentPanelMinimumWidth: Double = 420
    static let playbackAreaMinimumWidth: CGFloat = 520
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
    static let resultTextHorizontalPadding: CGFloat = 10
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

private func highlightedContent(
    _ content: String,
    query: String,
    textColor: Color,
    state: SearchHighlightState
) -> AttributedString {
    var highlighted = AttributedString(content)
    let terms = highlightTerms(from: query)

    let bg: Color
    switch state {
    case .default:
        bg = SearchHighlightTokens.default
    case .hover:
        bg = SearchHighlightTokens.hover
    case .selected:
        bg = SearchHighlightTokens.onSelected
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
