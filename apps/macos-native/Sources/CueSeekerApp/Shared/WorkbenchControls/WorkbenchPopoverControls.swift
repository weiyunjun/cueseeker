import AppKit
import SwiftUI

struct WorkbenchPopoverRow: View {
    let title: String
    var isSelected = false
    var isHighlighted = false
    var isRowHovered = false
    var icon: AppIcon?
    var iconWeight: AppIconWeight?
    var showsCheckmarkSlot = true
    var isEnabled = true
    var isDestructive = false
    var action: (() -> Void)? = nil
    var trailingIcon: AppIcon?
    var onHoverChange: ((Bool) -> Void)?
    @State private var isHovered = false

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(StaticButtonStyle())
            .disabled(!isEnabled)
            .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
            .focusable(false)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if showsCheckmarkSlot {
                if isSelected {
                    AppIconImage(.check, size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
                        .frame(width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS, height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
                        .foregroundStyle(iconColor)
                } else {
                    Color.clear
                        .frame(width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS, height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
                }
            }

            // Every menu glyph is drawn in the same square box, so the slot is
            // that box: a wider slot would only widen the gap before the label.
            if let icon {
                AppIconImage(
                    icon,
                    size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS,
                    weight: iconWeight
                )
                    .foregroundStyle(iconColor)
                    .frame(
                        width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS,
                        height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                    )
            }

            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTable, weight: .regular))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            if let trailingIcon {
                AppIconImage(
                    trailingIcon,
                    size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                )
                    .foregroundStyle(iconColor)
                    // No fixed width: a lone trailing glyph centred in a
                    // wider slot would leave the space after it reading wider
                    // than the space before the leading icon.
                    .frame(height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
            }
        }
        .foregroundStyle(labelColor)
        .padding(.leading, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
        .padding(.trailing, redesignTrailingPadding)
        .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                style: .continuous
            )
            .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            onHoverChange?(inside)
            isHovered = isEnabled && inside
        }
    }

    /// A trailing icon sits closer to the edge than trailing text does, so the
    /// two sides of the row read as equally spaced.
    private var redesignTrailingPadding: CGFloat {
        trailingIcon == nil
            ? WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
            : WorkbenchControlMetrics.redesignMenuItemTrailingIconPadding
    }

    private var rowBackground: Color {
        guard isEnabled else { return .clear }
        if isHighlighted || isRowHovered {
            return isDestructive
                ? WorkbenchRedesignColors.dangerBgHover
                : WorkbenchRedesignColors.bgHover
        }
        return .clear
    }

    private var labelColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return isDestructive
            ? WorkbenchRedesignColors.dangerText
            : WorkbenchRedesignColors.textPrimary
    }

    private var iconColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return isDestructive
            ? WorkbenchRedesignColors.dangerText
            : WorkbenchRedesignColors.textPrimary
    }
}

/// Menu Divider.
///
/// Its ends line up with where the items' content starts, and it keeps room
/// above and below itself, so it reads as a break between two groups rather
/// than as an underline belonging to the row above it.
///
/// The inset is written as the distance from the menu's edge and then given
/// back the menu's padding, because the divider is laid out inside the item
/// stack, which that padding has already moved in.
struct WorkbenchMenuDivider: View {
    var body: some View {
        Divider()
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignMenuDividerInset - MenuMetrics.padding
            )
            .padding(.vertical, WorkbenchControlMetrics.redesignMenuDividerGap)
    }
}

/// The surface a menu is drawn on. Player Chrome menus sit over the video and
/// keep the Player Speed Menu's look.
enum MenuSurface {
    case workbench
    case playerChrome
}

struct WorkbenchPopoverPanel<Content: View>: View {
    var surface = MenuSurface.workbench
    /// How tall the panel may grow. It is the menu's own cap by default; a menu
    /// that opened on a side with less room than that is given the room it has,
    /// and scrolls whatever no longer fits.
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    /// The open menu's highlight. Keeping the highlighted item visible belongs
    /// to the surface every menu shares, not to each menu: a menu that grows
    /// past the cap then reveals its highlight without doing anything itself,
    /// and a menu that never scrolls is unaffected. Items must carry `.id` of
    /// their own position for the reveal to find them.
    @ObservedObject var highlight: MenuHighlightModel
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    @State private var contentHeight: CGFloat = .infinity

    var body: some View {
        let isPlayerChrome = surface == .playerChrome
        let cornerRadius: CGFloat = WorkbenchControlMetrics.redesignMenuRadius
        // The scroll view spans the whole panel, and the item stack inside it
        // both applies the menu's padding and reserves the strip the scrollbar
        // needs — but only once the items outgrow the cap, so a menu that does
        // not scroll spends nothing on a scrollbar that never appears. The cap
        // makes the menu its items' own height until they pass it; width stays
        // whatever the items need, plus that strip when it is reserved.
        ScrollViewReader { proxy in
            MenuHeightCap(height: maximumHeight) {
                WorkbenchScrollView(
                    scrollbarInset: MenuMetrics.scrollbarOuterGap
                ) {
                    MenuItemStack(
                        padding: MenuMetrics.padding,
                        strip: MenuMetrics.scrollbarStrip,
                        cap: maximumHeight
                    ) {
                        content()
                    }
                    .background(
                        GeometryReader { contentGeo in
                            Color.clear
                                .onAppear {
                                    contentHeight = contentGeo.size.height
                                }
                                .onChange(of: contentGeo.size.height) { newHeight in
                                    contentHeight = newHeight
                                }
                        }
                    )
                }
            }
            .environment(\.colorScheme, isPlayerChrome ? .dark : colorScheme)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                Group {
                    if isPlayerChrome {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(PlaybackTheme.menuBackground)
                            .shadow(
                                color: PlaybackTheme.overlayShadowColor,
                                radius: PlaybackTheme.overlayShadowRadius,
                                y: PlaybackTheme.overlayShadowYOffset
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(WorkbenchRedesignColors.bgPopover)
                            .shadowToken(
                                WorkbenchRedesignColors.shadowPopover,
                                cornerRadius: cornerRadius
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isPlayerChrome
                            ? PlaybackTheme.textTertiary.opacity(0.3)
                            : WorkbenchRedesignColors.borderControl,
                        lineWidth: 1.0
                    )
            )
            .subtitleTableTextSelectionNonInteractiveRegion(
                cornerRadius: cornerRadius
            )
            // The item highlighted when the menu opens can already be out of
            // reach — `Save to Excerpt` opens on the list saved to most
            // recently — so opening reveals it the same way a keyboard move
            // does. The wheel and the scrollbar bump neither signal, so they
            // never pull the menu back to the highlight.
            .onAppear {
                revealHighlight(proxy)
            }
            .onChange(of: highlight.keyboardMoveCount) { _ in
                revealHighlight(proxy)
            }
        }
    }

    /// Scrolls the least amount that makes the highlighted item whole, without
    /// animating: the menu is already open and the item has to be there now.
    private func revealHighlight(_ proxy: ScrollViewProxy) {
        guard contentHeight > floor(maximumHeight),
              let position = highlight.highlightedPosition
        else {
            return
        }
        proxy.scrollTo(position)
    }
}

public struct WorkbenchDropdownAnchorPreferenceKey: PreferenceKey {
    public typealias Value = [String: CGRect]
    public static var defaultValue: Value { [:] }
    public static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    public func workbenchDropdownAnchor(id: String, in spaceName: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: WorkbenchDropdownAnchorPreferenceKey.self,
                        value: [id: geo.frame(in: .named(spaceName))]
                    )
            }
        )
    }
}

struct WorkbenchCardMenuItem: Identifiable, Sendable {
    let title: String
    let icon: AppIcon
    var isEnabled: Bool = true
    var isDestructive: Bool = false
    let action: @MainActor @Sendable () -> Void

    var id: String {
        title
    }
}

struct WorkbenchCardMenuState: Identifiable {
    let id = UUID()
    let cardID: String
    let anchorFrame: CGRect?
    let menuFrame: CGRect
    let items: [WorkbenchCardMenuItem]

    var isButtonAnchored: Bool {
        anchorFrame != nil
    }
}

struct WorkbenchCardRightClickMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let menuGate: MenuGate?
    let onRightClick: (CGPoint) -> Void

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(
            isEnabled: isEnabled,
            menuGate: menuGate,
            onRightClick: onRightClick
        )
    }

    final class MonitoringView: NSView {
        nonisolated(unsafe) private var monitor: Any?
        private var isEnabled = false
        private weak var menuGate: MenuGate?
        private var onRightClick: ((CGPoint) -> Void)?

        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        func update(
            isEnabled: Bool,
            menuGate: MenuGate?,
            onRightClick: @escaping (CGPoint) -> Void
        ) {
            self.isEnabled = isEnabled
            self.menuGate = menuGate
            self.onRightClick = onRightClick
            updateMonitor()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func updateMonitor() {
            guard isEnabled, window != nil else {
                removeMonitor()
                return
            }
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
                guard let self else {
                    return event
                }
                guard event.window === self.window else {
                    return event
                }

                let localPoint = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.intersection(self.visibleRect).contains(localPoint) else {
                    return event
                }

                if let menuGate = self.menuGate {
                    guard menuGate.route(event) != nil else {
                        return nil
                    }
                }

                self.onRightClick?(localPoint)
                return nil
            }
        }

        private func removeMonitor() {
            guard let monitor else {
                return
            }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

struct WorkbenchCardMenuPopover: View {
    let items: [WorkbenchCardMenuItem]
    @ObservedObject var highlight: MenuHighlightModel
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        icon: item.icon,
                        showsCheckmarkSlot: false,
                        isEnabled: item.isEnabled,
                        isDestructive: item.isDestructive,
                        action: {
                            onDismiss()
                            item.action()
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .frame(minWidth: 160, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
