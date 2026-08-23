import AppKit

// Only one instance may index the shared database. A second launch hands the
// user back to the instance that is already running instead of exiting silently.
if let running = SingleInstanceGuard.runningInstance() {
    running.activate(options: [.activateAllWindows])
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()

application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()

