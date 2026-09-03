import AppKit

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
/// Pages report their state here and place nothing themselves.
///
/// See `docs/human/requirements/20260903-UI-Native Window Controls Across
/// Workbench And Playback.md`.
@MainActor
enum AppWindowControls {
    enum Placement: Equatable {
        /// The Workbench top bar: inset `--spacing-6`, centred in
        /// `--height-app-topbar`.
        case workbench
        /// The player top bar: inset `--padding-player-topbar-x`, centred in
        /// `--height-player-topbar`. Shown with the Player UI, and kept shown
        /// while a playback layer is open.
        case playback(isVisible: Bool)
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

    static func windowWillEnterFullScreen() {
        isSystemTitlebar = true
        set(inset: nativeLeadingEdge, height: nativeTitlebarHeight, hidden: false)
    }

    static func windowDidLeaveSystemTitlebar() {
        isSystemTitlebar = false
        apply()
    }

    private static func apply() {
        guard !isSystemTitlebar else {
            return
        }
        switch placement {
        case .workbench:
            set(
                inset: WorkbenchControlMetrics.redesignSpacing6,
                height: WorkbenchControlMetrics.redesignAppTopbarHeight,
                hidden: false
            )
        case .playback(let isVisible):
            set(
                inset: PlaybackChromeMetrics.topbarHorizontalPadding,
                height: PlaybackChromeMetrics.videoTopBarHeight,
                hidden: !isVisible
            )
        }
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
