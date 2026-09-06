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
            WorkbenchRedesignColors.playbackOverlayShortcutButtonHoverBg
        case .commandPanel:
            WorkbenchRedesignColors.commandPanelShortcutButtonHoverBg
        }
    }

    var keycapBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.playbackOverlayKeycapBg
        case .commandPanel:
            WorkbenchRedesignColors.commandPanelKeycapBg
        }
    }

    var keycapHoverBackground: Color {
        switch self {
        case .playbackOverlay:
            WorkbenchRedesignColors.playbackOverlayKeycapHoverBg
        case .commandPanel:
            WorkbenchRedesignColors.commandPanelKeycapHoverBg
        }
    }
}

enum PlaybackCueFooterKeycap: Equatable {
    case text(String)
    case systemImage(String)

    static let returnKey = Self.systemImage("return")
}

/// One footer action: what it says, which key does the same thing, and the
/// work itself. Clicking runs exactly what the shortcut runs.
struct PlaybackCueFooterAction: Identifiable {
    let id: String
    let title: String
    let keycap: PlaybackCueFooterKeycap
    /// Whether the action hangs the Shiori destination menu off its button
    /// rather than finishing on its own. The button then takes its Open
    /// appearance while the menu is up.
    var opensShioriDestinationMenu = false
    let perform: () -> Void

    /// The four cue actions shared by Current, the subtitle Playlist and the
    /// Command Panel's search results.
    static func cueActions(
        playTitle: String,
        request: @escaping (PlaybackSubtitleFocusAction) -> Void
    ) -> [Self] {
        [
            Self(
                id: "shiori",
                title: L("playback.save_to_shiori"),
                keycap: .text("S"),
                opensShioriDestinationMenu: true,
                perform: { request(.shiori) }
            ),
            Self(
                id: "copy-cue-text",
                title: L("row_menu.copy_cue_text"),
                keycap: .text("C"),
                perform: { request(.copyCueText) }
            ),
            Self(
                id: "copy-deep-link",
                title: L("row_menu.copy_deep_link"),
                keycap: .text("X"),
                perform: { request(.copyCueMarkdownLink) }
            ),
            Self(
                id: "play",
                title: playTitle,
                keycap: .returnKey,
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
        Self(id: id, title: title, keycap: .returnKey, perform: perform)
    }
}

enum PlaybackCueFooterStatus {
    static func cues(totalCount: Int) -> String {
        L("playback.cue_count", max(0, totalCount))
    }

    static func videos(totalCount: Int) -> String {
        L("playback.video_count", max(0, totalCount))
    }

    static func searchResults(
        totalCount: Int,
        previewLimit: Int,
        hasMoreResults: Bool
    ) -> String {
        let resolvedTotalCount = max(0, totalCount)
        let resolvedPreviewLimit = max(0, previewLimit)
        guard resolvedTotalCount > resolvedPreviewLimit || hasMoreResults else {
            return L("playback.result_count", resolvedTotalCount)
        }
        return L("playback.result_count", resolvedTotalCount) + " "
            + L("playback.result_preview_note", resolvedPreviewLimit)
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

/// The open `Save to Shiori` menu: the footer it hangs off, the cue it saves,
/// and the lists it offers. The lists are read once, when the menu opens;
/// creating one closes the menu, so the snapshot cannot go stale while it is up.
struct PlaybackShioriDestinationMenu: Equatable {
    let surface: PlaybackCueFooterSurface
    let cueID: Int64
    let destinations: [SubtitleTableRowActionDestination]
}

private struct PlaybackShioriMenuAnchorKey: PreferenceKey {
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

            PlaybackCueFooterActionFlow(
                horizontalSpacing: WorkbenchControlMetrics.redesignSpacing1,
                verticalSpacing: WorkbenchControlMetrics.redesignSpacing1
            ) {
                ForEach(actions) { action in
                    PlaybackCueFooterActionButton(
                        surface: surface,
                        action: action,
                        isOpen: action.opensShioriDestinationMenu
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
        .overlayPreferenceValue(PlaybackShioriMenuAnchorKey.self) { anchor in
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
                playback.closeShioriDestinationMenu()
            }
        }
        .interfaceLayer(surface.interfaceLayer)
        .accessibilityIdentifier("playback-cue-footer")
    }

    /// The destination menu, but only while it belongs to this footer: the
    /// Command Panel's footer and the Overlay's are both mounted when the panel
    /// is stacked above the Overlay.
    private var openMenu: PlaybackShioriDestinationMenu? {
        guard let menu = playback.shioriDestinationMenu,
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
                        kind: .shioriDestinationMenu,
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
                                playback.closeShioriDestinationMenu()
                            }
                        }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)

                    ShioriDestinationMenuSurfaceHost(
                        menu: ShioriDestinationMenu(
                            destinations: menu.destinations,
                            highlight: playback.shioriDestinationMenuHighlight,
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
        _ menu: PlaybackShioriDestinationMenu?
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
        _ menu: PlaybackShioriDestinationMenu,
        maximumHeight: CGFloat
    ) -> CGSize {
        let host = NSHostingView(
            rootView: ShioriDestinationMenu(
                destinations: menu.destinations,
                highlight: playback.shioriDestinationMenuHighlight,
                maximumHeight: maximumHeight,
                onSelect: { _ in },
                onCreateList: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Arrows, Enter and Esc belong to the open menu; the surface under it must
    /// not respond to any of them. `S` belongs to it too: a plain key stops at
    /// an open menu, so the key that opened this one has to close it from here
    /// rather than by reaching the footer again.
    private func handleDestinationMenuKey(
        _ keyCode: UInt16,
        isRepeat: Bool,
        menu: PlaybackShioriDestinationMenu
    ) -> Bool {
        switch keyCode {
        case 53, 1:
            if !isRepeat {
                playback.closeShioriDestinationMenu()
            }
            return true
        case 126:
            playback.shioriDestinationMenuHighlight.moveHighlight(by: -1)
            return true
        case 125:
            playback.shioriDestinationMenuHighlight.moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76:
            if !isRepeat,
               let position = playback.shioriDestinationMenuHighlight
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
        menu: PlaybackShioriDestinationMenu
    ) {
        if menu.destinations.indices.contains(position) {
            saveToDestination(menu.destinations[position], menu: menu)
        } else if position == menu.destinations.count {
            createDestinationList(menu: menu)
        }
    }

    private func saveToDestination(
        _ destination: SubtitleTableRowActionDestination,
        menu: PlaybackShioriDestinationMenu
    ) {
        playback.closeShioriDestinationMenu()
        appState.saveShiori(
            cueID: menu.cueID,
            toListID: destination.id,
            listName: destination.title,
            report: .playbackFeedback
        )
    }

    private func createDestinationList(menu: PlaybackShioriDestinationMenu) {
        playback.closeShioriDestinationMenu()
        appState.beginCreatingShioriList(
            pendingTransfer: ShioriListEditorPendingTransfer(
                action: .saveToShiori,
                target: .cue(menu.cueID),
                report: .playbackFeedback
            )
        )
    }
}

private struct PlaybackCueFooterActionButton: View {
    let surface: PlaybackCueFooterSurface
    let action: PlaybackCueFooterAction
    /// The menu this button opened is up. It wears the same background it wears
    /// on hover for as long as that menu stays open.
    var isOpen = false

    @State private var isHovered = false

    private var isHighlighted: Bool {
        isHovered || isOpen
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

                PlaybackCueFooterKeycapView(
                    keycap: action.keycap,
                    background: isHighlighted
                        ? surface.keycapHoverBackground
                        : surface.keycapBackground
                )
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
            key: PlaybackShioriMenuAnchorKey.self,
            value: .bounds
        ) { anchor in
            action.opensShioriDestinationMenu ? anchor : nil
        }
        .accessibilityIdentifier("playback-cue-footer-action-\(action.id)")
    }
}

private struct PlaybackCueFooterKeycapView: View {
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
        case .systemImage(let systemName):
            Image(systemName: systemName)
        }
    }
}

/// Right-aligned wrapping row. The actions keep their full width and move to
/// another line when the footer is too narrow, so nothing is ever shortened.
private struct PlaybackCueFooterActionFlow: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height }
            + verticalSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews: subviews) {
            var x = bounds.maxX - row.width
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = row.indices.isEmpty
                ? size.width
                : horizontalSpacing + size.width
            if !row.indices.isEmpty, row.width + advance > maxWidth {
                rows.append(row)
                row = Row()
                row.indices = [index]
                row.width = size.width
                row.height = size.height
            } else {
                row.indices.append(index)
                row.width += advance
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty {
            rows.append(row)
        }
        return rows
    }
}

/// Hosts the destination menu's SwiftUI surface in the menu hosting view, the
/// way every menu in the App is hosted. The menu's own scrolling sees the wheel
/// first, and whatever it does not spend stops there instead of reaching the
/// cue list underneath — a surface drawn straight into the footer's overlay has
/// no view of its own at the place it is drawn, so the list below owned that
/// wheel.
private struct ShioriDestinationMenuSurfaceHost: NSViewRepresentable {
    let menu: ShioriDestinationMenu

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
    }
}
