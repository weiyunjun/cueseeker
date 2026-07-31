import Testing
@testable import CueSeekerApp

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
