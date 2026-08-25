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
enum InterfaceLayer: Int, Comparable {
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
    /// Edit Cover and Shiori List Editor sheets. The in-page Confirmation
    /// dialog is not registered today: it blocks input with its own scrim.
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
    @Published private(set) var openLayers: Set<InterfaceLayer> = []
    /// Open menus counted by owning layer. A count rather than a flag: a
    /// right-click relay opens the next menu before the previous one has
    /// finished closing.
    @Published private(set) var openMenuCounts: [InterfaceLayer: Int] = [:]

    func setOpen(_ layer: InterfaceLayer, _ isOpen: Bool) {
        if isOpen {
            openLayers.insert(layer)
        } else {
            openLayers.remove(layer)
        }
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

private struct IsWorkbenchPageFrozenKey: EnvironmentKey {
    static let defaultValue = false
}

private struct IsPlaybackOverlayCoveredKey: EnvironmentKey {
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

    /// Whether the workbench page must keep its picture — covered, or a menu
    /// is open. Hover and selection highlights stop following the pointer.
    var isWorkbenchPageFrozen: Bool {
        get { self[IsWorkbenchPageFrozenKey.self] }
        set { self[IsWorkbenchPageFrozenKey.self] = newValue }
    }

    /// Whether the Command Panel is stacked above the Playback Overlay.
    var isPlaybackOverlayCovered: Bool {
        get { self[IsPlaybackOverlayCoveredKey.self] }
        set { self[IsPlaybackOverlayCoveredKey.self] = newValue }
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
                \.isWorkbenchPageFrozen,
                layers.isFrozen(.workbenchPage)
            )
            .environment(
                \.isPlaybackOverlayCovered,
                layers.isCovered(.playbackOverlay)
            )
    }
}
