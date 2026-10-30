import AppKit
import CueSeekerCore
import SwiftUI

enum SubtitleTableRowActionMenuStyle {
    case search
    case excerpt
}

enum SubtitleTableProbeSurface: String, CaseIterable, Sendable {
    case search
    case excerpt

    init(tableName: String) {
        let normalizedName = tableName.lowercased()
        if normalizedName.contains("excerpt") {
            self = .excerpt
        } else {
            self = .search
        }
    }

    func counterName(_ event: String) -> String {
        "table.\(rawValue).\(event)"
    }
}

private enum RowActionMenuCoordinateSpace {
    static let name = "SubtitleTableRowActionMenu"
}

private struct RowActionMenuItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [SubtitleTableRowAction: CGRect] = [:]

    static func reduce(
        value: inout [SubtitleTableRowAction: CGRect],
        nextValue: () -> [SubtitleTableRowAction: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in
            newValue
        })
    }
}

struct RowActionMenu: View {
    var style: SubtitleTableRowActionMenuStyle = .search
    var showsCueGroup = false
    var canOpenFolder = true
    var disabledActions: Set<SubtitleTableRowAction> = []
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    @ObservedObject var submenuState: MenuSubmenuState<SubtitleTableRowAction>
    @ObservedObject var highlight: MenuHighlightModel
    var onAction: (SubtitleTableRowAction) -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            maximumHeight: maximumHeight,
            highlight: highlight
        ) {
            VStack(spacing: 0) {
                ForEach(Array(model.elements.enumerated()), id: \.offset) { position, element in
                    switch element {
                    case .divider:
                        WorkbenchMenuDivider()
                            .onHover { isHovered in
                                submenuState.noteItemHover(
                                    isHovered,
                                    at: position,
                                    trigger: nil,
                                    highlight: nil
                                )
                            }
                    case .action(let action):
                        actionRow(action, at: position)
                    }
                }
            }
        }
        .coordinateSpace(name: RowActionMenuCoordinateSpace.name)
        .onPreferenceChange(RowActionMenuItemFramePreferenceKey.self) {
            submenuState.updateParentItemFrames($0)
        }
    }

    private var model: SubtitleTableRowActionMenuModel {
        SubtitleTableRowActionMenuModel(style: style, showsCueGroup: showsCueGroup)
    }

    private func actionRow(
        _ action: SubtitleTableRowAction,
        at position: Int
    ) -> some View {
        let isSubmenuParent = action.opensDestinationSubmenu
        let isEnabled = model.isEnabled(
            action,
            disabledActions: disabledActions,
            canOpenFolder: canOpenFolder
        )
        return WorkbenchPopoverRow(
            title: action.title,
            isHighlighted: highlight.isSelected(position),
            isRowHovered: highlight.isHovered(position),
            isAccessibilityFocused: highlight.isAccessibilityFocused(position),
            icon: action.icon,
            iconWeight: action.iconWeight,
            showsCheckmarkSlot: false,
            isEnabled: isEnabled,
            isDestructive: action.isDestructive,
            action: {
                if isSubmenuParent {
                    highlight.selectPosition(position)
                    submenuState.open(action)
                } else {
                    submenuState.reset()
                    onAction(action)
                }
            },
            trailingIcon: isSubmenuParent ? .caretRight : nil,
            onHoverChange: { isHovered in
                submenuState.noteItemHover(
                    isHovered,
                    at: position,
                    trigger: isSubmenuParent && isEnabled ? action : nil,
                    highlight: highlight
                )
            }
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: RowActionMenuItemFramePreferenceKey.self,
                    value: [
                        action: proxy.frame(
                            in: .named(RowActionMenuCoordinateSpace.name)
                        ),
                    ]
                )
            }
        )
        .id(position)
    }
}

struct RowActionDestinationSubmenu: View {
    let destinations: [SubtitleTableRowActionDestination]
    @ObservedObject var submenuState: MenuSubmenuState<SubtitleTableRowAction>
    @ObservedObject var highlight: MenuHighlightModel
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    var onDestinationAction: (SubtitleTableRowActionDestination) -> Void
    var onCreateList: () -> Void

    var body: some View {
        ExcerptDestinationMenu(
            destinations: destinations,
            highlight: highlight,
            maximumHeight: maximumHeight,
            onSelect: onDestinationAction,
            onCreateList: onCreateList
        )
    }
}

enum CueStateTipGeometry {
    static let gap: CGFloat = TooltipGeometry.gap

    static func frame(
        anchor: CGRect,
        size: CGSize,
        visibleRect: CGRect
    ) -> CGRect {
        TooltipGeometry.frame(
            anchor: anchor,
            size: size,
            visibleRect: visibleRect
        )
    }
}

/// Holds the table's menus and cuts off whatever leaves the table body.
///
/// Its bounds are set to its frame, so a menu inside it is placed in the
/// container's coordinates like everything else the table positions.
final class SubtitleTableMenuClipView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Transparent itself, so a press that misses the menus keeps travelling.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

enum WorkbenchCheckboxDrawing {
    @MainActor
    static func draw(
        state: WorkbenchCheckboxState,
        isEnabled: Bool,
        in rect: CGRect,
        isFocused: Bool = false
    ) {
        WorkbenchCheckboxStyle.drawAppKitGlyph(
            for: state,
            isEnabled: isEnabled,
            size: SubtitleTableMetrics.checkboxSize,
            in: rect
        )

        guard isFocused else { return }
        let focusRect = rect.insetBy(
            dx: -WorkbenchControlMetrics.redesignFocusRingPathExpansion,
            dy: -WorkbenchControlMetrics.redesignFocusRingPathExpansion
        )
        let focusPath = NSBezierPath(ovalIn: focusRect)
        WorkbenchRedesignColors.NS.focusRing.setStroke()
        focusPath.lineWidth = WorkbenchControlMetrics.redesignFocusRingWidth
        focusPath.stroke()
    }
}

struct WorkbenchCheckboxButton: View {
    let state: WorkbenchCheckboxState
    var isEnabled: Bool = true
    var isFocused: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            WorkbenchCheckboxGlyph(
                state: state,
                isEnabled: isEnabled,
                size: SubtitleTableMetrics.checkboxSize
            )
            .overlay {
                if isFocused {
                    Circle()
                        .stroke(
                            WorkbenchRedesignColors.focusRing,
                            lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                        )
                        .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
    }
}
