import AppKit
import CueSeekerCore
import QuartzCore

enum PlaybackSubtitleFocusScrollSettleDirective: Equatable {
    case none
    case cancel
    case debounce
    case immediate
}

struct PlaybackSubtitleFocusScrollSample: Equatable {
    enum Phase: Equatable {
        case none
        case began
        case changed
        case ended
        case cancelled
    }

    let deltaY: CGFloat
    let isPrecise: Bool
    let phase: Phase
    let momentumPhase: Phase
    let isInside: Bool
}

enum PlaybackSubtitleFocusNativeWheelMode: Equatable {
    case none
    case discrete(direction: SubtitleFocusNavigationDirection, stepCount: Int)
    case precise(deltaY: CGFloat, beginsGesture: Bool)
}

struct PlaybackSubtitleFocusNativeWheelOutput: Equatable {
    let shouldConsume: Bool
    let mode: PlaybackSubtitleFocusNativeWheelMode
    let settleDirective: PlaybackSubtitleFocusScrollSettleDirective

    static let passThrough = PlaybackSubtitleFocusNativeWheelOutput(
        shouldConsume: false,
        mode: .none,
        settleDirective: .none
    )

    static let consumedNoop = PlaybackSubtitleFocusNativeWheelOutput(
        shouldConsume: true,
        mode: .none,
        settleDirective: .none
    )
}

struct PlaybackSubtitleFocusNativeWheelState: Equatable {
    private var ownsPreciseGesture = false
    private var awaitsMomentum = false
    private var requiresNewGesture = false

    mutating func consume(
        _ sample: PlaybackSubtitleFocusScrollSample,
        isEnabled: Bool
    ) -> PlaybackSubtitleFocusNativeWheelOutput {
        guard isEnabled else {
            reset(requiresNewGesture: true)
            return .consumedNoop
        }

        let hasNoPhases = sample.phase == .none && sample.momentumPhase == .none
        let isDiscrete = !sample.isPrecise
        if requiresNewGesture {
            let startsFreshGesture = isDiscrete
                || sample.phase == .began
                || (sample.isPrecise && hasNoPhases && sample.isInside)
            guard startsFreshGesture else {
                return .consumedNoop
            }
            requiresNewGesture = false
        }

        if isDiscrete {
            guard sample.isInside else {
                return .passThrough
            }
            guard sample.deltaY.isFinite, sample.deltaY != 0 else {
                return .consumedNoop
            }
            let direction: SubtitleFocusNavigationDirection = sample.deltaY > 0
                ? .backward
                : .forward
            return PlaybackSubtitleFocusNativeWheelOutput(
                shouldConsume: true,
                mode: .discrete(
                    direction: direction,
                    stepCount: max(1, Int(abs(sample.deltaY).rounded(.up)))
                ),
                settleDirective: .none
            )
        }

        if sample.isPrecise && hasNoPhases {
            guard sample.isInside || ownsPreciseGesture else {
                return .passThrough
            }
            let beginsGesture = !ownsPreciseGesture
            ownsPreciseGesture = true
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .debounce
            )
        }

        var beginsGesture = false
        if sample.phase == .began {
            ownsPreciseGesture = sample.isInside
            awaitsMomentum = false
            beginsGesture = ownsPreciseGesture
        } else if sample.momentumPhase == .began, awaitsMomentum {
            ownsPreciseGesture = true
            awaitsMomentum = false
        } else if !ownsPreciseGesture,
                  !awaitsMomentum,
                  sample.phase == .changed,
                  sample.isInside {
            ownsPreciseGesture = true
            beginsGesture = true
        }

        guard ownsPreciseGesture else {
            return .passThrough
        }
        if sample.phase == .cancelled || sample.momentumPhase == .cancelled {
            ownsPreciseGesture = false
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .immediate
            )
        }
        if sample.momentumPhase == .ended {
            ownsPreciseGesture = false
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .immediate
            )
        }
        if sample.momentumPhase == .began {
            ownsPreciseGesture = true
            awaitsMomentum = false
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .cancel
            )
        }
        if sample.phase == .ended {
            ownsPreciseGesture = false
            awaitsMomentum = true
            return preciseOutput(
                sample,
                beginsGesture: beginsGesture,
                settleDirective: .debounce
            )
        }
        return preciseOutput(
            sample,
            beginsGesture: beginsGesture,
            settleDirective: .cancel
        )
    }

    mutating func finishPreciseGesture() {
        ownsPreciseGesture = false
        awaitsMomentum = false
    }

    mutating func reset(requiresNewGesture: Bool = false) {
        ownsPreciseGesture = false
        awaitsMomentum = false
        self.requiresNewGesture = requiresNewGesture
    }

    private func preciseOutput(
        _ sample: PlaybackSubtitleFocusScrollSample,
        beginsGesture: Bool,
        settleDirective: PlaybackSubtitleFocusScrollSettleDirective
    ) -> PlaybackSubtitleFocusNativeWheelOutput {
        let deltaY = sample.deltaY.isFinite ? sample.deltaY : 0
        return PlaybackSubtitleFocusNativeWheelOutput(
            shouldConsume: true,
            mode: .precise(
                deltaY: deltaY,
                beginsGesture: beginsGesture
            ),
            settleDirective: settleDirective
        )
    }
}

@MainActor
final class PlaybackSubtitleFocusReelPositionAnimator: NSObject {
    let onUpdate: (CGFloat) -> Void
    let onCompletion: () -> Void
    weak var hostView: NSView?

    private(set) var isRunning = false
    var hasActiveTimer: Bool {
        timer != nil || displayLink != nil
    }
    private var timer: Timer?
    private var displayLink: AnyObject?
    private var generation = 0
    private var startTime: TimeInterval = 0
    private var duration: TimeInterval = 0
    private var startOffset: CGFloat = 0
    private var targetOffset: CGFloat = 0

    init(
        onUpdate: @escaping (CGFloat) -> Void,
        onCompletion: @escaping () -> Void
    ) {
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
    }

    func retarget(
        from currentOffset: CGFloat,
        to targetOffset: CGFloat,
        duration: TimeInterval
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        var resolvedStartOffset = currentOffset
        if isRunning, self.duration > 0 {
            let elapsed = max(0, now - startTime)
            let linearProgress = CGFloat(min(1, max(0, elapsed / self.duration)))
            let easedProgress = Self.easedProgress(linearProgress)
            resolvedStartOffset = startOffset
                + (self.targetOffset - startOffset) * easedProgress
        }
        generation += 1
        self.duration = max(0, duration)
        let isHostVisible = hostView?.window?.isVisible == true
        let initialLead = isHostVisible
            ? min(1.0 / 120.0, self.duration * 0.25)
            : 0
        startTime = now - initialLead
        startOffset = resolvedStartOffset
        self.targetOffset = targetOffset
        isRunning = true

        guard self.duration > 0, abs(targetOffset - resolvedStartOffset) > 0.01 else {
            finishImmediately(generation: generation)
            return
        }
        if #available(macOS 14.0, *),
           let hostView,
           hostView.window?.isVisible == true {
            timer?.invalidate()
            timer = nil
            if displayLink == nil {
                let link = hostView.displayLink(
                    target: self,
                    selector: #selector(handleDisplayLink(_:))
                )
                link.preferredFrameRateRange = CAFrameRateRange(
                    minimum: 60,
                    maximum: 120,
                    preferred: 120
                )
                link.add(to: .main, forMode: .common)
                link.isPaused = false
                displayLink = link
            }
        } else if timer == nil {
            let timer = Timer(
                timeInterval: 1 / 120,
                target: self,
                selector: #selector(handleTimer),
                userInfo: nil,
                repeats: true
            )
            timer.tolerance = 0
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        if isHostVisible, initialLead > 0 {
            let easedProgress = Self.easedProgress(
                CGFloat(initialLead / self.duration)
            )
            onUpdate(
                resolvedStartOffset + (targetOffset - resolvedStartOffset) * easedProgress
            )
        }
    }

    func cancel() {
        generation += 1
        stopFrameDriver()
        isRunning = false
    }

    static func easedProgress(_ linearProgress: CGFloat) -> CGFloat {
        CGFloat(
            PlaybackSubtitleFocusMetrics.scrollEasing.value(
                at: Double(linearProgress)
            )
        )
    }

    static func focusFadeEasedProgress(_ linearProgress: CGFloat) -> CGFloat {
        CGFloat(
            PlaybackSubtitleFocusMetrics.focusFadeEasing.value(
                at: Double(linearProgress)
            )
        )
    }

    @objc
    private func handleDisplayLink(_ sender: AnyObject) {
        handleTimer()
    }

    @objc
    private func handleTimer() {
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let linearProgress = CGFloat(min(1, max(0, elapsed / duration)))
        guard linearProgress < 1 else {
            stopFrameDriver()
            isRunning = false
            onUpdate(targetOffset)
            onCompletion()
            return
        }
        let easedProgress = Self.easedProgress(linearProgress)
        onUpdate(
            startOffset + (targetOffset - startOffset) * easedProgress
        )
    }

    private func finishImmediately(generation expectedGeneration: Int) {
        stopFrameDriver()
        onUpdate(targetOffset)
        Task { @MainActor [weak self] in
            guard let self,
                  self.generation == expectedGeneration,
                  self.isRunning
            else {
                return
            }
            self.isRunning = false
            self.onCompletion()
        }
    }

    private func stopFrameDriver() {
        if #available(macOS 14.0, *),
           let link = displayLink as? CADisplayLink {
            link.invalidate()
        }
        displayLink = nil
        timer?.invalidate()
        timer = nil
    }
}
