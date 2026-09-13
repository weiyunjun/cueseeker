import SwiftUI

enum PlaybackCueFooterMetrics {
    /// Provisional --height-playback-cue-footer, a floor rather than a fixed
    /// height: the actions wrap and the footer grows rather than truncating.
    static let minimumHeight: CGFloat = 48
}

/// Which surface the footer is drawn on. The two surfaces have different
/// backgrounds, so each carries its own keycap and button colours; it also
/// says which interface layer the buttons answer the pointer for.
enum PlaybackCueFooterSurface: Equatable {
    case playbackOverlay
    case commandPanel

    var interfaceLayer: InterfaceLayer {
        switch self {
        case .playbackOverlay:
            .playbackOverlay
        case .commandPanel:
            .commandPanel
        }
    }

    var buttonHoverBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.overlaySurfaceShortcutButtonHoverBg
        case .commandPanel:
            WorkbenchRedesignColors.popoverSurfaceShortcutButtonHoverBg
        }
    }

    var keycapBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.overlaySurfaceKeycapBg
        case .commandPanel:
            WorkbenchRedesignColors.popoverSurfaceKeycapBg
        }
    }

    var keycapHoverBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.overlaySurfaceKeycapHoverBg
        case .commandPanel:
            WorkbenchRedesignColors.popoverSurfaceKeycapHoverBg
        }
    }
}

enum PlaybackCueFooterKeycap: Equatable {
    case text(String)
    case icon(AppIcon)

    static let returnKey = Self.icon(.arrowElbowDownLeft)
}

/// The key a footer action shows: Return, which is fixed, or a shortcut the
/// user can rebind, drawn with whatever key it has now.
enum PlaybackCueFooterKeys: Equatable {
    case returnKey
    case shortcut(PlaybackShortcutAction)
}

/// One footer action: what it says, which key does the same thing, and the
/// work itself. Clicking runs exactly what the shortcut runs.
struct PlaybackCueFooterAction: Identifiable {
    let id: String
    let title: String
    let keys: PlaybackCueFooterKeys
    /// Whether the action hangs the Excerpt destination menu off its button
    /// rather than finishing on its own. The button then takes its Open
    /// appearance while the menu is up.
    var opensExcerptDestinationMenu = false
    let perform: () -> Void

    /// The four cue actions shared by Current, the subtitle Playlist and the
    /// Command Panel's search results.
    static func cueActions(
        playTitle: String,
        request: @escaping (PlaybackSubtitleFocusAction) -> Void
    ) -> [Self] {
        [
            Self(
                id: "excerpt",
                title: L("playback.save_to_excerpt"),
                keys: .shortcut(.saveToExcerpt),
                opensExcerptDestinationMenu: true,
                perform: { request(.excerpt) }
            ),
            Self(
                id: "copy-cue-text",
                title: L("row_menu.copy_cue_text"),
                keys: .shortcut(.copyCueText),
                perform: { request(.copyCueText) }
            ),
            Self(
                id: "copy-deep-link",
                title: L("row_menu.copy_deep_link"),
                keys: .shortcut(.copyDeepLink),
                perform: { request(.copyCueMarkdownLink) }
            ),
            Self(
                id: "play",
                title: playTitle,
                keys: .returnKey,
                perform: { request(.playFromThisCue) }
            ),
        ]
    }

    /// The single action of a footer whose only key is Return.
    static func primary(
        id: String,
        title: String,
        perform: @escaping () -> Void
    ) -> Self {
        Self(id: id, title: title, keys: .returnKey, perform: perform)
    }
}

enum PlaybackCueFooterStatus {
    static func cues(totalCount: Int) -> String {
        count(max(0, totalCount), key: "playback.cue_count")
    }

    static func videos(totalCount: Int) -> String {
        count(max(0, totalCount), key: "playback.video_count")
    }

    static func excerptLists(totalCount: Int) -> String {
        count(max(0, totalCount), key: "playback.excerpt_list_count")
    }

    static func searchResults(
        totalCount: Int,
        previewLimit: Int,
        hasMoreResults: Bool
    ) -> String {
        let resolvedTotalCount = max(0, totalCount)
        let resolvedPreviewLimit = max(0, previewLimit)
        let resultCount = count(resolvedTotalCount, key: "playback.result_count")
        guard resolvedTotalCount > resolvedPreviewLimit || hasMoreResults else {
            return resultCount
        }
        return resultCount + " "
            + L("playback.result_preview_note", resolvedPreviewLimit)
    }

    /// English takes the singular only for exactly one; zero is plural.
    private static func count(_ count: Int, key: String) -> String {
        count == 1 ? L("\(key).one") : L("\(key).other", count)
    }
}

/// Reports the footer's laid-out height to a surface that has to subtract it
/// from its own content area.
struct PlaybackCueFooterHeightKey: PreferenceKey {
    static let defaultValue = PlaybackCueFooterMetrics.minimumHeight

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The open `Save to Excerpt` menu: the footer it hangs off, the cue it saves,
/// and the lists it offers. The lists are read once, when the menu opens;
/// creating one closes the menu, so the snapshot cannot go stale while it is up.
struct PlaybackExcerptDestinationMenu: Equatable {
    let surface: PlaybackCueFooterSurface
    let cueID: Int64
    let destinations: [SubtitleTableRowActionDestination]
}

private struct PlaybackExcerptMenuAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = nextValue() ?? value
    }
}

struct PlaybackCueFooter: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var playback: PlaybackStore
    let surface: PlaybackCueFooterSurface
    let status: String?
    let actions: [PlaybackCueFooterAction]
    /// Describes the footer's own area, and through it the window the menu is
    /// placed in.
    @State private var hostAnchor = MenuAnchorHandle()
    @State private var menuSize: CGSize?
    /// The width the menu ends up with once its scrollbar is up, so a menu held
    /// to the room above the footer is placed against the width it really has.
    @State private var menuScrollingWidth: CGFloat?

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            if let status {
                Text(status)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playback-cue-footer-status")
            }

            WrappingFlowLayout(
                alignment: .trailing,
                horizontalSpacing: WorkbenchControlMetrics.redesignSpacing1,
                verticalSpacing: WorkbenchControlMetrics.redesignSpacing1
            ) {
                ForEach(actions) { action in
                    PlaybackCueFooterActionButton(
                        surface: surface,
                        action: action,
                        shortcuts: appState.settings.playbackShortcuts,
                        isOpen: action.opensExcerptDestinationMenu
                            && openMenu != nil
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(WorkbenchRedesignColors.textMuted)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        .frame(minHeight: PlaybackCueFooterMetrics.minimumHeight)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: PlaybackCueFooterHeightKey.self,
                    value: geometry.size.height
                )
            }
        }
        .background(MenuAnchorProbe(handle: hostAnchor))
        .overlayPreferenceValue(PlaybackExcerptMenuAnchorKey.self) { anchor in
            destinationMenuOverlay(anchor: anchor)
        }
        .onChange(of: openMenu) { menu in
            measureDestinationMenu(menu)
        }
        .onDisappear {
            // A menu belongs to the surface that opened it: switching modules
            // or closing the surface takes the footer away, and the menu with
            // it.
            if openMenu != nil {
                playback.closeExcerptDestinationMenu()
            }
        }
        .interfaceLayer(surface.interfaceLayer)
        .accessibilityIdentifier("playback-cue-footer")
    }

    /// The destination menu, but only while it belongs to this footer: the
    /// Command Panel's footer and the Overlay's are both mounted when the panel
    /// is stacked above the Overlay.
    private var openMenu: PlaybackExcerptDestinationMenu? {
        guard let menu = playback.excerptDestinationMenu,
              menu.surface == surface
        else {
            return nil
        }
        return menu
    }

    @ViewBuilder
    private func destinationMenuOverlay(anchor: Anchor<CGRect>?) -> some View {
        if let menu = openMenu,
           let anchor,
           let naturalSize = menuSize,
           let windowBounds = hostAnchor.windowBounds {
            GeometryReader { proxy in
                let buttonFrame = proxy[anchor]
                let placement = destinationMenuPlacement(
                    naturalSize: naturalSize,
                    anchorFrame: buttonFrame,
                    bounds: menuBounds(
                        windowBounds: windowBounds,
                        footerHeight: proxy.size.height
                    )
                )
                let menuFrame = placement.frame

                ZStack(alignment: .topLeading) {
                    MenuGateClientView(
                        gate: playback.interfaceLayers.menuGate,
                        owner: surface.interfaceLayer,
                        kind: .excerptDestinationMenu,
                        menuFrame: menuFrame,
                        // A press on the button is left to the button, which
                        // closes the menu it opened.
                        anchorFrame: buttonFrame,
                        handleKey: { keyCode, isRepeat in
                            handleDestinationMenuKey(
                                keyCode,
                                isRepeat: isRepeat,
                                menu: menu
                            )
                        },
                        dismiss: { _ in
                            DispatchQueue.main.async {
                                playback.closeExcerptDestinationMenu()
                            }
                        }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)

                    ExcerptDestinationMenuSurfaceHost(
                        menu: ExcerptDestinationMenu(
                            destinations: menu.destinations,
                            highlight: playback.excerptDestinationMenuHighlight,
                            maximumHeight: placement.maximumHeight,
                            onSelect: { destination in
                                saveToDestination(destination, menu: menu)
                            },
                            onCreateList: {
                                createDestinationList(menu: menu)
                            }
                        )
                    )
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                }
                .zIndex(1)
            }
        }
    }

    /// The room the menu is placed in: the window above the footer. The footer
    /// is the last row of its surface, so there is nothing below it to open
    /// into, and the shared rule turns the menu upward on its own.
    private func menuBounds(
        windowBounds: CGRect,
        footerHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: windowBounds.minX,
            y: windowBounds.minY,
            width: windowBounds.width,
            height: max(0, footerHeight - windowBounds.minY)
        )
    }

    /// Where the menu sits and how tall it may be there. When the room above
    /// the footer is shorter than the menu wants, the menu is held to that room,
    /// which brings its scrollbar up and widens it, so the placement is taken
    /// again against the wider surface.
    private func destinationMenuPlacement(
        naturalSize: CGSize,
        anchorFrame: CGRect,
        bounds: CGRect
    ) -> (frame: CGRect, maximumHeight: CGFloat) {
        let frame = MenuPlacement.openingFrame(
            anchor: anchorFrame,
            menuSize: naturalSize,
            in: bounds,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: true
        )
        guard frame.height < naturalSize.height else {
            return (frame, MenuMetrics.maximumHeight)
        }
        return (
            MenuPlacement.openingFrame(
                anchor: anchorFrame,
                menuSize: CGSize(
                    width: menuScrollingWidth ?? naturalSize.width,
                    height: frame.height
                ),
                in: bounds,
                gap: WorkbenchControlMetrics.redesignSpacing1,
                shrinksToFit: true
            ),
            frame.height
        )
    }

    private func measureDestinationMenu(
        _ menu: PlaybackExcerptDestinationMenu?
    ) {
        guard let menu else {
            menuSize = nil
            menuScrollingWidth = nil
            return
        }
        menuSize = measuredDestinationMenuSize(
            menu,
            maximumHeight: MenuMetrics.maximumHeight
        )
        // Measured against no room at all, so the scrollbar is certainly up and
        // the width is the one a shortened menu ends up with.
        menuScrollingWidth = measuredDestinationMenuSize(
            menu,
            maximumHeight: 0
        ).width
    }

    private func measuredDestinationMenuSize(
        _ menu: PlaybackExcerptDestinationMenu,
        maximumHeight: CGFloat
    ) -> CGSize {
        let host = NSHostingView(
            rootView: ExcerptDestinationMenu(
                destinations: menu.destinations,
                highlight: playback.excerptDestinationMenuHighlight,
                maximumHeight: maximumHeight,
                onSelect: { _ in },
                onCreateList: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Arrows, Enter and Esc belong to the open menu; the surface under it must
    /// not respond to any of them. The Save to Excerpt key belongs to it too: a
    /// plain key stops at an open menu, so the key that opened this one has to
    /// close it from here rather than by reaching the footer again.
    private func handleDestinationMenuKey(
        _ keyCode: UInt16,
        isRepeat: Bool,
        menu: PlaybackExcerptDestinationMenu
    ) -> Bool {
        let saveToExcerptKeyCode = appState.settings.playbackShortcuts.keymap
            .effectiveKey(for: .saveToExcerpt)?
            .keyCode
        if keyCode == 53 || keyCode == saveToExcerptKeyCode {
            if !isRepeat {
                playback.closeExcerptDestinationMenu()
            }
            return true
        }
        switch keyCode {
        case 126:
            playback.excerptDestinationMenuHighlight.moveHighlight(by: -1)
            return true
        case 125:
            playback.excerptDestinationMenuHighlight.moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76:
            if !isRepeat,
               let position = playback.excerptDestinationMenuHighlight
                   .highlightedPosition {
                activateDestination(at: position, menu: menu)
            }
            return true
        default:
            return false
        }
    }

    private func activateDestination(
        at position: Int,
        menu: PlaybackExcerptDestinationMenu
    ) {
        if menu.destinations.indices.contains(position) {
            saveToDestination(menu.destinations[position], menu: menu)
        } else if position == menu.destinations.count {
            createDestinationList(menu: menu)
        }
    }

    private func saveToDestination(
        _ destination: SubtitleTableRowActionDestination,
        menu: PlaybackExcerptDestinationMenu
    ) {
        playback.closeExcerptDestinationMenu()
        appState.saveExcerpt(
            cueID: menu.cueID,
            toListID: destination.id,
            listName: destination.title,
            report: .playbackFeedback
        )
    }

    private func createDestinationList(menu: PlaybackExcerptDestinationMenu) {
        playback.closeExcerptDestinationMenu()
        appState.beginCreatingExcerptList(
            pendingTransfer: ExcerptListEditorPendingTransfer(
                action: .saveToExcerpt,
                target: .cue(menu.cueID),
                report: .playbackFeedback
            )
        )
    }
}

private struct PlaybackCueFooterActionButton: View {
    let surface: PlaybackCueFooterSurface
    let action: PlaybackCueFooterAction
    /// Observed so the keycaps follow a shortcut rebound in Settings.
    @ObservedObject var shortcuts: PlaybackShortcutStore
    /// The menu this button opened is up. It wears the same background it wears
    /// on hover for as long as that menu stays open.
    var isOpen = false

    @State private var isHovered = false

    private var isHighlighted: Bool {
        isHovered || isOpen
    }

    /// A shortcut that is cleared or in conflict shows no keycap: its key does
    /// nothing, so the button shows only its title.
    private var keycaps: [PlaybackCueFooterKeycap] {
        switch action.keys {
        case .returnKey:
            [.returnKey]
        case .shortcut(let shortcut):
            shortcuts.keymap.effectiveKey(for: shortcut)?.keycaps ?? []
        }
    }

    var body: some View {
        Button(action: action.perform) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                Text(action.title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .fixedSize(horizontal: true, vertical: false)

                ForEach(keycaps.indices, id: \.self) { index in
                    PlaybackCueFooterKeycapView(
                        keycap: keycaps[index],
                        background: isHighlighted
                            ? surface.keycapHoverBackground
                            : surface.keycapBackground
                    )
                }
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing2)
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing1)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignChipRadius,
                    style: .continuous
                )
                .fill(
                    isHighlighted
                        ? surface.buttonHoverBackground
                        : Color.clear
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
        .anchorPreference(
            key: PlaybackExcerptMenuAnchorKey.self,
            value: .bounds
        ) { anchor in
            action.opensExcerptDestinationMenu ? anchor : nil
        }
        .accessibilityIdentifier("playback-cue-footer-action-\(action.id)")
    }
}

/// Keycap: one key drawn as a label or an icon on its surface's keycap colour.
struct PlaybackCueFooterKeycapView: View {
    let keycap: PlaybackCueFooterKeycap
    let background: Color

    var body: some View {
        label
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: WorkbenchControlMetrics.redesignFontWeightControl
            ))
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignKeycapHorizontalPadding
            )
            .frame(minWidth: WorkbenchControlMetrics.redesignKeycapHeight)
            .frame(height: WorkbenchControlMetrics.redesignKeycapHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignKeycapRadius,
                    style: .continuous
                )
                .fill(background)
            }
    }

    @ViewBuilder
    private var label: some View {
        switch keycap {
        case .text(let text):
            Text(text)
        case .icon(let icon):
            AppIconImage(icon, size: WorkbenchControlMetrics.redesignKeycapIconSize)
        }
    }
}

/// Hosts the destination menu's SwiftUI surface in the menu hosting view, the
/// way every menu in the App is hosted. The menu's own scrolling sees the wheel
/// first, and whatever it does not spend stops there instead of reaching the
/// cue list underneath — a surface drawn straight into the footer's overlay has
/// no view of its own at the place it is drawn, so the list below owned that
/// wheel.
private struct ExcerptDestinationMenuSurfaceHost: NSViewRepresentable {
    let menu: ExcerptDestinationMenu

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
    }
}
