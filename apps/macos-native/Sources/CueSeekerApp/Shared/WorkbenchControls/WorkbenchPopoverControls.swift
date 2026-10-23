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
        .background(
            GeometryReader { proxy in
                let rowFrame = proxy.frame(in: .named("WorkbenchPopoverPanelProbeSpace"))
                Color.clear
                    .onAppear {
                        MenuJitterProbe.logIfChanged(
                            key: "PopoverRow.\(title)",
                            category: "PopoverRow",
                            value: "frame=\(MenuJitterProbe.fmt(rowFrame))"
                        )
                    }
                    .onChange(of: rowFrame) { newFrame in
                        MenuJitterProbe.logIfChanged(
                            key: "PopoverRow.\(title)",
                            category: "PopoverRow",
                            value: "frame=\(MenuJitterProbe.fmt(newFrame))"
                        )
                    }
            }
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
            .coordinateSpace(name: "WorkbenchPopoverPanelProbeSpace")
            .background(
                GeometryReader { panelGeo in
                    let panelSize = panelGeo.size
                    let globalFrame = panelGeo.frame(in: .global)
                    Color.clear
                        .onAppear {
                            MenuJitterProbe.logIfChanged(
                                key: "PopoverPanel.geometry",
                                category: "PopoverPanel",
                                value: "size=\(MenuJitterProbe.fmt(panelSize)) global=\(MenuJitterProbe.fmt(globalFrame))"
                            )
                        }
                        .onChange(of: globalFrame) { newGlobal in
                            MenuJitterProbe.logIfChanged(
                                key: "PopoverPanel.geometry",
                                category: "PopoverPanel",
                                value: "size=\(MenuJitterProbe.fmt(panelGeo.size)) global=\(MenuJitterProbe.fmt(newGlobal))"
                            )
                        }
                }
            )
            // The item highlighted when the menu opens can already be out of
            // reach — `Save to Excerpt` opens on the list saved to most
            // recently — so opening reveals it the same way a keyboard move
            // does. The wheel and the scrollbar bump neither signal, so they
            // never pull the menu back to the highlight.
            .onAppear {
                MenuJitterProbe.log(
                    "PopoverPanel",
                    "onAppear revealHighlight highlightedPosition=\(String(describing: highlight.highlightedPosition)) maxH=\(String(format: "%.2f", maximumHeight))"
                )
                revealHighlight(proxy)
            }
            .onChange(of: highlight.keyboardMoveCount) { moveCount in
                MenuJitterProbe.log(
                    "PopoverPanel",
                    "onChange(keyboardMoveCount=\(moveCount)) -> scrollTo(\(String(describing: highlight.highlightedPosition))) contentH=\(String(format: "%.2f", contentHeight)) maxH=\(String(format: "%.2f", maximumHeight))"
                )
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
    let anchorFrame: CGRect
    let menuFrame: CGRect
    let items: [WorkbenchCardMenuItem]
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
