import AppKit
import SwiftUI

/// One action the Selection Action Overlay offers: what it says, the key that
/// does the same thing, and the work itself. Clicking a button runs exactly
/// what its key runs.
struct SchemaWorkbenchSelectionAction: Identifiable {
    let id: String
    let title: String
    /// What the keycap shows. Letters, never a symbol.
    let keyLabel: String
    let keyCode: UInt16
    let perform: () -> Void

    /// The three export actions both workbench tables offer, in overlay order.
    /// Exit is not here: the overlay owns it, the same way it owns the count.
    static func exportActions(
        exportToAnki: @escaping () -> Void,
        copyDeepLinks: @escaping () -> Void,
        copyTable: @escaping () -> Void
    ) -> [Self] {
        [
            // A, D, T.
            Self(
                id: "anki",
                title: L("table.toolbar.anki"),
                keyLabel: "A",
                keyCode: 0,
                perform: exportToAnki
            ),
            Self(
                id: "copy-deep-links",
                title: L("table.toolbar.copy_deep_links"),
                keyLabel: "D",
                keyCode: 2,
                perform: copyDeepLinks
            ),
            Self(
                id: "copy-table",
                title: L("table.toolbar.copy_table"),
                keyLabel: "T",
                keyCode: 17,
                perform: copyTable
            ),
        ]
    }
}

struct SchemaWorkbenchSelectionActionOverlay: View {
    let selectedRowCount: Int
    let actions: [SchemaWorkbenchSelectionAction]
    let anchor: MenuAnchorHandle?
    let onExitSelectionMode: () -> Void

    @Environment(\.interfaceLayerContext) private var layerContext

    /// Exit closes Select Mode, the same thing the toolbar's Select Mode
    /// Action does when it is switched off.
    private var allActions: [SchemaWorkbenchSelectionAction] {
        actions + [
            SchemaWorkbenchSelectionAction(
                id: "exit",
                title: L("table.toolbar.exit"),
                keyLabel: "Esc",
                keyCode: 53,
                perform: onExitSelectionMode
            ),
        ]
    }

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            Text(schemaWorkbenchSelectedCountText(selectedRowCount))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                // The buttons are borderless, so their own padding is
                // invisible whitespace. The count is inset by the same amount
                // to keep both ends of the container equally clear.
                .padding(.leading, WorkbenchControlMetrics.redesignSpacing3)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                ForEach(allActions) { action in
                    SchemaWorkbenchSelectionActionButton(action: action)
                }
            }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3)
        .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
        // The shadow belongs to the overlay's shape, not to the overlay.
        // Applied to the whole surface it is cast by every leaf inside it, so
        // each action button and the count line carried a shadow of its own.
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgPopover)
            .shadowToken(
                WorkbenchRedesignColors.shadowPopover,
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderMuted, lineWidth: 1)
        )
        .background(anchor.map { MenuAnchorProbe(handle: $0) })
        .background(
            SchemaWorkbenchSelectionShortcutMonitor(
                actions: allActions,
                isEnabled: !layerContext.isFrozen
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
        )
    }
}

/// Text plus the key that does the same thing. Default and Hover only: the
/// press itself is not drawn, per `UI Application Rules` 按下.
private struct SchemaWorkbenchSelectionActionButton: View {
    let action: SchemaWorkbenchSelectionAction

    @State private var isHovered = false

    var body: some View {
        Button(action: action.perform) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text(action.title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                SchemaWorkbenchSelectionKeycap(
                    label: action.keyLabel,
                    background: isHovered
                        ? WorkbenchRedesignColors.popoverSurfaceKeycapHoverBg
                        : WorkbenchRedesignColors.popoverSurfaceKeycapBg
                )
            }
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3)
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing2)
            .background {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignChipRadius,
                    style: .continuous
                )
                .fill(
                    isHovered
                        ? WorkbenchRedesignColors.popoverSurfaceShortcutButtonHoverBg
                        : Color.clear
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
        .accessibilityIdentifier("workbench-selection-action-\(action.id)")
    }
}

private struct SchemaWorkbenchSelectionKeycap: View {
    let label: String
    let background: Color

    var body: some View {
        Text(label)
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
            .allowsHitTesting(false)
    }
}

/// The overlay's keys. It lives and dies with the overlay, which exists only
/// in Select Mode, so nothing else has to remember to switch it off.
///
/// The monitor answers only for its own window: a key pressed while the
/// Settings window — or any other window — is the key window belongs to that
/// window and is passed straight through.
private struct SchemaWorkbenchSelectionShortcutMonitor: NSViewRepresentable {
    let actions: [SchemaWorkbenchSelectionAction]
    let isEnabled: Bool

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(actions: actions, isEnabled: isEnabled)
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator _: Void) {
        nsView.tearDown()
    }

    @MainActor
    final class MonitoringView: NSView {
        nonisolated(unsafe) private var eventMonitor: Any?
        private var actions: [SchemaWorkbenchSelectionAction] = []
        private var isEnabled = false

        func update(
            actions: [SchemaWorkbenchSelectionAction],
            isEnabled: Bool
        ) {
            self.actions = actions
            self.isEnabled = isEnabled
            installEventMonitorIfNeeded()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                removeEventMonitor()
            } else {
                installEventMonitorIfNeeded()
            }
        }

        func tearDown() {
            actions = []
            removeEventMonitor()
        }

        @discardableResult
        func handleForTesting(_ event: NSEvent) -> Bool {
            handle(event)
        }

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }

        private func installEventMonitorIfNeeded() {
            guard window != nil, eventMonitor == nil else {
                return
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown
            ) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    self?.handle(event) ?? false
                }
                return handled ? nil : event
            }
        }

        private func removeEventMonitor() {
            guard let eventMonitor else {
                return
            }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        /// Returns whether the key was spent here, in which case nothing
        /// below sees it.
        private func handle(_ event: NSEvent) -> Bool {
            guard isEnabled,
                  event.window === window,
                  event.modifierFlags
                  .intersection([.command, .control, .option, .shift])
                  .isEmpty,
                  !AppCoordinator.isEditableTextInputFocused(),
                  let action = actions.first(where: { $0.keyCode == event.keyCode })
            else {
                return false
            }
            if !event.isARepeat {
                action.perform()
            }
            return true
        }
    }
}
