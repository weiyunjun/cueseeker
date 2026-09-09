import AppKit
import SwiftUI

private struct AppFullscreenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The window is in system fullscreen, so the system titlebar owns the
    /// window controls and a page's own bar starts at its own padding instead
    /// of reserving their band.
    var isAppFullscreen: Bool {
        get { self[AppFullscreenKey.self] }
        set { self[AppFullscreenKey.self] = newValue }
    }
}

/// The one owner of the native window controls: close, minimize and zoom.
///
/// The three buttons stay in AppKit's own titlebar, so everything AppKit gives
/// them stays native — the hover glyphs of the group, the zoom button's tiling
/// menu, the Option behaviours — and nothing has to be put back after a sheet
/// or a resize re-tiles the titlebar. Two private `NSWindow` setters place
/// them: the titlebar height centres the group in the top bar, and the group
/// offset moves it in to the bar's inset. Both were measured to survive sheets,
/// resizes and hiding; see the implementation record.
///
/// The place is the same on every page — inset `--spacing-6`, centred in
/// `--height-app-topbar` — and only the visibility follows the page. Pages
/// report their state here and place nothing themselves.
///
/// See `docs/human/requirements/20260903-UI-Native Window Controls Across
/// Workbench And Playback.md`.
@MainActor
enum AppWindowControls {
    enum Placement: Equatable {
        /// The Workbench: always shown.
        case workbench
        /// The playback page: shown with the Player UI, and kept shown while a
        /// playback layer is open.
        case playback(isVisible: Bool)

        fileprivate var isHidden: Bool {
            if case .playback(let isVisible) = self {
                return !isVisible
            }
            return false
        }
    }

    /// From the close button's leading edge to the zoom button's trailing
    /// edge, native spacing included. Layouts reserve this much after the
    /// inset; there is no token for it.
    private(set) static var clusterWidth: CGFloat = 0

    private static weak var window: NSWindow?
    private static var placement: Placement = .workbench
    /// The system owns the titlebar in fullscreen; placements wait until it
    /// is handed back.
    private static var isSystemTitlebar = false
    private static var nativeLeadingEdge: CGFloat = 0
    private static var nativeTitlebarHeight: CGFloat = 0

    private static let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

    static func attach(to window: NSWindow) {
        self.window = window
        if let close = window.standardWindowButton(.closeButton),
           let zoom = window.standardWindowButton(.zoomButton) {
            nativeLeadingEdge = close.frame.minX
            clusterWidth = zoom.frame.maxX - close.frame.minX
        }
        nativeTitlebarHeight = window.frame.height - window.contentLayoutRect.height
        apply()
    }

    static func place(_ placement: Placement) {
        guard self.placement != placement else {
            return
        }
        self.placement = placement
        apply()
    }

    // MARK: - Fullscreen
    //
    // The buttons are hidden through both transitions, so neither animation
    // draws them at the native corner. In fullscreen they are shown for the
    // system's own titlebar; after the exit they take the page's place again.

    static func windowWillEnterFullScreen() {
        isSystemTitlebar = true
        setNative(hidden: true)
    }

    static func windowDidEnterFullScreen() {
        setNative(hidden: false)
    }

    static func windowWillExitFullScreen() {
        setNative(hidden: true)
    }

    static func windowDidLeaveSystemTitlebar() {
        isSystemTitlebar = false
        apply()
    }

    private static func apply() {
        guard !isSystemTitlebar else {
            return
        }
        set(
            inset: WorkbenchControlMetrics.redesignSpacing6,
            height: WorkbenchControlMetrics.redesignAppTopbarHeight,
            hidden: placement.isHidden
        )
    }

    private static func setNative(hidden: Bool) {
        set(inset: nativeLeadingEdge, height: nativeTitlebarHeight, hidden: hidden)
    }

    private static func set(inset: CGFloat, height: CGFloat, hidden: Bool) {
        guard let window else {
            return
        }
        for type in buttons {
            window.standardWindowButton(type)?.isHidden = hidden
        }
        // Without the setters the buttons keep their native place; nothing
        // else is tried.
        guard window.responds(to: #selector(TitlebarPlacing.setTitlebarHeight(_:))),
              window.responds(to: #selector(TitlebarPlacing.setStandardWindowButtonGroupOffset(_:)))
        else {
            return
        }
        let placing = unsafeBitCast(window, to: TitlebarPlacing.self)
        placing.setTitlebarHeight(height)
        placing.setStandardWindowButtonGroupOffset(NSSize(width: inset - nativeLeadingEdge, height: 0))
    }
}

/// The two private `NSWindow` setters, measured on macOS 15.5.
@objc private protocol TitlebarPlacing {
    @objc(setTitlebarHeight:) func setTitlebarHeight(_ height: CGFloat)
    @objc(setStandardWindowButtonGroupOffset:) func setStandardWindowButtonGroupOffset(_ offset: NSSize)
}
