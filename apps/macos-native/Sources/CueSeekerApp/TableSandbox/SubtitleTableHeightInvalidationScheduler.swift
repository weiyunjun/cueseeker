import Foundation

@MainActor
final class SubtitleTableHeightInvalidationScheduler {
    typealias ScheduleBlock = @MainActor (
        _ delayNanoseconds: UInt64,
        _ operation: @escaping @MainActor () -> Void
    ) -> Void

    private let delayNanoseconds: UInt64
    private let action: (String) -> Void
    private let scheduleBlock: ScheduleBlock
    private var pendingReason: String?
    private var isScheduled = false

    init(
        delayNanoseconds: UInt64 = 16_000_000,
        scheduleBlock: ScheduleBlock? = nil,
        action: @escaping (String) -> Void
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.scheduleBlock = scheduleBlock ?? { delayNanoseconds, operation in
            DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(Int(delayNanoseconds))) {
                Task { @MainActor in operation() }
            }
        }
        self.action = action
    }

    func schedule(reason: String) {
        pendingReason = reason
        guard !isScheduled else { return }

        isScheduled = true
        scheduleBlock(delayNanoseconds) { [weak self] in
            self?.fire()
        }
    }

    func cancel() {
        isScheduled = false
        pendingReason = nil
    }

    func flushForTesting() {
        fire()
    }

    private func fire() {
        guard isScheduled else { return }
        let reason = pendingReason ?? "scheduled"
        pendingReason = nil
        isScheduled = false
        action(reason)
    }
}
