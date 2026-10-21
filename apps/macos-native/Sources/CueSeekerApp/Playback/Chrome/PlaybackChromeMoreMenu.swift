import AppKit
import CueSeekerCore
import SwiftUI

/// The More menu's submenus, in the order the menu lists them.
enum PlaybackMoreSubmenu: Int, CaseIterable, Hashable {
    case audioTrack
    case subtitle
    case defaultAudioTrack
    case defaultSubtitle

    var title: String {
        switch self {
        case .audioTrack:
            L("playback.more.audio_track")
        case .subtitle:
            L("playback.more.subtitle")
        case .defaultAudioTrack:
            L("playback.more.default_audio_track")
        case .defaultSubtitle:
            L("playback.more.default_subtitle")
        }
    }

    /// Whether the submenu sets the default rather than what plays now.
    var setsDefault: Bool {
        self == .defaultAudioTrack || self == .defaultSubtitle
    }
}

/// One list the More menu offers for the open video: the names in order, the
/// one playing and the default. Both indexes are the items that take effect,
/// so one the list does not reach shows as the first.
struct PlaybackMoreMenuList: Equatable {
    let names: [String]
    let currentIndex: Int
    let defaultIndex: Int
}

/// What the More menu lists for the open video: the audio tracks Index
/// recorded and the subtitles matched to it.
struct PlaybackMoreMenu: Equatable {
    let audioTracks: PlaybackMoreMenuList
    let subtitles: PlaybackMoreMenuList

    func list(in submenu: PlaybackMoreSubmenu) -> PlaybackMoreMenuList {
        switch submenu {
        case .audioTrack, .defaultAudioTrack:
            audioTracks
        case .subtitle, .defaultSubtitle:
            subtitles
        }
    }

    /// The submenu checks one item and tags the other the submenu does not
    /// set: Audio Track and Subtitle check the one playing and tag the
    /// default, their Default submenus the reverse.
    func checkedIndex(in submenu: PlaybackMoreSubmenu) -> Int {
        let list = list(in: submenu)
        return submenu.setsDefault ? list.defaultIndex : list.currentIndex
    }

    func tag(in submenu: PlaybackMoreSubmenu) -> (index: Int, title: String) {
        let list = list(in: submenu)
        return submenu.setsDefault
            ? (list.currentIndex, L("playback.more.current_tag"))
            : (list.defaultIndex, L("playback.more.default_tag"))
    }

    /// The triggers that open a submenu: those whose list is not empty.
    var enabledSubmenus: [PlaybackMoreSubmenu] {
        PlaybackMoreSubmenu.allCases.filter { !list(in: $0).names.isEmpty }
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
            track.codec,
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

/// The More menu and its open submenu, laid over the playback stage so a long
/// list has the stage's height to open into.
struct PlaybackChromeMoreMenuOverlay: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var submenuState: MenuSubmenuState<PlaybackMoreSubmenu>
    let menu: PlaybackMoreMenu
    let buttonFrame: CGRect
    let suppressesInteraction: Bool
    let onSelect: (PlaybackMoreSubmenu, Int) -> Void
    @State private var layout: PlaybackMoreMenuLayout?

    private static let padding = MenuMetrics.padding
    private static let itemHeight = WorkbenchControlMetrics.redesignMenuItemHeight
    private static let itemGap: CGFloat = 0

    /// What the layout is measured from.
    private struct LayoutInput: Equatable {
        let stageSize: CGSize
        let buttonFrame: CGRect
        let menu: PlaybackMoreMenu
    }

    var body: some View {
        GeometryReader { proxy in
            let menuFrame = layout?.menuFrame ?? .zero
            let openSubmenu = submenuState.openParent
            let submenu = openSubmenu.flatMap { layout?.submenus[$0] }

            ZStack(alignment: .topLeading) {
                MenuGateClientView(
                    gate: playback.interfaceLayers.menuGate,
                    owner: .playbackPage,
                    kind: .playerMoreMenu,
                    menuFrame: menuFrame,
                    submenuFrame: submenu?.frame,
                    // A press on the More button is left to the button, which
                    // closes the menu it opened.
                    anchorFrame: buttonFrame,
                    notePointer: { point in
                        guard let openSubmenu, let submenu else {
                            return
                        }
                        submenuState.notePointer(
                            point,
                            parentMenuFrame: menuFrame,
                            triggerFrame: Self.triggerFrame(openSubmenu, menuWidth: menuFrame.width)
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
                    PlaybackMoreMenuHost(content: AnyView(firstLevelMenu))
                        .frame(width: menuFrame.width, height: menuFrame.height)
                        .offset(x: menuFrame.minX, y: menuFrame.minY)
                    interactiveRegion(menuFrame)
                }

                if let openSubmenu, let submenu {
                    PlaybackMoreMenuHost(
                        content: AnyView(
                            submenuPanel(
                                openSubmenu,
                                itemWidth: submenu.itemWidth,
                                maximumHeight: submenu.maximumHeight
                            )
                        )
                    )
                    .frame(width: submenu.frame.width, height: submenu.frame.height)
                    .offset(x: submenu.frame.minX, y: submenu.frame.minY)
                    interactiveRegion(submenu.frame)
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

    // MARK: - Menus

    private var firstLevelMenu: some View {
        WorkbenchPopoverPanel(
            surface: .playerChrome,
            highlight: playback.moreMenuHighlight
        ) {
            VStack(spacing: Self.itemGap) {
                ForEach(PlaybackMoreSubmenu.allCases, id: \.self) { submenu in
                    PlaybackMoreMenuTrigger(
                        submenu: submenu,
                        isEnabled: menu.enabledSubmenus.contains(submenu),
                        suppressesInteraction: suppressesInteraction,
                        highlight: playback.moreMenuHighlight,
                        submenuState: submenuState
                    )
                    .id(submenu.rawValue)
                }
            }
        }
    }

    private func submenuPanel(
        _ submenu: PlaybackMoreSubmenu,
        itemWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> some View {
        WorkbenchPopoverPanel(
            surface: .playerChrome,
            maximumHeight: maximumHeight,
            highlight: playback.moreSubmenuHighlight
        ) {
            items(submenu, itemWidth: itemWidth)
        }
    }

    /// The submenu's items, laid out at the given width, or each name on one
    /// line when there is none.
    private func items(_ submenu: PlaybackMoreSubmenu, itemWidth: CGFloat?) -> some View {
        let tag = menu.tag(in: submenu)
        return VStack(spacing: Self.itemGap) {
            ForEach(Array(menu.list(in: submenu).names.enumerated()), id: \.offset) { index, name in
                PlaybackMoreSubmenuItem(
                    name: name,
                    isChecked: menu.checkedIndex(in: submenu) == index,
                    tag: tag.index == index ? tag.title : nil,
                    width: itemWidth,
                    position: index,
                    suppressesInteraction: suppressesInteraction,
                    highlight: playback.moreSubmenuHighlight,
                    action: {
                        onSelect(submenu, index)
                        playback.closeMoreMenu()
                    }
                )
                .id(index)
            }
        }
    }

    /// A clickable control for the Player UI's idle hide: the menus are hosted
    /// in AppKit views, which the stage's SwiftUI preference cannot see into.
    private func interactiveRegion(_ frame: CGRect) -> some View {
        Color.clear
            .frame(width: frame.width, height: frame.height)
            .playerInteractiveRegion()
            .offset(x: frame.minX, y: frame.minY)
            .allowsHitTesting(false)
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

    /// The trigger's frame in the menu's own space.
    private static func triggerFrame(_ submenu: PlaybackMoreSubmenu, menuWidth: CGFloat) -> CGRect {
        CGRect(
            x: padding,
            y: padding + CGFloat(submenu.rawValue) * (itemHeight + itemGap),
            width: menuWidth - padding * 2,
            height: itemHeight
        )
    }

    /// Where a submenu sits and the width its items are laid out at. It is as
    /// wide as its names on one line, held to the cap and to the room on the
    /// side it opens to: the right when it fits there, else the left, else the
    /// wider side. When the room cannot hold its height it scrolls, and the
    /// scrollbar's strip comes out of the items' width where the room has
    /// nothing more to give.
    static func submenuLayout(
        naturalItemWidth: CGFloat,
        itemStackHeight: (CGFloat) -> CGFloat,
        menuFrame: CGRect,
        triggerFrame: CGRect,
        bounds: CGRect
    ) -> PlaybackMoreSubmenuLayout {
        let padding = Self.padding * 2
        let wanted = min(naturalItemWidth + padding, PlaybackChromeMetrics.audioTrackMenuMaxWidth)
        let roomRight = bounds.maxX - menuFrame.maxX
        let roomLeft = menuFrame.minX - bounds.minX
        let room = wanted <= roomRight ? roomRight
            : wanted <= roomLeft ? roomLeft
            : max(roomRight, roomLeft)
        let maximumHeight = min(MenuMetrics.maximumHeight, bounds.height)
        var itemWidth = min(wanted, room) - padding
        var size = CGSize(width: itemWidth + padding, height: itemStackHeight(itemWidth) + padding)
        if size.height > maximumHeight {
            itemWidth = min(itemWidth, room - padding - MenuMetrics.scrollbarStrip)
            size = CGSize(
                width: itemWidth + padding + MenuMetrics.scrollbarStrip,
                height: maximumHeight
            )
        }
        return PlaybackMoreSubmenuLayout(
            frame: MenuSubmenuGeometry.frame(
                parentMenuFrame: menuFrame,
                parentItemFrame: triggerFrame,
                submenuSize: size,
                visibleRect: bounds
            ),
            itemWidth: itemWidth,
            maximumHeight: maximumHeight
        )
    }

    /// Measures the menus as they lay out and places them on the stage. A
    /// submenu and its Default submenu tag different items, and a tag narrows
    /// the name beside it, so each is measured on its own.
    func measuredLayout(stageSize: CGSize) -> PlaybackMoreMenuLayout {
        let bounds = Self.bounds(stageSize: stageSize, buttonFrame: buttonFrame)
        let menuFrame = MenuPlacement.openingFrame(
            anchor: buttonFrame,
            menuSize: NSHostingView(rootView: firstLevelMenu).fittingSize,
            in: bounds,
            gap: PlaybackChromeMetrics.speedMenuGap
        )
        return PlaybackMoreMenuLayout(
            menuFrame: menuFrame,
            submenus: Dictionary(uniqueKeysWithValues: PlaybackMoreSubmenu.allCases.map { submenu in
                let layout = Self.submenuLayout(
                    naturalItemWidth: NSHostingView(rootView: items(submenu, itemWidth: nil))
                        .fittingSize.width,
                    itemStackHeight: { width in
                        NSHostingView(rootView: items(submenu, itemWidth: width)).fittingSize.height
                    },
                    menuFrame: menuFrame,
                    triggerFrame: Self.triggerFrame(submenu, menuWidth: menuFrame.width),
                    bounds: bounds
                )
                return (submenu, layout)
            })
        )
    }
}

/// Where the More menu and its submenus sit on the stage.
struct PlaybackMoreMenuLayout {
    let menuFrame: CGRect
    let submenus: [PlaybackMoreSubmenu: PlaybackMoreSubmenuLayout]
}

struct PlaybackMoreSubmenuLayout {
    let frame: CGRect
    /// The width the tracks are laid out at; names wrap inside it.
    let itemWidth: CGFloat
    /// How tall the submenu may grow before it scrolls.
    let maximumHeight: CGFloat
}

/// Hosts a menu surface in the menu hosting view, the way every menu in the
/// App is hosted, so the submenu's own scrolling sees the wheel first and
/// nothing underneath takes what it leaves.
private struct PlaybackMoreMenuHost: NSViewRepresentable {
    let content: AnyView

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: content)
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = content
    }
}

/// A Submenu Trigger: the pointer reaching it opens its submenu at once, and a
/// press opens it too.
private struct PlaybackMoreMenuTrigger: View {
    let submenu: PlaybackMoreSubmenu
    let isEnabled: Bool
    let suppressesInteraction: Bool
    @ObservedObject var highlight: MenuHighlightModel
    @ObservedObject var submenuState: MenuSubmenuState<PlaybackMoreSubmenu>

    var body: some View {
        Button {
            guard isEnabled, !suppressesInteraction else {
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
                    size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS
                )
            }
            .foregroundStyle(isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary)
            .padding(.leading, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
            // A Trailing Slot holding an icon gives up 2pt on its side.
            .padding(.trailing, WorkbenchControlMetrics.redesignMenuItemTrailingIconPadding)
            // As wide as the widest trigger's content, which the menu takes.
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
                suppressesInteraction: suppressesInteraction,
                onHoverChange: { isHovered in
                    submenuState.noteItemHover(
                        isHovered,
                        at: submenu.rawValue,
                        trigger: isEnabled ? submenu : nil,
                        highlight: highlight
                    )
                }
            )
        )
        .focusable(false)
    }
}

/// One item: the check, the whole name, which wraps, and the tag.
private struct PlaybackMoreSubmenuItem: View {
    let name: String
    let isChecked: Bool
    let tag: String?
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
        Button {
            guard !suppressesInteraction else {
                return
            }
            action()
        } label: {
            HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                AppIconImage(
                    .check,
                    size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS
                )
                .opacity(isChecked ? 1 : 0)
                .frame(
                    width: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS,
                    height: Self.lineHeight
                )

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
            .foregroundStyle(PlaybackTheme.textPrimary)
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
        .buttonStyle(
            PlaybackChromeMenuButtonStyle(
                isHighlighted: highlight.isSelected(position),
                isHovered: highlight.isHovered(position),
                suppressesInteraction: suppressesInteraction,
                onHoverChange: { isHovered in
                    highlight.noteHover(isHovered, at: position)
                }
            )
        )
        .focusable(false)
    }
}
