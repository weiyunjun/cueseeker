import CoreGraphics
import CueSeekerCore
import SwiftUI

struct RecentWatchingGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    @Environment(\.libraryCardContextMenuOpen) private var pageContextMenuOpen
    let items: [RecentLibraryWatchingPresentation]
    @ObservedObject var highlight: CardHighlightModel
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (RecentLibraryWatchingPresentation) -> Void

    var body: some View {
        if let pageContextMenuOpen {
            sectionedGrid(openContextMenu: pageContextMenuOpen)
        } else {
            LibraryCardContextMenuHost { sectionedGrid(openContextMenu: $0) }
        }
    }

    private func sectionedGrid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        let sections = RecentTimeSection.group(
            items,
            timestamp: \.updatedAt
        )
        return VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing3
        ) {
            ForEach(sections, id: \.section) { entry in
                VStack(
                    alignment: .leading,
                    spacing: WorkbenchControlMetrics.redesignSpacing3
                ) {
                    RecentSectionTitleView(title: entry.section.localizedTitle)

                    LibraryOverviewGrid(items: entry.items) { item in
                        LibraryVideoCard(
                            content: LibraryVideoCardContent(item),
                            highlight: highlight,
                            isSelected: highlight.isSelected(item.id),
                            isHovered: highlight.isHovered(item.id),
                            actions: .appState(appState),
                            openContextMenu: openContextMenu,
                            onOpen: { onOpen(item) }
                        )
                        .background {
                            if let itemFrameCoordinateSpace {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: LibraryItemFramePreferenceKey.self,
                                        value: [
                                            item.id: proxy.frame(
                                                in: .named(itemFrameCoordinateSpace)
                                            )
                                        ]
                                    )
                                }
                            }
                        }
                        .id(item.id)
                    }
                }
            }
        }
        .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
            guard itemFrameCoordinateSpace != nil else {
                return
            }
            onItemFramesChange(frames)
        }
    }
}

private struct LibraryVideoCardGrid<Item: Identifiable>: View
where Item.ID == String {
    @EnvironmentObject private var appState: AppCoordinator
    /// Set when the page already hosts the menu at its own root. The grid then
    /// uses that host, so the menu covers the whole page instead of only the
    /// grid it was opened from.
    @Environment(\.libraryCardContextMenuOpen) private var pageContextMenuOpen
    let items: [Item]
    @ObservedObject var highlight: CardHighlightModel
    let itemFrameCoordinateSpace: String?
    let onItemFramesChange: ([String: CGRect]) -> Void
    let content: (Item) -> LibraryVideoCardContent
    let onOpen: (Item) -> Void

    var body: some View {
        if let pageContextMenuOpen {
            grid(openContextMenu: pageContextMenuOpen)
        } else {
            LibraryCardContextMenuHost { grid(openContextMenu: $0) }
        }
    }

    private func grid(
        openContextMenu: @escaping ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    ) -> some View {
        LibraryOverviewGrid(items: items) { item in
            LibraryVideoCard(
                content: content(item),
                highlight: highlight,
                isSelected: highlight.isSelected(item.id),
                isHovered: highlight.isHovered(item.id),
                actions: .appState(appState),
                openContextMenu: openContextMenu,
                onOpen: { onOpen(item) }
            )
            .background {
                if let itemFrameCoordinateSpace {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: LibraryItemFramePreferenceKey.self,
                            value: [
                                item.id: proxy.frame(
                                    in: .named(itemFrameCoordinateSpace)
                                )
                            ]
                        )
                    }
                }
            }
            .id(item.id)
        }
        .onPreferenceChange(LibraryItemFramePreferenceKey.self) { frames in
            guard itemFrameCoordinateSpace != nil else {
                return
            }
            onItemFramesChange(frames)
        }
    }
}

/// Shared by the video card grid and the Excerpt card grid: both report where
/// their cards sit so the Command Panel can walk them with the arrow keys.
struct LibraryItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(
        value: inout [String: CGRect],
        nextValue: () -> [String: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

@MainActor
struct LibraryCardActionHandlers {
    let revealFile: (String) -> Void
    let openFolder: (String) -> Void
    let changeCover: (LibraryUserCoverTarget, String?, String?) -> Void
    let markVideo: (LibraryVideo, LibraryWatchState) -> Void
    let markFolder: (String, LibraryWatchState) -> Void

    static func appState(_ appState: AppCoordinator) -> LibraryCardActionHandlers {
        LibraryCardActionHandlers(
            revealFile: { appState.revealFile(atPath: $0) },
            openFolder: { appState.openFolder(atPath: $0) },
            changeCover: { target, coverPath, coverRevision in
                appState.beginChangingLibraryCover(
                    target: target,
                    currentCoverPath: coverPath,
                    currentCoverRevision: coverRevision
                )
            },
            markVideo: { appState.markLibraryVideo($0, as: $1) },
            markFolder: { appState.markCompleteLibraryFolder(folderPath: $0, as: $1) }
        )
    }
}

private struct LibraryVideoCardContent {
    let videoPath: String
    let folderTitle: String
    let episodeNumber: Int
    let positionMilliseconds: Int
    let duration: Double?
    let coverPath: String?
    let coverRevision: String?
    let watchStatus: LibraryWatchStatus
    let libraryVideo: LibraryVideo

    init(_ item: RecentLibraryWatchingPresentation) {
        videoPath = item.videoPath
        folderTitle = item.folderTitle
        episodeNumber = item.episodeNumber
        positionMilliseconds = item.positionMilliseconds
        duration = item.playbackDuration ?? item.duration
        coverPath = item.coverPath
        coverRevision = item.coverRevision
        watchStatus = LibraryWatchStatus(item.watchState)
        libraryVideo = item.libraryVideo
    }

    init(
        folderTitle: String,
        video: CompleteLibraryVideoPresentation
    ) {
        videoPath = video.videoPath
        self.folderTitle = folderTitle
        episodeNumber = video.episodeNumber
        positionMilliseconds = video.positionMilliseconds
        duration = video.playbackDuration ?? video.duration
        coverPath = video.coverPath
        coverRevision = video.coverRevision
        watchStatus = LibraryWatchStatus(video.watchState)
        libraryVideo = video.libraryVideo
    }
}

private struct LibraryVideoCard: View {
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.libraryCardContextMenuToggleAnchor) private var toggleAnchorMenu
    @Environment(\.libraryCardContextMenuAnchorOwner) private var anchorMenuOwnerID
    let content: LibraryVideoCardContent
    @ObservedObject var highlight: CardHighlightModel
    let isSelected: Bool
    let isHovered: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    let onOpen: () -> Void

    @State private var moreMenuAnchor = MenuAnchorHandle()

    private var cardID: String {
        content.videoPath
    }

    private var isMoreMenuOpen: Bool {
        anchorMenuOwnerID == cardID
    }

    private var isMoreButtonVisible: Bool {
        highlight.isPointerHovered(cardID) || isMoreMenuOpen
    }

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            let isWorkbench = layerContext.layer == .workbenchPage && !highlight.keepsCurrentWhenPointerLeaves
            let isPlaybackOverlay = layerContext.layer == .playbackOverlay
            let isCommandPanel = layerContext.layer == .commandPanel
            let _ = isWorkbench ? highlight.syncSelectedDuringRender(accessibility?.focusedCardID) : ()
            let _ = (isWorkbench || isPlaybackOverlay || isCommandPanel)
                ? syncAccessibilityAction(accessibility, layer: layerContext.layer)
                : ()
            let isCardFocused = (isWorkbench && accessibility?.isFocused(.mediaCard(cardID)) == true)
                || (isPlaybackOverlay && accessibility?.isPlaybackFocused(.overlayVideoCard(cardID)) == true)
                || (isCommandPanel && accessibility?.isPlaybackFocused(.commandPanelRecentCard(cardID)) == true)
            let isActionFocused = (isWorkbench && accessibility?.isFocused(.mediaCardActionButton(cardID)) == true)
                || (isPlaybackOverlay && accessibility?.isPlaybackFocused(.overlayVideoCardActionButton(cardID)) == true)
                || (isCommandPanel && accessibility?.isPlaybackFocused(.commandPanelRecentCardActionButton(cardID)) == true)

            LibraryOverviewCardSurface(
                isSelected: highlight.isSelected(cardID),
                isHovered: highlight.isHovered(cardID),
                isFocused: isCardFocused,
                animatesHover: highlight.animatesHoverBackground,
                action: {
                    highlight.notePress(id: cardID)
                    onOpen()
                }
            ) {
                VStack(alignment: .leading, spacing: WorkbenchLibraryMetrics.recentCardGap) {
                    cover(isActionFocused: isActionFocused)

                    Text(content.folderTitle)
                        .font(.system(size: WorkbenchLibraryMetrics.titleSize, weight: .semibold))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)

                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                        Text(episodeLabel)
                            .font(.system(size: WorkbenchLibraryMetrics.metaSize, weight: .medium))
                            .foregroundStyle(WorkbenchRedesignColors.textMuted)
                            .monospacedDigit()

                        WatchStatusBadge(status: content.watchStatus)
                    }
                    .allowsHitTesting(false)
                }
            }
            .onHover { highlight.noteHover($0, id: cardID, showsHand: true) }
            .libraryCardContextMenuTrigger(
                isEnabled: true,
                ownerID: cardID,
                items: contextMenuItems,
                openContextMenu: { items, point, ownerID in
                    highlight.notePress(id: cardID)
                    openContextMenu(items, point, ownerID)
                }
            )
            .onAppear {
                guard isWorkbench || isPlaybackOverlay || isCommandPanel else { return }
                syncAccessibilityAction(accessibility, layer: layerContext.layer)
            }
            .onDisappear {
                let token = ObjectIdentifier(moreMenuAnchor)
                if isWorkbench {
                    accessibility?.unregisterMediaCardAction(id: cardID, ownerToken: token)
                } else if isPlaybackOverlay {
                    accessibility?.unregisterPlaybackOverlayCardAction(id: cardID, ownerToken: token)
                } else if isCommandPanel {
                    accessibility?.unregisterCommandPanelCardAction(id: cardID, ownerToken: token)
                }
            }
            .accessibilityLabel(
                "\(content.folderTitle), \(episodeLabel), \(content.watchStatus.title)"
            )
        }
    }

    private func syncAccessibilityAction(
        _ accessibility: WorkbenchAccessibilityCoordinator?,
        layer: InterfaceLayer
    ) {
        let items = contextMenuItems
        let anchor = moreMenuAnchor
        let id = cardID
        let toggle = toggleAnchorMenu
        let token = ObjectIdentifier(anchor)
        switch layer {
        case .workbenchPage:
            accessibility?.registerMediaCardAction(id: id, ownerToken: token) {
                toggle?(items, anchor, id)
            }
        case .playbackOverlay:
            accessibility?.registerPlaybackOverlayCardAction(id: id, ownerToken: token) {
                toggle?(items, anchor, id)
            }
        case .commandPanel:
            accessibility?.registerCommandPanelCardAction(id: id, ownerToken: token) {
                toggle?(items, anchor, id)
            }
        default:
            break
        }
    }

    private func cover(isActionFocused: Bool) -> some View {
        LibraryCoverWithProgress(
            coverPath: content.coverPath,
            coverRevision: content.coverRevision,
            positionMilliseconds: content.positionMilliseconds,
            duration: content.duration,
            showsMoreButton: isMoreButtonVisible || isActionFocused,
            isMoreMenuOpen: isMoreMenuOpen,
            isMoreButtonFocused: isActionFocused,
            moreMenuAnchor: moreMenuAnchor,
            onMoreHoverChange: { isButtonHovered in
                highlight.noteActionButtonHover(isButtonHovered, id: cardID)
            },
            onToggleMoreMenu: {
                highlight.notePress(id: cardID)
                toggleAnchorMenu?(contextMenuItems, moreMenuAnchor, cardID)
            }
        )
    }

    private var contextMenuItems: [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: L("library.open_folder"), icon: .folder) {
                actions.revealFile(content.videoPath)
            },
            LibraryCardContextMenuItem(
                title: LibraryCoverContextMenuItem.title,
                icon: LibraryCoverContextMenuItem.icon
            ) {
                actions.changeCover(
                    .video(path: content.videoPath),
                    content.coverPath,
                    content.coverRevision
                )
            },
            LibraryCardContextMenuItem(title: L("library.mark_finished"), icon: .checkCircle) {
                actions.markVideo(content.libraryVideo, .finished)
            },
            LibraryCardContextMenuItem(title: L("library.mark_unwatched"), icon: .circle) {
                actions.markVideo(content.libraryVideo, .unwatched)
            },
            LibraryCardContextMenuItem(title: L("library.mark_watching"), icon: .playCircle) {
                actions.markVideo(content.libraryVideo, .watching)
            }
        ]
    }

    private var episodeLabel: String {
        String(format: "EP%02d", content.episodeNumber)
    }
}

struct CompleteLibraryFolderGrid: View {
    @EnvironmentObject private var appState: AppCoordinator
    let folders: [CompleteLibraryFolderSummaryPresentation]
    @ObservedObject var highlight: CardHighlightModel
    let onOpen: (CompleteLibraryFolderSummaryPresentation) -> Void

    var body: some View {
        LibraryCardContextMenuHost { openContextMenu in
            LibraryOverviewGrid(items: folders) { folder in
                LibraryFolderCard(
                    folder: folder,
                    highlight: highlight,
                    isSelected: highlight.isSelected(folder.id),
                    isHovered: highlight.isHovered(folder.id),
                    actions: .appState(appState),
                    openContextMenu: openContextMenu
                ) {
                    onOpen(folder)
                }
            }
        }
    }
}

struct LibraryFolderCard: View {
    @Environment(\.libraryCardContextMenuToggleAnchor) private var toggleAnchorMenu
    @Environment(\.libraryCardContextMenuAnchorOwner) private var anchorMenuOwnerID
    let folder: CompleteLibraryFolderSummaryPresentation
    @ObservedObject var highlight: CardHighlightModel
    let isSelected: Bool
    let isHovered: Bool
    let actions: LibraryCardActionHandlers
    let openContextMenu: ([LibraryCardContextMenuItem], CGPoint, String) -> Void
    let onOpen: () -> Void

    @State private var moreMenuAnchor = MenuAnchorHandle()

    private var isAvailable: Bool {
        folder.episodeCount > 0
    }

    private var cardID: String {
        folder.id
    }

    private var isMoreMenuOpen: Bool {
        isAvailable && anchorMenuOwnerID == cardID
    }

    private var isMoreButtonVisible: Bool {
        isAvailable && (highlight.isPointerHovered(cardID) || isMoreMenuOpen)
    }

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            let _ = !highlight.keepsCurrentWhenPointerLeaves
                ? highlight.syncSelectedDuringRender(accessibility?.focusedCardID)
                : ()
            let _ = syncAccessibilityAction(accessibility)
            let isCardFocused = accessibility?.isFocused(.mediaCard(cardID)) == true
            let isActionFocused = accessibility?.isFocused(.mediaCardActionButton(cardID)) == true

            LibraryOverviewCardSurface(
                isSelected: highlight.isSelected(cardID),
                isHovered: highlight.isHovered(cardID),
                isFocused: isCardFocused,
                isEnabled: isAvailable,
                animatesHover: highlight.animatesHoverBackground,
                action: {
                    guard isAvailable else {
                        return
                    }
                    highlight.notePress(id: cardID)
                    onOpen()
                }
            ) {
                LibraryOverviewCardContent(title: folder.folderTitle) {
                    cover(isActionFocused: isActionFocused)
                }
            }
            .onHover { highlight.noteHover($0, id: cardID, showsHand: isAvailable) }
            .libraryCardContextMenuTrigger(
                isEnabled: isAvailable,
                ownerID: cardID,
                items: folderContextMenuItems,
                openContextMenu: { items, point, ownerID in
                    highlight.notePress(id: cardID)
                    openContextMenu(items, point, ownerID)
                }
            )
            .onAppear {
                syncAccessibilityAction(accessibility)
            }
            .onDisappear {
                accessibility?.unregisterMediaCardAction(
                    id: cardID,
                    ownerToken: ObjectIdentifier(moreMenuAnchor)
                )
            }
            .accessibilityLabel(folder.folderTitle)
        }
    }

    private func syncAccessibilityAction(_ accessibility: WorkbenchAccessibilityCoordinator?) {
        let available = isAvailable
        let items = folderContextMenuItems
        let anchor = moreMenuAnchor
        let id = cardID
        let toggle = toggleAnchorMenu
        accessibility?.registerMediaCardAction(
            id: id,
            ownerToken: ObjectIdentifier(anchor)
        ) {
            guard available else { return }
            toggle?(items, anchor, id)
        }
    }

    private func cover(isActionFocused: Bool) -> some View {
        LibraryCoverWithBadge(
            coverPath: folder.coverPath,
            coverRevision: folder.coverRevision,
            badgeText: episodeCountText,
            showsMoreButton: isMoreButtonVisible || (isAvailable && isActionFocused),
            isMoreMenuOpen: isMoreMenuOpen,
            isMoreButtonFocused: isActionFocused,
            moreMenuAnchor: moreMenuAnchor,
            onMoreHoverChange: { isButtonHovered in
                highlight.noteActionButtonHover(isButtonHovered, id: cardID)
            },
            onToggleMoreMenu: {
                guard isAvailable else {
                    return
                }
                highlight.notePress(id: cardID)
                toggleAnchorMenu?(folderContextMenuItems, moreMenuAnchor, cardID)
            }
        )
    }

    private var folderContextMenuItems: [LibraryCardContextMenuItem] {
        Self.contextMenuItems(for: folder, actions: actions)
    }

    static func contextMenuItems(
        for folder: CompleteLibraryFolderSummaryPresentation,
        actions: LibraryCardActionHandlers
    ) -> [LibraryCardContextMenuItem] {
        [
            LibraryCardContextMenuItem(title: L("library.open_folder"), icon: .folder) {
                actions.openFolder(folder.folderPath)
            },
            LibraryCardContextMenuItem(
                title: LibraryCoverContextMenuItem.title,
                icon: LibraryCoverContextMenuItem.icon
            ) {
                actions.changeCover(
                    .folder(path: folder.folderPath),
                    folder.coverPath,
                    folder.coverRevision
                )
            },
            LibraryCardContextMenuItem(title: L("library.mark_all_finished"), icon: .checkCircle) {
                actions.markFolder(folder.folderPath, .finished)
            },
            LibraryCardContextMenuItem(title: L("library.mark_all_unwatched"), icon: .circle) {
                actions.markFolder(folder.folderPath, .unwatched)
            },
            LibraryCardContextMenuItem(title: L("library.mark_all_watching"), icon: .playCircle) {
                actions.markFolder(folder.folderPath, .watching)
            }
        ]
    }

    private var episodeCountText: String {
        folder.episodeCount == 1
            ? L("library.episode_count.one")
            : L("library.episode_count.other", folder.episodeCount)
    }
}

struct CompleteLibraryEpisodeGrid: View {
    let folderTitle: String
    let videos: [CompleteLibraryVideoPresentation]
    @ObservedObject var highlight: CardHighlightModel
    var emptyMinHeight: CGFloat = 0
    var itemFrameCoordinateSpace: String? = nil
    var onItemFramesChange: ([String: CGRect]) -> Void = { _ in }
    let onOpen: (CompleteLibraryVideoPresentation) -> Void

    var body: some View {
        if videos.isEmpty {
            WorkbenchEmptyHint(
                icon: .video,
                message: L("library.episodes_empty")
            )
            .frame(minHeight: emptyMinHeight)
        } else {
            LibraryVideoCardGrid(
                items: videos,
                highlight: highlight,
                itemFrameCoordinateSpace: itemFrameCoordinateSpace,
                onItemFramesChange: onItemFramesChange,
                content: {
                    LibraryVideoCardContent(
                        folderTitle: folderTitle,
                        video: $0
                    )
                },
                onOpen: onOpen
            )
        }
    }
}
