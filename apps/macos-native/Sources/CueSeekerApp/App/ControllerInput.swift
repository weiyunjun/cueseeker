import Foundation

enum ControllerButton: Equatable, Sendable {
    case south
    case east
    case west
    case north
    case auxiliaryLeft
    case auxiliaryRight
    case centerSurface
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case leftThumbstick
    case rightThumbstick
}

enum ControllerDirection: Equatable, Sendable {
    case up
    case down
    case left
    case right
}

enum ControllerDirectionalSource: Equatable, Sendable {
    case directionalPad
    case leftThumbstick
}

enum ControllerInput: Equatable, Sendable {
    case button(ControllerButton, isRepeat: Bool = false)
    case direction(
        ControllerDirection,
        source: ControllerDirectionalSource,
        isRepeat: Bool
    )
}

struct ControllerThumbstickInterpreter {
    let activationThreshold: Float
    let releaseThreshold: Float
    private(set) var activeDirection: ControllerDirection?

    init(
        activationThreshold: Float = 0.65,
        releaseThreshold: Float = 0.35
    ) {
        precondition(releaseThreshold < activationThreshold)
        self.activationThreshold = activationThreshold
        self.releaseThreshold = releaseThreshold
    }

    mutating func update(x: Float, y: Float) -> ControllerDirection? {
        let horizontalMagnitude = abs(x)
        let verticalMagnitude = abs(y)

        if activeDirection != nil {
            if max(horizontalMagnitude, verticalMagnitude) <= releaseThreshold {
                activeDirection = nil
            }
            return nil
        }

        guard max(horizontalMagnitude, verticalMagnitude) >= activationThreshold else {
            return nil
        }

        let direction: ControllerDirection
        if horizontalMagnitude > verticalMagnitude {
            direction = x < 0 ? .left : .right
        } else {
            direction = y < 0 ? .down : .up
        }
        activeDirection = direction
        return direction
    }

    mutating func reset() {
        activeDirection = nil
    }
}
