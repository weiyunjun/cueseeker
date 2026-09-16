import AppKit
import SwiftUI

/// The main window's stacked interface layers, lowest first, following the
/// layer list in `docs/human/design/UI Application Rules.md` (界面层级).
///
/// The workbench page is the base everything else stacks on, so it is never
/// registered; it counts as always open. The playback page is routed over the
/// whole workbench, which is how "one page covers another" exists at all: while
/// it is open every workbench surface is covered, and the playback overlays
/// stack above it in the order the design lists.
///
/// Menus are deliberately not a case. A menu belongs to the layer that opened
/// it and sits only above that layer, so the registry records open menus by
/// their owning layer instead of ranking them.
///
/// The Settings window and the system menu bar are separate windows and are
/// not part of this list.
enum InterfaceLayer: Int, CaseIterable, Comparable {
    /// 工作台页面 — the base.
    case workbenchPage
    /// 播放页视频与控制条, routed over the whole workbench.
    case playbackPage
    /// Playback Overlay and its same-layer modules (Current, Playlist,
    /// Collage Editor). The workbench Selection Action Overlay is not
    /// registered today: no coverage question is asked about it.
    case playbackOverlay
    /// Command Panel, above the Playback Overlay.
    case commandPanel
    /// Whatever the dialog layer inside the main window is drawing: Edit
    /// Cover, the Excerpt List Editor, Rename, Filter, Export to Anki, the
    /// Task panel and Confirmation. The layer registers itself from its own
    /// list of open dialogs, so a dialog added to the layer is registered with
    /// it. A Confirmation may stack on another dialog, and the layer stays open
    /// until the last of them closes.
    case dialog

    static func < (lhs: InterfaceLayer, rhs: InterfaceLayer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The one place that answers "is this layer covered" and "must this layer
/// keep its picture". Each layer's open state stays with the module that owns
/// it; the module reports transitions here, and every surface that used to
/// keep a coverage flag of its own asks this registry instead.
@MainActor
final class InterfaceLayerRegistry: ObservableObject {
    /// The one menu event implementation. It lives on the registry because
    /// every place that reports or asks about layers is also where menus are
    /// opened, so the existing plumbing reaches both.
    private(set) lazy var menuGate = MenuGate(interfaceLayers: self)

    @Published private(set) var openLayers: Set<InterfaceLayer> = []
    /// Open menus counted by owning layer. A count rather than a flag: a
    /// right-click relay opens the next menu before the previous one has
    /// finished closing.
    @Published private(set) var openMenuCounts: [InterfaceLayer: Int] = [:]
    /// The size of the dialog that owns input, or nil while no dialog is open.
    /// Dialogs are centred in the main window, so this is where it keeps the
    /// keyboard.
    var topDialogSize: CGSize?
    /// Whether a system sheet — a file panel, or Export to Anki's replace
    /// warning — is attached to the main window.
    /// The system dims the whole window under it, so the dialog layer's own
    /// veil steps aside rather than dimming the page twice.
    @Published private(set) var isSystemSheetAttached = false

    func setSystemSheetAttached(_ isAttached: Bool) {
        guard isSystemSheetAttached != isAttached else {
            return
        }
        isSystemSheetAttached = isAttached
    }

    func setOpen(_ layer: InterfaceLayer, _ isOpen: Bool) {
        guard openLayers.contains(layer) != isOpen else {
            return
        }
        if isOpen {
            openLayers.insert(layer)
            if layer == .dialog {
                givePageFocusUp()
            }
        } else {
            openLayers.remove(layer)
            if layer == .dialog {
                topDialogSize = nil
            }
        }
        // Entering or leaving a layer is an interface switch: the pointer goes
        // back to the arrow until it moves again.
        AppPointerShape.reset()
    }

    /// The page gives its focus up as a dialog opens, the way it does for a
    /// menu, so nothing it had focused comes back when the dialog closes. A
    /// field giving its focus up redraws the window at once, and this runs
    /// while the window is still drawing the dialog in: given up here, that
    /// redraw could read a stale state. So the focus is given up on the next
    /// turn, and only while the page still holds it: a dialog that focused its
    /// own field on appearing keeps it.
    private func givePageFocusUp() {
        guard let window = NSApplication.shared.keyWindow,
              let pageFocus = Self.focusOwner(in: window)
        else {
            return
        }
        Task { @MainActor in
            guard Self.focusOwner(in: window) === pageFocus else {
                return
            }
            window.makeFirstResponder(nil)
        }
    }

    /// The control that holds the window's keyboard, or nil when nothing does.
    /// Every text field in a window edits through the one field editor, so
    /// the field it is editing answers for it.
    private static func focusOwner(in window: NSWindow) -> NSResponder? {
        guard let responder = window.firstResponder, responder !== window else {
            return nil
        }
        if let editor = responder as? NSTextView,
           editor.isFieldEditor,
           let field = editor.delegate as? NSResponder {
            return field
        }
        return responder
    }

    /// Registers an open menu. The owner holds the token while its menu is
    /// open; releasing it — on dismissal, or by being torn down with the menu
    /// still open — takes the menu out of the registry, so no teardown path
    /// can leave a menu registered forever.
    func registerOpenMenu(ownedBy owner: InterfaceLayer) -> OpenMenuToken {
        openMenuCounts[owner, default: 0] += 1
        return OpenMenuToken(registry: self, owner: owner)
    }

    fileprivate func menuDidClose(ownedBy owner: InterfaceLayer) {
        guard let count = openMenuCounts[owner] else {
            return
        }
        if count <= 1 {
            openMenuCounts[owner] = nil
        } else {
            openMenuCounts[owner] = count - 1
        }
    }

    func isOpen(_ layer: InterfaceLayer) -> Bool {
        layer == .workbenchPage || openLayers.contains(layer)
    }

    /// Whether a higher layer is open above `layer`. Menus do not count here:
    /// a menu covers no layer, it only freezes the content of its own.
    func isCovered(_ layer: InterfaceLayer) -> Bool {
        openLayers.contains { $0 > layer }
    }

    /// Whether `layer` must keep the picture it had: a higher layer covers it,
    /// or a menu is open at or above it. A frozen surface keeps its current
    /// item, highlight and selection, and stops following the pointer.
    func isFrozen(_ layer: InterfaceLayer) -> Bool {
        isCovered(layer) || openMenuCounts.keys.contains { $0 >= layer }
    }

    /// Every layer that must keep its picture, so a surface can ask about the
    /// layer it is on rather than about the page underneath it. The same card
    /// grid appears on the workbench page, in the Command Panel and in the
    /// Playback Overlay, and each of those must answer for itself.
    var frozenLayers: Set<InterfaceLayer> {
        Set(InterfaceLayer.allCases.filter(isFrozen))
    }

    /// Every layer something else owns input above, answered the same way.
    var coveredLayers: Set<InterfaceLayer> {
        Set(InterfaceLayer.allCases.filter(isCovered))
    }

    /// Whether a menu that nothing covers is open. The main window's focus
    /// barrier asks this: while such a menu owns input, nothing underneath may
    /// take the keyboard back.
    var hasUncoveredOpenMenu: Bool {
        openMenuCounts.keys.contains { !isCovered($0) }
    }

    /// Whether a menu owned by `owner` is covered. A menu sits only above its
    /// own layer, so whatever covers that layer covers the menu with it.
    func isMenuCovered(ownedBy owner: InterfaceLayer) -> Bool {
        isCovered(owner)
    }

    /// See `registerOpenMenu(ownedBy:)`.
    final class OpenMenuToken {
        nonisolated(unsafe) private weak var registry: InterfaceLayerRegistry?
        private let owner: InterfaceLayer

        fileprivate init(registry: InterfaceLayerRegistry, owner: InterfaceLayer) {
            self.registry = registry
            self.owner = owner
        }

        deinit {
            // Menu owners live on the main actor, so the token is released
            // there too.
            let registry = registry
            let owner = owner
            MainActor.assumeIsolated {
                registry?.menuDidClose(ownedBy: owner)
            }
        }
    }
}

private struct InterfaceLayersKey: EnvironmentKey {
    static let defaultValue: InterfaceLayerRegistry? = nil
}

private struct IsWorkbenchPageCoveredKey: EnvironmentKey {
    static let defaultValue = false
}

private struct InterfaceLayerContextKey: EnvironmentKey {
    static let defaultValue = InterfaceLayerContext()
}

private struct IsPlaybackOverlayCoveredKey: EnvironmentKey {
    static let defaultValue = false
}

private struct IsDialogOpenKey: EnvironmentKey {
    static let defaultValue = false
}

private struct IsSystemSheetAttachedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The registry, for surfaces that report menu transitions or need a
    /// direct answer. nil in hierarchies outside the main window.
    var interfaceLayers: InterfaceLayerRegistry? {
        get { self[InterfaceLayersKey.self] }
        set { self[InterfaceLayersKey.self] = newValue }
    }

    /// Whether something above the workbench page owns input — the playback
    /// page or a dialog. Cursor effects, menu-open triggers and external text
    /// selection stop while covered.
    var isWorkbenchPageCovered: Bool {
        get { self[IsWorkbenchPageCoveredKey.self] }
        set { self[IsWorkbenchPageCoveredKey.self] = newValue }
    }

    /// Which layer this subtree is on, and which layers must keep their
    /// picture. Ask it whether the surface reading it is frozen.
    var interfaceLayerContext: InterfaceLayerContext {
        get { self[InterfaceLayerContextKey.self] }
        set { self[InterfaceLayerContextKey.self] = newValue }
    }

    /// Whether the Command Panel is stacked above the Playback Overlay.
    var isPlaybackOverlayCovered: Bool {
        get { self[IsPlaybackOverlayCoveredKey.self] }
        set { self[IsPlaybackOverlayCoveredKey.self] = newValue }
    }

    /// Whether a dialog is open. The player reads it as the loss of its focus,
    /// which a dialog in its own window used to take from the main window.
    var isDialogOpen: Bool {
        get { self[IsDialogOpenKey.self] }
        set { self[IsDialogOpenKey.self] = newValue }
    }

    /// See `InterfaceLayerRegistry.isSystemSheetAttached`.
    var isSystemSheetAttached: Bool {
        get { self[IsSystemSheetAttachedKey.self] }
        set { self[IsSystemSheetAttachedKey.self] = newValue }
    }
}

/// Publishes the registry's answers as plain environment values, so consumers
/// re-render only when an answer actually changes rather than on every
/// registry write.
struct InterfaceLayerCoverageBridge: ViewModifier {
    @ObservedObject var layers: InterfaceLayerRegistry

    func body(content: Content) -> some View {
        content
            .environment(\.interfaceLayers, layers)
            .environment(
                \.isWorkbenchPageCovered,
                layers.isCovered(.workbenchPage)
            )
            .environment(
                \.interfaceLayerContext,
                InterfaceLayerContext(
                    coveredLayers: layers.coveredLayers,
                    frozenLayers: layers.frozenLayers
                )
            )
            .environment(
                \.isPlaybackOverlayCovered,
                layers.isCovered(.playbackOverlay)
            )
            .environment(\.isDialogOpen, layers.isOpen(.dialog))
            .environment(\.isSystemSheetAttached, layers.isSystemSheetAttached)
    }
}


/// The freeze question answered from where the surface actually is.
///
/// A card grid is reused above the page it was written for: the Command Panel
/// and the Playback Overlay both show one. Asking the workbench page's answer
/// there reads back "frozen" the moment those layers open, which is exactly
/// when their own cards are the ones the reader is pointing at.
struct InterfaceLayerContext: Equatable {
    var layer: InterfaceLayer = .workbenchPage
    var coveredLayers: Set<InterfaceLayer> = []
    var frozenLayers: Set<InterfaceLayer> = []

    /// Whether something above the surface reading this owns input. Its own
    /// menus and pointer interactions stop while covered.
    var isCovered: Bool {
        coveredLayers.contains(layer)
    }

    /// Whether the surface reading this must keep the picture it had.
    var isFrozen: Bool {
        frozenLayers.contains(layer)
    }
}

extension View {
    /// Says which layer everything inside belongs to. A layer that hosts
    /// content written for the page below it must claim it.
    func interfaceLayer(_ layer: InterfaceLayer) -> some View {
        modifier(InterfaceLayerModifier(layer: layer))
    }
}

/// The one way to hand main-window content to a separately hosted
/// `NSHostingView`.
///
/// The SwiftUI environment stops at a hosting boundary, so content given to
/// its own hosting view reads a nil registry and a default layer context that
/// is never frozen — its hover gates go silently blind. Every non-menu host
/// wraps its root view here, and content added to a hosted surface later
/// inherits the freeze without anyone remembering to wire it.
///
/// Menu surfaces are the deliberate exception and must not be bridged: a menu
/// belongs to the layer it freezes, so bridging would freeze the menu's own
/// rows and scrollbar together with the page below it.
@MainActor
enum InterfaceLayerHosting {
    static func bridgedRootView(
        _ view: AnyView,
        layers: InterfaceLayerRegistry?,
        context: InterfaceLayerContext
    ) -> AnyView {
        AnyView(
            view
                .environment(\.interfaceLayers, layers)
                .environment(\.interfaceLayerContext, context)
        )
    }
}

private struct InterfaceLayerModifier: ViewModifier {
    let layer: InterfaceLayer
    @Environment(\.interfaceLayerContext) private var context

    func body(content: Content) -> some View {
        content.environment(
            \.interfaceLayerContext,
            InterfaceLayerContext(
                layer: layer,
                coveredLayers: context.coveredLayers,
                frozenLayers: context.frozenLayers
            )
        )
    }
}
