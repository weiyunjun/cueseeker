import Foundation
import SwiftUI

extension Notification.Name {
    static let cueSeekerScrollDebounceSettled = Notification.Name(
        "CueSeekerScrollDebounceSettled"
    )
}

/// Coordinates the 300ms scroll-end debounce and cursor visibility state for
/// pointer hover and pointer shape updates across the App.
@MainActor
final class PointerHoverScrollState: ObservableObject {
    static let shared = PointerHoverScrollState()
    static let debounceNanoseconds: UInt64 = 300_000_000

    @Published private(set) var isScrolling = false
    @Published private(set) var isCursorHidden = false
    private var debounceTask: Task<Void, Never>?

    func noteScrolled() {
        if !isScrolling {
            isScrolling = true
        }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            self?.settleScroll()
        }
    }

    func notePointerMoved() {
        debounceTask?.cancel()
        debounceTask = nil
        if isScrolling {
            isScrolling = false
        }
    }

    func cancelScrollDebounceForWindowResign() {
        debounceTask?.cancel()
        debounceTask = nil
        if isScrolling {
            isScrolling = false
        }
    }

    func settleScroll() {
        debounceTask?.cancel()
        debounceTask = nil
        if isScrolling {
            isScrolling = false
        }
        CardHighlightModel.broadcastScrollSettled()
        MenuHighlightModel.broadcastScrollSettled()
        AppPointerShape.noteScrollSettled()
        NotificationCenter.default.post(
            name: .cueSeekerScrollDebounceSettled,
            object: nil
        )
    }

    func noteCursorHiddenChanged(_ isHidden: Bool) {
        if isCursorHidden != isHidden {
            isCursorHidden = isHidden
        }
    }

    func resetForTesting() {
        debounceTask?.cancel()
        debounceTask = nil
        isScrolling = false
        isCursorHidden = AppCursorVisibility.isCursorHidden
    }
}

/// Hover for a visual effect, reported only while the surface's layer owns
/// input, the cursor is visible, and scroll debounce is not active.
extension View {
    func onPointerHover(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(PointerHoverModifier(action: action))
    }
}

/// The delivery rule, kept out of the view so it can be pinned by tests.
struct PointerHoverGate: Equatable {
    /// What the pointer last did, whether or not the surface was allowed to
    /// answer it.
    private var reportedIsHovered = false
    /// What the surface was last told, which is what it is painting.
    private var deliveredIsHovered = false

    /// Records what the pointer did and returns what the surface should be
    /// told, or nil when it should be told nothing.
    mutating func report(
        _ isHovered: Bool,
        isFrozen: Bool,
        isScrolling: Bool = false,
        isCursorHidden: Bool = false
    ) -> Bool? {
        reportedIsHovered = isHovered
        return delivery(
            isFrozen: isFrozen,
            isScrolling: isScrolling,
            isCursorHidden: isCursorHidden
        )
    }

    /// Returns what the surface should be told now that the freeze, scroll, or
    /// cursor visibility state changed.
    mutating func freezeChanged(
        isFrozen: Bool,
        isScrolling: Bool = false,
        isCursorHidden: Bool = false
    ) -> Bool? {
        delivery(
            isFrozen: isFrozen,
            isScrolling: isScrolling,
            isCursorHidden: isCursorHidden
        )
    }

    private mutating func delivery(
        isFrozen: Bool,
        isScrolling: Bool,
        isCursorHidden: Bool
    ) -> Bool? {
        if isCursorHidden {
            guard deliveredIsHovered else {
                return nil
            }
            deliveredIsHovered = false
            return false
        }
        guard !isFrozen, !isScrolling else {
            return nil
        }
        guard deliveredIsHovered != reportedIsHovered else {
            return nil
        }
        deliveredIsHovered = reportedIsHovered
        return reportedIsHovered
    }
}

private struct PointerHoverModifier: ViewModifier {
    let action: (Bool) -> Void
    @Environment(\.interfaceLayerContext) private var layerContext
    @ObservedObject private var scrollState = PointerHoverScrollState.shared
    @State private var gate = PointerHoverGate()

    func body(content: Content) -> some View {
        content
            .onHover { isHovered in
                if let delivered = gate.report(
                    isHovered,
                    isFrozen: layerContext.isFrozen,
                    isScrolling: scrollState.isScrolling,
                    isCursorHidden: AppCursorVisibility.isCursorHidden
                ) {
                    action(delivered)
                }
            }
            .onChange(of: layerContext.isFrozen) { isFrozen in
                if let delivered = gate.freezeChanged(
                    isFrozen: isFrozen,
                    isScrolling: scrollState.isScrolling,
                    isCursorHidden: AppCursorVisibility.isCursorHidden
                ) {
                    action(delivered)
                }
            }
            .onChange(of: scrollState.isScrolling) { isScrolling in
                if let delivered = gate.freezeChanged(
                    isFrozen: layerContext.isFrozen,
                    isScrolling: isScrolling,
                    isCursorHidden: AppCursorVisibility.isCursorHidden
                ) {
                    action(delivered)
                }
            }
            .onChange(of: scrollState.isCursorHidden) { isCursorHidden in
                if let delivered = gate.freezeChanged(
                    isFrozen: layerContext.isFrozen,
                    isScrolling: scrollState.isScrolling,
                    isCursorHidden: isCursorHidden
                ) {
                    action(delivered)
                }
            }
    }
}
