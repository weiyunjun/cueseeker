import AppKit

// Only one instance per build environment may index its database. A second
// launch in the same environment hands the user back to the running instance.
let instanceLock: SingleInstanceGuard.LockHandle?
switch SingleInstanceGuard.acquireLock() {
case .acquired(let handle):
    instanceLock = handle
case .alreadyRunning(let holderPID):
    if let running = SingleInstanceGuard.runningApplication(forHolderPID: holderPID) {
        running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
    exit(0)
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = MainActor.assumeIsolated { AppDelegate() }

application.delegate = delegate
withExtendedLifetime(instanceLock) {
    application.run()
}

