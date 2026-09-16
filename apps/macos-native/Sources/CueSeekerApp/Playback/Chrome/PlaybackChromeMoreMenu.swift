import AppKit
import CueSeekerCore
import SwiftUI

/// The More menu's submenus, in the order the menu lists them.
enum PlaybackMoreSubmenu: Int, CaseIterable, Hashable {
    case audioTrack
    case defaultAudioTrack

    var title: String {
        switch self {
        case .audioTrack:
            L("playback.more.audio_track")
        case .defaultAudioTrack:
            L("playback.more.default_audio_track")
        }
    }
}

/// What the More menu lists for the open video: the audio tracks Index
/// recorded, the one playing and the default audio track. Both indexes are the
/// tracks that take effect, so a track the list does not reach shows as the
/// first.
struct PlaybackAudioTrackMenu: Equatable {
    let trackNames: [String]
    let currentIndex: Int
    let defaultIndex: Int

    /// The submenu checks one track and tags the other the submenu does not
    /// set: Audio Track checks the one playing and tags the default, Default
    /// Audio Track the reverse.
    func checkedIndex(in submenu: PlaybackMoreSubmenu) -> Int {
        submenu == .audioTrack ? currentIndex : defaultIndex
    }

    func tag(in submenu: PlaybackMoreSubmenu) -> (index: Int, title: String) {
        switch submenu {
        case .audioTrack:
            (defaultIndex, L("playback.more.default_tag"))
        case .defaultAudioTrack:
            (currentIndex, L("playback.more.current_tag"))
        }
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

/// The More menu and its open submenu, laid over the playback stage so a long
/// track list has the stage's height to open into.
struct PlaybackChromeMoreMenuOverlay: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var submenuState: MenuSubmenuState<PlaybackMoreSubmenu>
    let menu: PlaybackAudioTrackMenu
    let buttonFrame: CGRect
    let suppressesInteraction: Bool
    let onSelect: (PlaybackMoreSubmenu, Int) -> Void
    @State private var submenuHeights: [PlaybackMoreSubmenu: CGFloat] = [:]

    private static let padding = PlaybackChromeMetrics.speedMenuPadding
    private static let itemHeight = PlaybackChromeMetrics.speedMenuItemHeight
    private static let itemGap = PlaybackChromeMetrics.speedMenuItemVerticalGap

    var body: some View {
        GeometryReader { proxy in
            // Menus keep the margin the controls use from the stage's edges.
            let bounds = CGRect(origin: .zero, size: proxy.size)
                .insetBy(
                    dx: PlaybackChromeMetrics.chromeHorizontalPadding,
                    dy: PlaybackChromeMetrics.chromeHorizontalPadding
                )
            let menuFrame = MenuPlacement.openingFrame(
                anchor: buttonFrame,
                menuSize: Self.menuSize,
                in: bounds,
                gap: PlaybackChromeMetrics.speedMenuGap
            )
            let openSubmenu = submenuState.openParent
            let submenu = openSubmenu.flatMap { submenu in
                submenuHeights[submenu].map {
                    submenuPlacement(submenu, naturalHeight: $0, menuFrame: menuFrame, bounds: bounds)
                }
            }

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
                            triggerFrame: Self.triggerFrame(openSubmenu)
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

                PlaybackMoreMenuHost(content: AnyView(firstLevelMenu))
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                interactiveRegion(menuFrame)

                if let openSubmenu, let submenu {
                    PlaybackMoreMenuHost(
                        content: AnyView(
                            audioTrackMenu(openSubmenu, maximumHeight: submenu.maximumHeight)
                        )
                    )
                    .frame(width: submenu.frame.width, height: submenu.frame.height)
                    .offset(x: submenu.frame.minX, y: submenu.frame.minY)
                    interactiveRegion(submenu.frame)
                }
            }
        }
        .onAppear {
            submenuHeights = measuredSubmenuHeights()
        }
        .onChange(of: menu) { _ in
            submenuHeights = measuredSubmenuHeights()
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
                        isEnabled: !menu.trackNames.isEmpty,
                        suppressesInteraction: suppressesInteraction,
                        highlight: playback.moreMenuHighlight,
                        submenuState: submenuState
                    )
                    .id(submenu.rawValue)
                }
            }
        }
    }

    private func audioTrackMenu(
        _ submenu: PlaybackMoreSubmenu,
        maximumHeight: CGFloat
    ) -> some View {
        let tag = menu.tag(in: submenu)
        return WorkbenchPopoverPanel(
            surface: .playerChrome,
            maximumHeight: maximumHeight,
            highlight: playback.moreSubmenuHighlight
        ) {
            VStack(spacing: Self.itemGap) {
                ForEach(Array(menu.trackNames.enumerated()), id: \.offset) { index, name in
                    PlaybackAudioTrackMenuItem(
                        name: name,
                        isChecked: menu.checkedIndex(in: submenu) == index,
                        tag: tag.index == index ? tag.title : nil,
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

    private static var menuSize: CGSize {
        let count = CGFloat(PlaybackMoreSubmenu.allCases.count)
        return CGSize(
            width: PlaybackChromeMetrics.moreMenuWidth,
            height: padding * 2 + itemHeight * count + itemGap * (count - 1)
        )
    }

    /// The trigger's frame in the menu's own space.
    private static func triggerFrame(_ submenu: PlaybackMoreSubmenu) -> CGRect {
        CGRect(
            x: padding,
            y: padding + CGFloat(submenu.rawValue) * (itemHeight + itemGap),
            width: PlaybackChromeMetrics.moreMenuWidth - padding * 2,
            height: itemHeight
        )
    }

    /// Where the submenu sits and how tall it may be. When the stage cannot
    /// hold its natural height it is held to the room there is, which brings
    /// up its scrollbar and widens it by the scrollbar's strip.
    private func submenuPlacement(
        _ submenu: PlaybackMoreSubmenu,
        naturalHeight: CGFloat,
        menuFrame: CGRect,
        bounds: CGRect
    ) -> (frame: CGRect, maximumHeight: CGFloat) {
        let width = PlaybackChromeMetrics.audioTrackMenuWidth
        let frame = MenuSubmenuGeometry.frame(
            parentMenuFrame: menuFrame,
            parentItemFrame: Self.triggerFrame(submenu),
            submenuSize: CGSize(width: width, height: naturalHeight),
            visibleRect: bounds
        )
        guard frame.height < naturalHeight else {
            return (frame, MenuMetrics.maximumHeight)
        }
        return (
            MenuSubmenuGeometry.frame(
                parentMenuFrame: menuFrame,
                parentItemFrame: Self.triggerFrame(submenu),
                submenuSize: CGSize(
                    width: width + MenuMetrics.scrollbarStrip,
                    height: frame.height
                ),
                visibleRect: bounds
            ),
            frame.height
        )
    }

    /// Each submenu's height as it lays out, capped the way every menu is.
    /// The two submenus tag different tracks, and a tag narrows the name
    /// beside it, so they can wrap differently.
    private func measuredSubmenuHeights() -> [PlaybackMoreSubmenu: CGFloat] {
        Dictionary(uniqueKeysWithValues: PlaybackMoreSubmenu.allCases.map { submenu in
            let host = NSHostingView(
                rootView: audioTrackMenu(submenu, maximumHeight: MenuMetrics.maximumHeight)
            )
            host.layoutSubtreeIfNeeded()
            return (submenu, host.fittingSize.height)
        })
    }
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
            submenuState.open(submenu)
        } label: {
            HStack(spacing: PlaybackChromeMetrics.speedMenuItemContentGap) {
                Text(submenu.title)
                    .font(.system(size: PlaybackChromeMetrics.speedMenuItemFontSize, weight: .medium))

                Spacer(minLength: 0)

                AppIconImage(.caretRight, size: PlaybackChromeMetrics.speedMenuCheckFontSize)
            }
            .foregroundStyle(isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary)
            .padding(.leading, PlaybackChromeMetrics.speedMenuItemHorizontalPadding)
            // A Trailing Slot holding an icon gives up 2pt on its side.
            .padding(.trailing, PlaybackChromeMetrics.speedMenuItemHorizontalPadding - 2)
            .frame(
                width: PlaybackChromeMetrics.moreMenuWidth - PlaybackChromeMetrics.speedMenuPadding * 2,
                height: PlaybackChromeMetrics.speedMenuItemHeight
            )
            .contentShape(RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuItemRadius))
        }
        .buttonStyle(
            PlaybackChromeMenuButtonStyle(
                isHighlighted: highlight.highlightedPosition == submenu.rawValue,
                suppressesInteraction: suppressesInteraction,
                onHoverChange: { isHovered in
                    // Crossing to the open submenu over this item means nothing.
                    guard !submenuState.isPointerInSafeArea else {
                        return
                    }
                    highlight.noteHover(isHovered, at: submenu.rawValue)
                    if isEnabled {
                        submenuState.setParentHovered(submenu, isHovered: isHovered)
                    }
                }
            )
        )
        .focusable(false)
    }
}

/// One track: the check, the whole name, which wraps, and the tag.
private struct PlaybackAudioTrackMenuItem: View {
    let name: String
    let isChecked: Bool
    let tag: String?
    let position: Int
    let suppressesInteraction: Bool
    @ObservedObject var highlight: MenuHighlightModel
    let action: () -> Void

    /// One line of the name, so the check and the tag sit on its first line
    /// however far the name wraps.
    private static let lineHeight: CGFloat = 16

    var body: some View {
        Button {
            guard !suppressesInteraction else {
                return
            }
            action()
        } label: {
            HStack(alignment: .top, spacing: PlaybackChromeMetrics.speedMenuItemContentGap) {
                AppIconImage(.check, size: PlaybackChromeMetrics.speedMenuCheckFontSize)
                    .opacity(isChecked ? 1 : 0)
                    .frame(width: PlaybackChromeMetrics.speedMenuCheckColumnWidth, height: Self.lineHeight)

                Text(name)
                    .font(.system(
                        size: PlaybackChromeMetrics.speedMenuItemFontSize,
                        weight: isChecked ? .bold : .medium
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
            .padding(.horizontal, PlaybackChromeMetrics.speedMenuItemHorizontalPadding)
            .padding(.vertical, (PlaybackChromeMetrics.speedMenuItemHeight - Self.lineHeight) / 2)
            .frame(
                width: PlaybackChromeMetrics.audioTrackMenuWidth - PlaybackChromeMetrics.speedMenuPadding * 2,
                alignment: .leading
            )
            .contentShape(RoundedRectangle(cornerRadius: PlaybackChromeMetrics.speedMenuItemRadius))
        }
        .buttonStyle(
            PlaybackChromeMenuButtonStyle(
                isHighlighted: highlight.highlightedPosition == position,
                suppressesInteraction: suppressesInteraction,
                onHoverChange: { isHovered in
                    highlight.noteHover(isHovered, at: position)
                }
            )
        )
        .focusable(false)
    }
}
