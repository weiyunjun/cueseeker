import AppKit
import CueSeekerCore
import SwiftUI

/// The More menu's single submenu trigger.
enum PlaybackMoreSubmenu: Int, CaseIterable, Hashable {
    case audioTrack

    var title: String {
        L("playback.more.audio_track")
    }
}

/// One list a player menu offers for the open video: the names in order, the
/// one playing and the default. Both indexes are the items that take effect,
/// so one the list does not reach shows as the first.
struct PlaybackMoreMenuList: Equatable {
    let names: [String]
    let currentIndex: Int
    let defaultIndex: Int
}

/// What the More menu lists for the open video: the audio tracks Index
/// recorded.
struct PlaybackMoreMenu: Equatable {
    let audioTracks: PlaybackMoreMenuList

    /// Audio Track checks the track playing now and tags the default track.
    var checkedIndex: Int {
        audioTracks.currentIndex
    }

    var defaultTag: (index: Int, title: String) {
        (audioTracks.defaultIndex, L("playback.more.default_tag"))
    }
}

/// A choice in the Player Subtitle Menu: a subtitle from the snapshot captured
/// when the menu opened, or the trailing `Off` item.
enum PlaybackSubtitleMenuChoice: Equatable {
    case subtitle(Int)
    case off
}

/// What the Player Subtitle Menu lists for the open video: the snapshot of
/// matched subtitles in database order, which one is active, which one is the
/// default, and whether subtitles are currently visible.
struct PlaybackSubtitleMenu: Equatable {
    let records: [VideoSubtitle]
    let subtitles: PlaybackMoreMenuList
    let areSubtitlesVisible: Bool

    init(
        records: [VideoSubtitle] = [],
        subtitles: PlaybackMoreMenuList,
        areSubtitlesVisible: Bool
    ) {
        self.records = records
        self.subtitles = subtitles
        self.areSubtitlesVisible = areSubtitlesVisible
    }

    /// The position of the trailing `Off` item after all subtitle rows.
    var offPosition: Int {
        subtitles.names.count
    }

    /// All selectable item positions in top-to-bottom order: each subtitle row
    /// followed by `Off`.
    var selectablePositions: [Int] {
        Array(0...offPosition)
    }

    /// The single checked position: the active subtitle when subtitles are
    /// visible, or `Off` when subtitles are hidden.
    var checkedPosition: Int {
        guard areSubtitlesVisible,
              subtitles.names.indices.contains(subtitles.currentIndex)
        else {
            return offPosition
        }
        return subtitles.currentIndex
    }

    func choice(at position: Int) -> PlaybackSubtitleMenuChoice? {
        if position == offPosition {
            return .off
        }
        guard subtitles.names.indices.contains(position) else {
            return nil
        }
        return .subtitle(position)
    }

    func isChecked(at position: Int) -> Bool {
        checkedPosition == position
    }

    func tag(at position: Int) -> String? {
        guard subtitles.names.indices.contains(position),
              position == subtitles.defaultIndex
        else {
            return nil
        }
        return L("playback.more.default_tag")
    }
}

enum PlaybackAudioTrackName {
    /// `#1 日语, Commentary, opus, 2ch`: the track's number, then its language
    /// in the interface language, title, codec and channel count, leaving out
    /// whatever the file does not record.
    static func name(
        for track: VideoAudioTrack,
        at index: Int,
        locale: Locale = AppLocalization.locale
    ) -> String {
        let details = [
            track.language.map { locale.localizedString(forLanguageCode: $0) ?? $0 },
            track.title,
            MediaDetailFormatter.audioCodecText(track.codec),
            track.channels.map { "\($0)ch" },
        ].compactMap { $0 }
        let number = "#\(index + 1)"
        return details.isEmpty ? number : "\(number) \(details.joined(separator: ", "))"
    }
}

enum PlaybackSubtitleName {
    /// The last two extensions of the file name at most: `.sc.ass`, or `.srt`
    /// when the name has only one.
    static func name(forSubtitlePath path: String) -> String {
        let fileName = URL.fromMediaPath(path).lastPathComponent as NSString
        let last = fileName.pathExtension
        let secondLast = (fileName.deletingPathExtension as NSString).pathExtension
        return secondLast.isEmpty ? ".\(last)" : ".\(secondLast).\(last)"
    }
}

/// Shared layout and two-pass measurement for Player Chrome menu panels whose
/// item names wrap up to `PlaybackChromeMetrics.audioTrackMenuMaxWidth` and
/// shrink by `MenuMetrics.scrollbarStrip` when scrolling is needed.
struct PlaybackWrappedMenuPanelLayout {
    let frame: CGRect
    /// The width the items are laid out at; names wrap inside it.
    let itemWidth: CGFloat
    /// How tall the panel may grow before it scrolls.
    let maximumHeight: CGFloat

    static func resolve(
        naturalItemWidth: CGFloat,
        itemStackHeight: (CGFloat) -> CGFloat,
        room: CGFloat,
        boundsHeight: CGFloat,
        place: (CGSize) -> CGRect
    ) -> PlaybackWrappedMenuPanelLayout {
        let padding = MenuMetrics.padding * 2
        let wanted = min(naturalItemWidth + padding, PlaybackChromeMetrics.audioTrackMenuMaxWidth)
        let maximumHeight = min(MenuMetrics.maximumHeight, boundsHeight)
        var itemWidth = min(wanted, room) - padding
        var size = CGSize(width: itemWidth + padding, height: itemStackHeight(itemWidth) + padding)
        if size.height > maximumHeight {
            itemWidth = min(itemWidth, room - padding - MenuMetrics.scrollbarStrip)
            size = CGSize(
                width: itemWidth + padding + MenuMetrics.scrollbarStrip,
                height: maximumHeight
            )
        }
        return PlaybackWrappedMenuPanelLayout(
            frame: place(size),
            itemWidth: itemWidth,
            maximumHeight: maximumHeight
        )
    }

    @MainActor
    static func measure<Items: View>(
        room: CGFloat,
        boundsHeight: CGFloat,
        @ViewBuilder items: (CGFloat?) -> Items,
        place: (CGSize) -> CGRect
    ) -> PlaybackWrappedMenuPanelLayout {
        resolve(
            naturalItemWidth: NSHostingView(rootView: items(nil)).fittingSize.width,
            itemStackHeight: { width in
                NSHostingView(rootView: items(width)).fittingSize.height
            },
            room: room,
            boundsHeight: boundsHeight,
            place: place
        )
    }
}

typealias PlaybackMoreSubmenuLayout = PlaybackWrappedMenuPanelLayout
typealias PlaybackSubtitleMenuLayout = PlaybackWrappedMenuPanelLayout

/// Where the More menu and its Audio Track submenu sit on the stage.
struct PlaybackMoreMenuLayout {
    let menuFrame: CGRect
    let submenu: PlaybackWrappedMenuPanelLayout
}

/// The More menu and its Audio Track submenu, laid over the playback stage so a
/// long list has the stage's height to open into.
struct PlaybackChromeMoreMenuOverlay: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var submenuState: MenuSubmenuState<PlaybackMoreSubmenu>
    let menu: PlaybackMoreMenu
    let buttonFrame: CGRect
    let suppressesInteraction: Bool
    let onSelect: (Int) -> Void
    @State private var layout: PlaybackMoreMenuLayout?

    private static let padding = MenuMetrics.padding
    private static let itemHeight = WorkbenchControlMetrics.redesignMenuItemHeight
    private static let itemGap: CGFloat = 0

    private struct LayoutInput: Equatable {
        let stageSize: CGSize
        let buttonFrame: CGRect
        let menu: PlaybackMoreMenu
    }

    var body: some View {
        GeometryReader { proxy in
            let menuFrame = layout?.menuFrame ?? .zero
            let submenu = submenuState.openParent != nil ? layout?.submenu : nil

            ZStack(alignment: .topLeading) {
                MenuGateClientView(
                    gate: playback.interfaceLayers.menuGate,
                    owner: .playbackPage,
                    kind: .playerMoreMenu,
                    menuFrame: menuFrame,
                    submenuFrame: submenu?.frame,
                    anchorFrame: buttonFrame,
                    notePointer: { point in
                        guard let submenu else {
                            return
                        }
                        submenuState.notePointer(
                            point,
                            parentMenuFrame: menuFrame,
                            triggerFrame: Self.triggerFrame(menuWidth: menuFrame.width)
                                .offsetBy(dx: menuFrame.minX, dy: menuFrame.minY),
                            submenuFrame: submenu.frame
                        )
                    },
                    handleKey: { keyCode, isRepeat in
                        playback.handleMoreMenuKey(keyCode, isRepeat: isRepeat, onSelect: onSelect)
                    },
                    dismiss: { _ in
                        DispatchQueue.main.async {
                            playback.closeMoreMenu()
                        }
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)

                if layout != nil {
                    PlaybackHostedMenuSurface(frame: menuFrame) {
                        firstLevelMenu
                    }
                }

                if let submenu {
                    PlaybackHostedMenuSurface(frame: submenu.frame) {
                        WorkbenchPopoverPanel(
                            surface: .playerChrome,
                            maximumHeight: submenu.maximumHeight,
                            highlight: playback.moreSubmenuHighlight
                        ) {
                            items(itemWidth: submenu.itemWidth)
                        }
                    }
                }
            }
            .onAppear {
                layout = measuredLayout(stageSize: proxy.size)
            }
            .onChange(of: LayoutInput(stageSize: proxy.size, buttonFrame: buttonFrame, menu: menu)) { input in
                layout = measuredLayout(stageSize: input.stageSize)
            }
        }
    }

    private var firstLevelMenu: some View {
        WorkbenchPopoverPanel(
            surface: .playerChrome,
            highlight: playback.moreMenuHighlight
        ) {
            PlaybackMoreMenuTrigger(
                submenu: .audioTrack,
                suppressesInteraction: suppressesInteraction,
                highlight: playback.moreMenuHighlight,
                submenuState: submenuState
            )
            .id(PlaybackMoreSubmenu.audioTrack.rawValue)
        }
    }

    /// The Audio Track submenu's items, laid out at the given width, or each
    /// name on one line when measuring natural width. When the video has no
    /// audio tracks, the submenu shows a single disabled row without a leading
    /// checkmark slot.
    @ViewBuilder
    private func items(itemWidth: CGFloat?) -> some View {
        let names = menu.audioTracks.names
        if names.isEmpty {
            PlaybackChromeMenuItem(
                name: L("playback.more.no_audio_tracks"),
                showsCheckmarkSlot: false,
                isEnabled: false,
                width: itemWidth,
                position: 0,
                suppressesInteraction: suppressesInteraction,
                highlight: playback.moreSubmenuHighlight,
                action: {}
            )
        } else {
            let tag = menu.defaultTag
            VStack(spacing: Self.itemGap) {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    PlaybackChromeMenuItem(
                        name: name,
                        isChecked: menu.checkedIndex == index,
                        tag: tag.index == index ? tag.title : nil,
                        width: itemWidth,
                        position: index,
                        suppressesInteraction: suppressesInteraction,
                        highlight: playback.moreSubmenuHighlight,
                        action: {
                            onSelect(index)
                            playback.closeMoreMenu()
                        }
                    )
                    .id(index)
                }
            }
        }
    }

    // MARK: - Geometry

    /// The room the menus open into: below the top bar, above the buttons by
    /// the gap the menu keeps from them, and inside the margin the controls
    /// keep from the stage's sides.
    static func bounds(stageSize: CGSize, buttonFrame: CGRect) -> CGRect {
        let top = WorkbenchControlMetrics.redesignAppTopbarHeight
        return CGRect(
            x: PlaybackChromeMetrics.chromeHorizontalPadding,
            y: top,
            width: max(0, stageSize.width - PlaybackChromeMetrics.chromeHorizontalPadding * 2),
            height: max(0, buttonFrame.minY - PlaybackChromeMetrics.speedMenuGap - top)
        )
    }

    private static func triggerFrame(menuWidth: CGFloat) -> CGRect {
        CGRect(
            x: padding,
            y: padding,
            width: menuWidth - padding * 2,
            height: itemHeight
        )
    }

    private static func submenuRoom(
        naturalItemWidth: CGFloat,
        menuFrame: CGRect,
        bounds: CGRect
    ) -> CGFloat {
        let wanted = min(
            naturalItemWidth + padding * 2,
            PlaybackChromeMetrics.audioTrackMenuMaxWidth
        )
        let roomRight = bounds.maxX - menuFrame.maxX
        let roomLeft = menuFrame.minX - bounds.minX
        return wanted <= roomRight ? roomRight
            : wanted <= roomLeft ? roomLeft
            : max(roomRight, roomLeft)
    }

    static func submenuLayout(
        naturalItemWidth: CGFloat,
        itemStackHeight: (CGFloat) -> CGFloat,
        menuFrame: CGRect,
        triggerFrame: CGRect,
        bounds: CGRect
    ) -> PlaybackMoreSubmenuLayout {
        PlaybackWrappedMenuPanelLayout.resolve(
            naturalItemWidth: naturalItemWidth,
            itemStackHeight: itemStackHeight,
            room: submenuRoom(naturalItemWidth: naturalItemWidth, menuFrame: menuFrame, bounds: bounds),
            boundsHeight: bounds.height,
            place: { size in
                MenuSubmenuGeometry.frame(
                    parentMenuFrame: menuFrame,
                    parentItemFrame: triggerFrame,
                    submenuSize: size,
                    visibleRect: bounds
                )
            }
        )
    }

    func measuredLayout(stageSize: CGSize) -> PlaybackMoreMenuLayout {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let bounds = Self.bounds(stageSize: stageSize, buttonFrame: buttonFrame)
        let menuFrame = MenuPlacement.openingFrame(
            anchor: buttonFrame,
            menuSize: NSHostingView(rootView: firstLevelMenu).fittingSize,
            in: bounds,
            gap: PlaybackChromeMetrics.speedMenuGap
        )
        let submenu = Self.submenuLayout(
            naturalItemWidth: NSHostingView(rootView: items(itemWidth: nil)).fittingSize.width,
            itemStackHeight: { width in
                NSHostingView(rootView: items(itemWidth: width)).fittingSize.height
            },
            menuFrame: menuFrame,
            triggerFrame: Self.triggerFrame(menuWidth: menuFrame.width),
            bounds: bounds
        )
        let measureMs = max(0, (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "player_more_menu",
            trigger: "chrome_more_button",
            startedAt: startedAt,
            measureMs: measureMs
        )
        return PlaybackMoreMenuLayout(
            menuFrame: menuFrame,
            submenu: submenu
        )
    }
}

/// The Player Subtitle Menu, laid over the playback stage above the subtitle
/// button. It lists the video's matched subtitles (tagging the default), a
/// divider, and the trailing `Off` item.
struct PlaybackChromeSubtitleMenuOverlay: View {
    @ObservedObject var playback: PlaybackStore
    let menu: PlaybackSubtitleMenu
    let buttonFrame: CGRect
    let suppressesInteraction: Bool
    let onSelect: (Int) -> Void
    @State private var layout: PlaybackSubtitleMenuLayout?

    private static let itemGap: CGFloat = 0

    private struct LayoutInput: Equatable {
        let stageSize: CGSize
        let buttonFrame: CGRect
        let menu: PlaybackSubtitleMenu
    }

    var body: some View {
        GeometryReader { proxy in
            let menuFrame = layout?.frame ?? .zero

            ZStack(alignment: .topLeading) {
                MenuGateClientView(
                    gate: playback.interfaceLayers.menuGate,
                    owner: .playbackPage,
                    kind: .playerSubtitleMenu,
                    menuFrame: menuFrame,
                    anchorFrame: buttonFrame,
                    handleKey: { keyCode, isRepeat in
                        playback.handleSubtitleMenuKey(keyCode, isRepeat: isRepeat, onSelect: onSelect)
                    },
                    dismiss: { _ in
                        DispatchQueue.main.async {
                            playback.closeSubtitleMenu()
                        }
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)

                if let layout {
                    PlaybackHostedMenuSurface(frame: menuFrame) {
                        WorkbenchPopoverPanel(
                            surface: .playerChrome,
                            maximumHeight: layout.maximumHeight,
                            highlight: playback.subtitleMenuHighlight
                        ) {
                            items(itemWidth: layout.itemWidth)
                        }
                    }
                }
            }
            .onAppear {
                layout = measuredLayout(stageSize: proxy.size)
            }
            .onChange(of: LayoutInput(stageSize: proxy.size, buttonFrame: buttonFrame, menu: menu)) { input in
                layout = measuredLayout(stageSize: input.stageSize)
            }
        }
    }

    private func items(itemWidth: CGFloat?) -> some View {
        VStack(spacing: Self.itemGap) {
            ForEach(Array(menu.subtitles.names.enumerated()), id: \.offset) { index, name in
                PlaybackChromeMenuItem(
                    name: name,
                    isChecked: menu.isChecked(at: index),
                    tag: menu.tag(at: index),
                    width: itemWidth,
                    position: index,
                    suppressesInteraction: suppressesInteraction,
                    highlight: playback.subtitleMenuHighlight,
                    action: {
                        onSelect(index)
                        playback.closeSubtitleMenu()
                    }
                )
                .id(index)
            }

            WorkbenchMenuDivider()

            PlaybackChromeMenuItem(
                name: L("playback.subtitle_menu.off"),
                isChecked: menu.isChecked(at: menu.offPosition),
                tag: nil,
                width: itemWidth,
                position: menu.offPosition,
                suppressesInteraction: suppressesInteraction,
                highlight: playback.subtitleMenuHighlight,
                action: {
                    onSelect(menu.offPosition)
                    playback.closeSubtitleMenu()
                }
            )
            .id(menu.offPosition)
        }
    }

    func measuredLayout(stageSize: CGSize) -> PlaybackSubtitleMenuLayout {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let bounds = PlaybackChromeMoreMenuOverlay.bounds(
            stageSize: stageSize,
            buttonFrame: buttonFrame
        )
        let layout = PlaybackWrappedMenuPanelLayout.measure(
            room: bounds.width,
            boundsHeight: bounds.height,
            items: { width in items(itemWidth: width) },
            place: { size in
                MenuPlacement.openingFrame(
                    anchor: buttonFrame,
                    menuSize: size,
                    in: bounds,
                    gap: PlaybackChromeMetrics.speedMenuGap
                )
            }
        )
        let measureMs = max(0, (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "player_subtitle_menu",
            trigger: "chrome_subtitle_button",
            startedAt: startedAt,
            measureMs: measureMs
        )
        return layout
    }
}

/// Hosts a menu surface in the menu hosting view, the way every menu in the
/// App is hosted, so the menu's own scrolling sees the wheel first and nothing
/// underneath takes what it leaves.
struct PlaybackMoreMenuHost: NSViewRepresentable {
    let content: AnyView

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: content)
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = content
    }
}

/// Places a hosted Player Chrome menu panel at `frame` and reports its bounds
/// as an interactive region so the Player UI's idle timer does not hide while
/// the pointer rests on the menu.
private struct PlaybackHostedMenuSurface<Content: View>: View {
    let frame: CGRect
    @ViewBuilder let content: () -> Content

    var body: some View {
        PlaybackMoreMenuHost(content: AnyView(content()))
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
        Color.clear
            .frame(width: frame.width, height: frame.height)
            .playerInteractiveRegion()
            .offset(x: frame.minX, y: frame.minY)
            .allowsHitTesting(false)
    }
}

/// A Submenu Trigger: the pointer reaching it opens its submenu at once, and a
/// press opens it too.
private struct PlaybackMoreMenuTrigger: View {
    let submenu: PlaybackMoreSubmenu
    let suppressesInteraction: Bool
    @ObservedObject var highlight: MenuHighlightModel
    @ObservedObject var submenuState: MenuSubmenuState<PlaybackMoreSubmenu>

    var body: some View {
        Button {
            guard !suppressesInteraction else {
                return
            }
            highlight.selectPosition(submenu.rawValue)
            submenuState.open(submenu)
        } label: {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text(submenu.title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .medium))

                Spacer(minLength: 0)

                AppIconImage(
                    .caretRight,
                    size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                )
            }
            .foregroundStyle(PlaybackTheme.textPrimary)
            .padding(.leading, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
            // A Trailing Slot holding an icon gives up 2pt on its side.
            .padding(.trailing, WorkbenchControlMetrics.redesignMenuItemTrailingIconPadding)
            .frame(maxWidth: .infinity)
            .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(
            PlaybackChromeMenuButtonStyle(
                isHighlighted: highlight.isSelected(submenu.rawValue),
                isHovered: highlight.isHovered(submenu.rawValue),
                isAccessibilityFocused: highlight.isAccessibilityFocused(submenu.rawValue),
                suppressesInteraction: suppressesInteraction,
                onHoverChange: { isHovered in
                    submenuState.noteItemHover(
                        isHovered,
                        at: submenu.rawValue,
                        trigger: submenu,
                        highlight: highlight
                    )
                }
            )
        )
        .focusable(false)
    }
}

/// One Player Chrome menu item: optional leading checkmark slot, wrapping
/// label, and optional trailing tag. Supports both selectable radio items and
/// disabled status rows (such as `No Audio Tracks`, which omits the leading
/// checkmark slot).
private struct PlaybackChromeMenuItem: View {
    let name: String
    var showsCheckmarkSlot: Bool = true
    var isChecked: Bool = false
    var isEnabled: Bool = true
    var tag: String? = nil
    /// The width the item is laid out at; nil keeps the name on one line.
    let width: CGFloat?
    let position: Int
    let suppressesInteraction: Bool
    @ObservedObject var highlight: MenuHighlightModel
    let action: () -> Void

    /// One line of the name, so the check and the tag sit on its first line
    /// however far the name wraps.
    private static let lineHeight: CGFloat = NSLayoutManager().defaultLineHeight(
        for: NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .medium
        )
    )

    var body: some View {
        if isEnabled {
            Button {
                guard !suppressesInteraction else {
                    return
                }
                DebugInteractionLatencyProbe.measureMenuItemAction(
                    menuID: "player_chrome_menu",
                    item: name,
                    action
                )
            } label: {
                rowContent
            }
            .buttonStyle(
                PlaybackChromeMenuButtonStyle(
                    isHighlighted: highlight.isSelected(position),
                    isHovered: highlight.isHovered(position),
                    isAccessibilityFocused: highlight.isAccessibilityFocused(position),
                    suppressesInteraction: suppressesInteraction,
                    onHoverChange: { isHovered in
                        highlight.noteHover(isHovered, at: position)
                    }
                )
            )
            .focusable(false)
        } else {
            rowContent
                .overlay(
                    Group {
                        if highlight.isAccessibilityFocused(position) {
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius
                                    + WorkbenchControlMetrics.redesignFocusRingPathExpansion,
                                style: .continuous
                            )
                            .stroke(
                                PlaybackTheme.focusRing,
                                lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                            )
                            .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                            .allowsHitTesting(false)
                        }
                    }
                )
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if showsCheckmarkSlot {
                AppIconImage(
                    .check,
                    size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                )
                .opacity(isChecked ? 1 : 0)
                .frame(
                    width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS,
                    height: Self.lineHeight
                )
            }

            Text(name)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                    weight: .medium
                ))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let tag {
                Text(tag)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .medium))
                    .foregroundStyle(PlaybackTheme.textSecondary)
                    .padding(.horizontal, WorkbenchControlMetrics.redesignChipHorizontalPadding)
                    .padding(.vertical, WorkbenchControlMetrics.redesignChipVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignChipRadius)
                            .fill(PlaybackTheme.controlHoverBackground)
                    )
                    .fixedSize()
                    .frame(height: Self.lineHeight)
            }
        }
        .foregroundStyle(isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary)
        .padding(.horizontal, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
        .padding(.vertical, (WorkbenchControlMetrics.redesignMenuItemHeight - Self.lineHeight) / 2)
        .frame(width: width, alignment: .leading)
        .contentShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                style: .continuous
            )
        )
    }
}
