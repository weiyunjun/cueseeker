import Foundation
import GameController

@MainActor
final class GameControllerInputMonitor {
    typealias InputEligibility = @MainActor () -> Bool
    typealias RepeatEligibility = @MainActor (ControllerDirection) -> Bool
    typealias InputHandler = @MainActor (ControllerInput) -> Bool

    private let inputEligibility: InputEligibility
    private let repeatEligibility: RepeatEligibility
    private let inputHandler: InputHandler
    private let repeatDelay: TimeInterval
    private let repeatInterval: TimeInterval
    private var notificationObservers: [NSObjectProtocol] = []
    private var activeController: GCController?
    private var thumbstickInterpreter = ControllerThumbstickInterpreter()
    private var repeatDelayTimer: Timer?
    private var repeatTimer: Timer?
    private var repeatingDirection: ControllerDirection?

    init(
        repeatDelay: TimeInterval = 0.4,
        repeatInterval: TimeInterval = 0.08,
        inputEligibility: @escaping InputEligibility,
        repeatEligibility: @escaping RepeatEligibility,
        inputHandler: @escaping InputHandler
    ) {
        self.repeatDelay = repeatDelay
        self.repeatInterval = repeatInterval
        self.inputEligibility = inputEligibility
        self.repeatEligibility = repeatEligibility
        self.inputHandler = inputHandler
    }

    func start() {
        guard notificationObservers.isEmpty else {
            return
        }

        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reconcileControllers()
                }
            },
            center.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let controller = notification.object as? GCController else {
                    return
                }
                let controllerID = ObjectIdentifier(controller)
                MainActor.assumeIsolated {
                    self?.disconnectController(id: controllerID)
                }
            },
        ]

        connectFirstAvailableController()
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func stop() {
        GCController.stopWirelessControllerDiscovery()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll(keepingCapacity: false)
        detachActiveController()
    }

    private func connectFirstAvailableController() {
        guard activeController == nil else {
            return
        }
        for controller in GCController.controllers() {
            if connect(controller) {
                return
            }
        }
    }

    @discardableResult
    private func connect(_ controller: GCController) -> Bool {
        guard activeController == nil,
              controller.productCategory == GCProductCategoryDualSense,
              let profile = controller.extendedGamepad as? GCDualSenseGamepad
        else {
            return false
        }

        activeController = controller
        controller.handlerQueue = .main
        configure(profile)
        return true
    }

    private func reconcileControllers() {
        if let activeController,
           !GCController.controllers().contains(where: { $0 === activeController }) {
            detachActiveController()
        }
        connectFirstAvailableController()
    }

    private func disconnectController(id: ObjectIdentifier) {
        guard let activeController,
              ObjectIdentifier(activeController) == id
        else {
            return
        }
        detachActiveController()
        connectFirstAvailableController()
    }

    private func configure(_ profile: GCDualSenseGamepad) {
        bind(profile.buttonA, to: .south)
        bind(profile.buttonB, to: .east)
        bind(profile.buttonX, to: .west)
        bind(profile.buttonY, to: .north)
        bind(profile.buttonOptions, to: .auxiliaryLeft)
        bind(profile.buttonMenu, to: .auxiliaryRight)
        bind(profile.touchpadButton, to: .centerSurface)
        bind(profile.leftShoulder, to: .leftShoulder)
        bind(profile.rightShoulder, to: .rightShoulder)
        bind(profile.leftTrigger, to: .leftTrigger)
        bind(profile.rightTrigger, to: .rightTrigger)
        bind(profile.leftThumbstickButton, to: .leftThumbstick)
        bind(profile.rightThumbstickButton, to: .rightThumbstick)

        bind(profile.dpad.up, to: .up)
        bind(profile.dpad.down, to: .down)
        bind(profile.dpad.left, to: .left)
        bind(profile.dpad.right, to: .right)

        profile.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            MainActor.assumeIsolated {
                self?.handleThumbstick(x: x, y: y)
            }
        }
    }

    private func bind(
        _ input: GCControllerButtonInput?,
        to button: ControllerButton
    ) {
        input?.pressedChangedHandler = { [weak self] _, _, isPressed in
            guard isPressed else {
                return
            }
            _ = MainActor.assumeIsolated {
                self?.deliver(.button(button))
            }
        }
    }

    private func bind(
        _ input: GCControllerButtonInput,
        to direction: ControllerDirection
    ) {
        input.pressedChangedHandler = { [weak self] _, _, isPressed in
            guard isPressed else {
                return
            }
            _ = MainActor.assumeIsolated {
                self?.deliver(.direction(
                    direction,
                    source: .directionalPad,
                    isRepeat: false
                ))
            }
        }
    }

    func handleThumbstick(x: Float, y: Float) {
        let previousDirection = thumbstickInterpreter.activeDirection
        let activatedDirection = thumbstickInterpreter.update(x: x, y: y)

        if previousDirection != nil,
           thumbstickInterpreter.activeDirection == nil {
            cancelDirectionRepeat()
        }
        guard let activatedDirection else {
            return
        }

        guard deliver(.direction(
            activatedDirection,
            source: .leftThumbstick,
            isRepeat: false
        )) else {
            return
        }
        guard repeatEligibility(activatedDirection) else {
            return
        }
        startDirectionRepeat(activatedDirection)
    }

    private func startDirectionRepeat(_ direction: ControllerDirection) {
        cancelDirectionRepeat()
        repeatingDirection = direction

        let delayTimer = Timer(timeInterval: repeatDelay, repeats: false) {
            [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.repeatingDirection == direction else {
                    return
                }
                guard self.repeatEligibility(direction),
                      self.deliver(.direction(
                    direction,
                    source: .leftThumbstick,
                    isRepeat: true
                )) else {
                    self.cancelDirectionRepeat()
                    return
                }
                let repeatTimer = Timer(
                    timeInterval: self.repeatInterval,
                    repeats: true
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self,
                              self.repeatingDirection == direction
                        else {
                            return
                        }
                        guard self.repeatEligibility(direction),
                              self.deliver(.direction(
                            direction,
                            source: .leftThumbstick,
                            isRepeat: true
                        )) else {
                            self.cancelDirectionRepeat()
                            return
                        }
                    }
                }
                self.repeatTimer = repeatTimer
                RunLoop.main.add(repeatTimer, forMode: .common)
            }
        }
        repeatDelayTimer = delayTimer
        RunLoop.main.add(delayTimer, forMode: .common)
    }

    private func cancelDirectionRepeat() {
        repeatDelayTimer?.invalidate()
        repeatDelayTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatingDirection = nil
    }

    private func detachActiveController() {
        if let profile = activeController?.extendedGamepad as? GCDualSenseGamepad {
            profile.buttonA.pressedChangedHandler = nil
            profile.buttonB.pressedChangedHandler = nil
            profile.buttonX.pressedChangedHandler = nil
            profile.buttonY.pressedChangedHandler = nil
            profile.buttonOptions?.pressedChangedHandler = nil
            profile.buttonMenu.pressedChangedHandler = nil
            profile.touchpadButton.pressedChangedHandler = nil
            profile.leftShoulder.pressedChangedHandler = nil
            profile.rightShoulder.pressedChangedHandler = nil
            profile.leftTrigger.pressedChangedHandler = nil
            profile.rightTrigger.pressedChangedHandler = nil
            profile.leftThumbstickButton?.pressedChangedHandler = nil
            profile.rightThumbstickButton?.pressedChangedHandler = nil
            profile.dpad.up.pressedChangedHandler = nil
            profile.dpad.down.pressedChangedHandler = nil
            profile.dpad.left.pressedChangedHandler = nil
            profile.dpad.right.pressedChangedHandler = nil
            profile.leftThumbstick.valueChangedHandler = nil
        }

        cancelDirectionRepeat()
        thumbstickInterpreter.reset()
        activeController = nil
    }

    @discardableResult
    private func deliver(_ input: ControllerInput) -> Bool {
        guard inputEligibility() else {
            return false
        }
        return inputHandler(input)
    }
}
