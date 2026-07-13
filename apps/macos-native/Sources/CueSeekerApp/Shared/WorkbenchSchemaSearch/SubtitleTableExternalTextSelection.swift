import AppKit
import SwiftUI

@MainActor
protocol SubtitleTableExternalTextSelectionTarget: AnyObject {
    var externalTextSelectionWindowRect: CGRect? { get }
    var canBeginExternalTextSelection: Bool { get }

    func beginExternalTextSelection(
        startWindowPoint: CGPoint,
        currentWindowPoint: CGPoint
    ) -> Bool
    func updateExternalTextSelection(windowPoint: CGPoint) -> Bool
    func endExternalTextSelection(windowPoint: CGPoint) -> Bool
    func cancelExternalTextSelection()
}

@MainActor
final class SubtitleTableExternalTextSelectionSession: ObservableObject {
    private static let dragThreshold: CGFloat = 3

    enum Phase: Equatable {
        case idle
        case armed
        case selecting
    }

    private(set) var phase: Phase = .idle
    private weak var target: (any SubtitleTableExternalTextSelectionTarget)?
    private var targetIdentity: ObjectIdentifier?
    private var startWindowPoint: CGPoint?

    var targetWindowRect: CGRect? {
        validTargetWindowRect
    }

    func bind(_ target: any SubtitleTableExternalTextSelectionTarget) {
        let identity = ObjectIdentifier(target)
        guard self.target == nil || targetIdentity != identity else {
            return
        }

        cancel()
        self.target = target
        targetIdentity = identity
    }

    func unbind(_ target: any SubtitleTableExternalTextSelectionTarget) {
        guard targetIdentity == ObjectIdentifier(target) else {
            return
        }

        cancel()
        self.target = nil
        targetIdentity = nil
    }

    @discardableResult
    func arm(startWindowPoint: CGPoint) -> Bool {
        cancel()
        guard target?.canBeginExternalTextSelection == true,
              validTargetWindowRect != nil
        else {
            return false
        }

        self.startWindowPoint = startWindowPoint
        phase = .armed
        return true
    }

    @discardableResult
    func drag(windowPoint: CGPoint) -> Bool {
        guard let target else {
            reset()
            return false
        }

        switch phase {
        case .idle:
            return false
        case .armed:
            guard target.canBeginExternalTextSelection,
                  let targetWindowRect = validTargetWindowRect,
                  targetWindowRect.contains(windowPoint),
                  let startWindowPoint,
                  hypot(
                      windowPoint.x - startWindowPoint.x,
                      windowPoint.y - startWindowPoint.y
                  ) >= Self.dragThreshold
            else {
                if !target.canBeginExternalTextSelection || validTargetWindowRect == nil {
                    reset()
                }
                return false
            }

            guard target.beginExternalTextSelection(
                startWindowPoint: startWindowPoint,
                currentWindowPoint: windowPoint
            ) else {
                return false
            }
            phase = .selecting
            return true
        case .selecting:
            guard target.updateExternalTextSelection(windowPoint: windowPoint) else {
                target.cancelExternalTextSelection()
                reset()
                return false
            }
            return true
        }
    }

    @discardableResult
    func end(windowPoint: CGPoint) -> Bool {
        guard phase == .selecting, let target else {
            reset()
            return false
        }

        let handled = target.endExternalTextSelection(windowPoint: windowPoint)
        if !handled {
            target.cancelExternalTextSelection()
        }
        reset()
        return handled
    }

    func cancel() {
        if phase == .selecting {
            target?.cancelExternalTextSelection()
        }
        reset()
    }

    private var validTargetWindowRect: CGRect? {
        guard let rect = target?.externalTextSelectionWindowRect,
              rect.width > 0,
              rect.height > 0,
              !rect.isNull,
              !rect.isInfinite
        else {
            return nil
        }
        return rect
    }

    private func reset() {
        phase = .idle
        startWindowPoint = nil
    }
}

private struct SubtitleTableExternalTextSelectionSessionKey: EnvironmentKey {
    static let defaultValue: SubtitleTableExternalTextSelectionSession? = nil
}

extension EnvironmentValues {
    var subtitleTableExternalTextSelectionSession: SubtitleTableExternalTextSelectionSession? {
        get { self[SubtitleTableExternalTextSelectionSessionKey.self] }
        set { self[SubtitleTableExternalTextSelectionSessionKey.self] = newValue }
    }
}

enum SubtitleTableExternalTextSelectionRegion: Hashable {
    case allowedBackground
    case searchAndFilter
    case countSummary
    case summaryAction
    case viewButton
}

struct SubtitleTableExternalTextSelectionRegionPreferenceKey: PreferenceKey {
    static var defaultValue: [SubtitleTableExternalTextSelectionRegion: CGRect] { [:] }

    static func reduce(
        value: inout [SubtitleTableExternalTextSelectionRegion: CGRect],
        nextValue: () -> [SubtitleTableExternalTextSelectionRegion: CGRect]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func subtitleTableExternalTextSelectionRegion(
        _ region: SubtitleTableExternalTextSelectionRegion,
        in coordinateSpaceName: String
    ) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .allowsHitTesting(false)
                    .preference(
                        key: SubtitleTableExternalTextSelectionRegionPreferenceKey.self,
                        value: [region: geometry.frame(in: .named(coordinateSpaceName))]
                    )
            }
        )
    }
}

struct SubtitleTableExternalTextSelectionStartPolicy: Equatable {
    let allowedFrame: CGRect?
    let excludedFrames: [CGRect]
    let requiredFramesAreReady: Bool
    let isBlocked: Bool

    func allowsStart(at point: CGPoint, tableFrame: CGRect?) -> Bool {
        guard !isBlocked,
              requiredFramesAreReady,
              let allowedFrame,
              let tableFrame,
              tableFrame.width > 0,
              tableFrame.height > 0,
              allowedFrame.contains(point),
              !tableFrame.contains(point)
        else {
            return false
        }
        return !excludedFrames.contains(where: { $0.contains(point) })
    }
}

struct SubtitleTableExternalTextSelectionEventMonitor: NSViewRepresentable {
    let session: SubtitleTableExternalTextSelectionSession
    let startPolicy: SubtitleTableExternalTextSelectionStartPolicy

    func makeNSView(context _: Context) -> MonitoringView {
        MonitoringView()
    }

    func updateNSView(_ nsView: MonitoringView, context _: Context) {
        nsView.update(session: session, startPolicy: startPolicy)
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator _: Void) {
        nsView.tearDown()
    }

    @MainActor
    final class MonitoringView: NSView {
        nonisolated(unsafe) private var eventMonitor: Any?
        private weak var session: SubtitleTableExternalTextSelectionSession?
        private var startPolicy = SubtitleTableExternalTextSelectionStartPolicy(
            allowedFrame: nil,
            excludedFrames: [],
            requiredFramesAreReady: false,
            isBlocked: true
        )

        override var isFlipped: Bool { true }

        func update(
            session: SubtitleTableExternalTextSelectionSession,
            startPolicy: SubtitleTableExternalTextSelectionStartPolicy
        ) {
            if self.session !== session {
                self.session?.cancel()
                self.session = session
            }
            self.startPolicy = startPolicy
            if startPolicy.isBlocked || !startPolicy.requiredFramesAreReady {
                session.cancel()
            }
            installEventMonitorIfNeeded()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                session?.cancel()
                removeEventMonitor()
            } else {
                installEventMonitorIfNeeded()
            }
        }

        func tearDown() {
            session?.cancel()
            session = nil
            removeEventMonitor()
        }

        func routeForTesting(_ event: NSEvent) {
            route(event)
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
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.route(event)
                }
                return event
            }
        }

        private func removeEventMonitor() {
            guard let eventMonitor else {
                return
            }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        private func route(_ event: NSEvent) {
            guard let session else {
                return
            }
            if event.type == .leftMouseDown {
                session.cancel()
            }
            guard event.window === window else { return }

            switch event.type {
            case .leftMouseDown:
                let localPoint = convert(event.locationInWindow, from: nil)
                let tableFrame = session.targetWindowRect.map { convert($0, from: nil) }
                guard startPolicy.allowsStart(at: localPoint, tableFrame: tableFrame) else {
                    return
                }
                _ = session.arm(startWindowPoint: event.locationInWindow)
            case .leftMouseDragged:
                _ = session.drag(windowPoint: event.locationInWindow)
            case .leftMouseUp:
                _ = session.end(windowPoint: event.locationInWindow)
            default:
                break
            }
        }
    }
}
