import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
private final class ControllerRepeatTestState {
    var inputs: [ControllerInput] = []
}

@MainActor
func runControllerRepeatTimers(for interval: TimeInterval = 0.05) {
    RunLoop.main.run(until: Date().addingTimeInterval(interval))
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
func thumbstickRepeatsUntilItReturnsToTheDeadzone() {
    let state = ControllerRepeatTestState()
    let monitor = GameControllerInputMonitor(
        repeatDelay: 0.01,
        repeatInterval: 0.01,
        inputEligibility: { true }
    ) { input in
        state.inputs.append(input)
        return true
    }
    defer {
        monitor.stop()
    }

    monitor.handleThumbstick(x: 0, y: 0.8)
    runControllerRepeatTimers()
    #expect(state.inputs.first == .direction(
        .up,
        source: .leftThumbstick,
        isRepeat: false
    ))
    #expect(state.inputs.contains(.direction(
        .up,
        source: .leftThumbstick,
        isRepeat: true
    )))

    monitor.handleThumbstick(x: 0, y: 0)
    let countAfterDeadzone = state.inputs.count
    runControllerRepeatTimers(for: 0.03)
    #expect(state.inputs.count == countAfterDeadzone)
}

@MainActor
@Test
func buttonsAndDirectionalPadRepeatUntilRelease() {
    let state = ControllerRepeatTestState()
    let monitor = GameControllerInputMonitor(
        repeatDelay: 0.01,
        repeatInterval: 0.01,
        inputEligibility: { true }
    ) { input in
        state.inputs.append(input)
        return true
    }
    defer {
        monitor.stop()
    }

    monitor.handleButton(.west, isPressed: true)
    runControllerRepeatTimers()
    #expect(state.inputs.first == .button(.west))
    #expect(state.inputs.contains(.button(.west, isRepeat: true)))

    monitor.handleButton(.west, isPressed: false)
    let countAfterButtonRelease = state.inputs.count
    runControllerRepeatTimers(for: 0.03)
    #expect(state.inputs.count == countAfterButtonRelease)

    monitor.handleDirectionalPad(.down, isPressed: true)
    runControllerRepeatTimers()
    #expect(state.inputs.contains(.direction(
        .down,
        source: .directionalPad,
        isRepeat: false
    )))
    #expect(state.inputs.contains(.direction(
        .down,
        source: .directionalPad,
        isRepeat: true
    )))

    monitor.handleDirectionalPad(.down, isPressed: false)
    let countAfterDirectionRelease = state.inputs.count
    runControllerRepeatTimers(for: 0.03)
    #expect(state.inputs.count == countAfterDirectionRelease)
}
