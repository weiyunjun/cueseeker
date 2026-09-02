import AppKit
import SwiftUI

/// The shapes the pointer takes in CueSeeker.
enum PointerShape: Equatable {
    case arrow
    case grab
    case iBeam

    var cursor: NSCursor {
        switch self {
        case .arrow: .arrow
        case .grab: .pointingHand
        case .iBeam: .iBeam
        }
    }
}

/// An AppKit surface that answers the shape for a point of its own. It is
/// asked only when the pointer really moved.
@MainActor
protocol PointerShapeProviding: AnyObject {
    func pointerShape(atWindowPoint point: CGPoint) -> PointerShape
}

/// The decision, kept free of AppKit so tests can drive it with the event
/// sequences of `docs/human/requirements/20260902-UI-Pointer Shape Follows
/// Pointer Movement.md`.
///
/// The shape changes on three occasions only. The pointer really moved, and
/// what is under it is asked. A reset — an interface switch, a menu or a
/// dialog opening — puts the arrow back until the next movement. Or the
/// hand's target lost its highlight to something other than the pointer.
/// Nothing else moves it: not the wheel, not a key, not a layout change under
/// a pointer that stayed put.
struct PointerShapeModel: Equatable {
    private(set) var shape: PointerShape = .arrow
    /// The cards under the pointer that would show the hand. SwiftUI reports
    /// them whether or not the pointer moved, so they are bookkeeping until a
    /// movement, or a hover the pointer itself caused, asks for a decision.
    private var handCardsUnderPointer: Set<String> = []

    /// A real pointer movement. `surfaceShape` is what the surface under the
    /// pointer answers; a hand card under the pointer wins over it. While a
    /// menu owns input, movement decides nothing and the arrow stays.
    mutating func pointerMoved(
        over surfaceShape: PointerShape,
        isMenuOpen: Bool
    ) -> PointerShape? {
        guard !isMenuOpen else {
            return nil
        }
        return apply(handCardsUnderPointer.isEmpty ? surfaceShape : .grab)
    }

    /// A card's hover report. Returns whether the report calls for a decision
    /// now, which is only when the pointer caused it — the card's highlight
    /// model knows — so a card that slid under a still pointer changes nothing.
    mutating func cardHover(
        _ isHovered: Bool,
        id: String,
        showsHand: Bool,
        followsPointer: Bool
    ) -> Bool {
        if isHovered, showsHand {
            handCardsUnderPointer.insert(id)
        } else {
            handCardsUnderPointer.remove(id)
        }
        return followsPointer
    }

    /// Rules 3 and 4: the arrow, until the pointer moves again.
    mutating func reset() -> PointerShape {
        apply(.arrow)
    }

    /// Rule 5: the hand's target lost its highlight to something other than
    /// the pointer. Only the hand is affected; an I-beam stays where it is.
    mutating func handTargetChanged() -> PointerShape? {
        guard shape == .grab else {
            return nil
        }
        return apply(.arrow)
    }

    private mutating func apply(_ next: PointerShape) -> PointerShape {
        shape = next
        return next
    }
}

/// The one place the App decides a pointer shape.
///
/// AppKit re-evaluates the cursor for the pointer's current location at every
/// display cycle — after a scroll, a layout change, a key that moved a
/// selection — and applies whatever cursor rect it finds there, or the arrow
/// when it finds none; SwiftUI used to answer from geometry through its
/// hosting view's cursor update. That is measured, not assumed; see the
/// implementation record. A shape left to them follows geometry instead of
/// the pointer, which the requirement forbids. So the shape is decided here,
/// on real movement and on the resets and at no other time, and every surface
/// carries that one decided shape in a cursor rect over its whole area, so
/// what AppKit applies at the display cycle is the decision already made.
@MainActor
enum AppPointerShape {
    private(set) static var model = PointerShapeModel()
    private static weak var window: NSWindow?
    private static var isMenuOpen: () -> Bool = { false }
    private static var runLoopObserver: CFRunLoopObserver?

    static func attach(to window: NSWindow, isMenuOpen: @escaping @MainActor () -> Bool) {
        self.window = window
        self.isMenuOpen = isMenuOpen
        installRestore()
    }

    /// The cursor a surface registers over its whole visible area, from
    /// `resetCursorRects`. AppKit applies a cursor rect synchronously in the
    /// same pass that would otherwise fall back to the arrow, so the rect is
    /// how the decided shape survives a scroll or a layout change under a
    /// pointer that did not move. The rect is rebuilt only when the shape
    /// changes.
    static var rectCursor: NSCursor {
        model.shape.cursor
    }

    /// AppKit still states a shape of its own now and then: the arrow when
    /// the pointer leaves a tracking area or the window becomes key, the
    /// I-beam from a text view's own tracking. None of those is a movement,
    /// so none may change the shape. The owner's shape is put back at the end
    /// of every run loop pass. Only the App's own three shapes are corrected,
    /// so a cursor AppKit chose for a reason of its own is left alone, and
    /// nothing is stated while the pointer is outside the window or the App
    /// is not active, where the cursor belongs to somebody else.
    private static func installRestore() {
        guard runLoopObserver == nil else {
            return
        }
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue,
            true,
            CFIndex.max
        ) { _, _ in
            MainActor.assumeIsolated {
                restoreIfAppKitTookOver()
            }
        }
        runLoopObserver = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    private static func restoreIfAppKitTookOver() {
        let cursor = model.shape.cursor
        guard NSApp.isActive,
              let window,
              let content = window.contentView,
              content.frame.contains(window.mouseLocationOutsideOfEventStream)
        else {
            return
        }
        let current = NSCursor.current
        guard current !== cursor,
              [NSCursor.arrow, NSCursor.iBeam, NSCursor.pointingHand].contains(where: { $0 === current })
        else {
            return
        }
        cursor.set()
    }

    /// From the window, once it has dispatched a real pointer movement.
    static func pointerMoved(in window: NSWindow, at windowPoint: CGPoint) {
        guard window === self.window else {
            return
        }
        decide(at: windowPoint)
    }

    /// From a card's highlight model, for every hover report it receives.
    static func noteCardHover(
        _ isHovered: Bool,
        id: String,
        showsHand: Bool,
        followsPointer: Bool
    ) {
        guard model.cardHover(
            isHovered,
            id: id,
            showsHand: showsHand,
            followsPointer: followsPointer
        ), let window else {
            return
        }
        decide(at: window.mouseLocationOutsideOfEventStream)
    }

    /// An interface switch, or a menu or dialog opening.
    static func reset() {
        set(model.reset())
    }

    /// The hand's target lost its highlight to something other than the
    /// pointer.
    static func handTargetChanged() {
        set(model.handTargetChanged())
    }

    /// AppKit asked what the cursor should be, for the rect a surface carries.
    /// The answer is the shape already decided; nothing is decided again.
    static func restate() {
        model.shape.cursor.set()
    }

    private static func decide(at windowPoint: CGPoint) {
        set(model.pointerMoved(
            over: surfaceShape(at: windowPoint),
            isMenuOpen: isMenuOpen()
        ))
    }

    /// What the AppKit view under the pointer answers: a surface that decides
    /// for itself, text that can be selected or typed into, or nothing.
    private static func surfaceShape(at windowPoint: CGPoint) -> PointerShape {
        guard let content = window?.contentView else {
            return .arrow
        }
        let point = content.superview?.convert(windowPoint, from: nil) ?? windowPoint
        var view = content.hitTest(point)
        while let current = view {
            if let surface = current as? PointerShapeProviding {
                return surface.pointerShape(atWindowPoint: windowPoint)
            }
            if let text = current as? NSTextView {
                return text.isSelectable ? .iBeam : .arrow
            }
            if let field = current as? NSTextField {
                return field.isEditable || field.isSelectable ? .iBeam : .arrow
            }
            view = current.superview
        }
        return .arrow
    }

    private static var rectShape: PointerShape = .arrow

    private static func set(_ shape: PointerShape?) {
        guard let shape else {
            return
        }
        shape.cursor.set()
        if shape != rectShape {
            rectShape = shape
            window?.resetCursorRects()
        }
    }
}

/// A hosting view that leaves the pointer shape to `AppPointerShape`.
///
/// SwiftUI answers AppKit's cursor query from here with a shape decided from
/// geometry. This view answers with the shape the App already decided: as a
/// cursor rect over its whole area, which is what AppKit applies at the
/// display cycle — measured to run in the same pass that would otherwise fall
/// back to the arrow and flicker on every wheel notch — and again from the
/// cursor update AppKit sends for that rect.
class CueSeekerHostingView<Content: View>: NSHostingView<Content> {
    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: AppPointerShape.rectCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        AppPointerShape.restate()
    }
}
