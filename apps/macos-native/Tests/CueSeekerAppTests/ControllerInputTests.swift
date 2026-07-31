import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
private final class ControllerRepeatTestState {
    var allowsRepeat: Bool
    var inputs: [ControllerInput] = []

    init(allowsRepeat: Bool) {
        self.allowsRepeat = allowsRepeat
    }
}

@Test
func thumbstickUsesMainAxisAndRequiresDeadzoneBeforeRetriggering() {
    var interpreter = ControllerThumbstickInterpreter()

    #expect(interpreter.update(x: 0.8, y: 0.6) == .right)
    #expect(interpreter.activeDirection == .right)
    #expect(interpreter.update(x: -0.9, y: 0) == nil)
    #expect(interpreter.activeDirection == .right)

    #expect(interpreter.update(x: 0.2, y: 0.2) == nil)
    #expect(interpreter.activeDirection == nil)
    #expect(interpreter.update(x: 0.2, y: -0.8) == .down)
}

@Test
func thumbstickIgnoresMovementBelowActivationThreshold() {
    var interpreter = ControllerThumbstickInterpreter()

    #expect(interpreter.update(x: 0.64, y: 0) == nil)
    #expect(interpreter.update(x: 0, y: 0.65) == .up)
    interpreter.reset()
    #expect(interpreter.activeDirection == nil)
}

@MainActor
@Test
func thumbstickRepeatRequiresEligibilityAtActivationAndANewDeadzoneCycle() async throws {
    let state = ControllerRepeatTestState(allowsRepeat: false)
    let monitor = GameControllerInputMonitor(
        repeatDelay: 0.01,
        repeatInterval: 0.01,
        inputEligibility: { true },
        repeatEligibility: { _ in state.allowsRepeat }
    ) { input in
        state.inputs.append(input)
        return true
    }
    defer {
        monitor.stop()
    }

    monitor.handleThumbstick(x: 0.8, y: 0)
    #expect(state.inputs == [
        .direction(.right, source: .leftThumbstick, isRepeat: false),
    ])

    state.allowsRepeat = true
    try await Task.sleep(for: .milliseconds(40))
    #expect(state.inputs.count == 1)

    monitor.handleThumbstick(x: 0, y: 0)
    monitor.handleThumbstick(x: 0.8, y: 0)
    #expect(state.inputs.count == 2)
}

@MainActor
@Test
func thumbstickRepeatStopsWhenTheCurrentInterfaceRejectsIt() async throws {
    let state = ControllerRepeatTestState(allowsRepeat: true)
    let monitor = GameControllerInputMonitor(
        repeatDelay: 0.02,
        repeatInterval: 0.01,
        inputEligibility: { true },
        repeatEligibility: { _ in state.allowsRepeat }
    ) { input in
        state.inputs.append(input)
        return true
    }
    defer {
        monitor.stop()
    }

    monitor.handleThumbstick(x: -0.8, y: 0)
    state.allowsRepeat = false
    try await Task.sleep(for: .milliseconds(50))
    #expect(state.inputs.count == 1)

    state.allowsRepeat = true
    try await Task.sleep(for: .milliseconds(30))
    #expect(state.inputs.count == 1)

    monitor.handleThumbstick(x: 0, y: 0)
    monitor.handleThumbstick(x: -0.8, y: 0)
    #expect(state.inputs.count == 2)
}
