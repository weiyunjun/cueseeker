import AppKit
import Combine

@MainActor
final class TitlebarControlsCoordinator: NSObject {
    private weak var window: NSWindow?
    private let appState: AppState
    private let sidebarWidth: CGFloat
    private let expandedToggleTrailing: CGFloat = 24
    private let collapsedToggleGap: CGFloat = 10
    private let animationDuration: TimeInterval = 0.22

    private let toggleButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "")
    private var cancellables: Set<AnyCancellable> = []
    private var expandedToggleConstraint: NSLayoutConstraint?
    private var collapsedToggleConstraint: NSLayoutConstraint?
    private var titleCenterConstraint: NSLayoutConstraint?

    init(window: NSWindow, appState: AppState, sidebarWidth: CGFloat) {
        self.window = window
        self.appState = appState
        self.sidebarWidth = sidebarWidth
        super.init()

        installControls()
        bindState()
    }

    @objc
    private func toggleSidebar(_ sender: Any?) {
        appState.toggleSidebar()
    }

    private func installControls() {
        guard let window,
              let zoomButton = window.standardWindowButton(.zoomButton),
              let titlebarView = zoomButton.superview else {
            return
        }

        configureToggleButton()
        configureTitleLabel()

        titlebarView.addSubview(toggleButton)
        titlebarView.addSubview(titleLabel)

        let expandedToggleConstraint = toggleButton.centerXAnchor.constraint(
            equalTo: titlebarView.leadingAnchor,
            constant: sidebarWidth - expandedToggleTrailing
        )
        let collapsedToggleConstraint = toggleButton.leadingAnchor.constraint(
            equalTo: zoomButton.trailingAnchor,
            constant: collapsedToggleGap
        )
        let titleCenterConstraint = titleLabel.centerXAnchor.constraint(
            equalTo: titlebarView.centerXAnchor,
            constant: appState.isSidebarVisible ? sidebarWidth / 2 : 0
        )

        self.expandedToggleConstraint = expandedToggleConstraint
        self.collapsedToggleConstraint = collapsedToggleConstraint
        self.titleCenterConstraint = titleCenterConstraint

        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: 28),
            toggleButton.heightAnchor.constraint(equalToConstant: 28),
            toggleButton.centerYAnchor.constraint(equalTo: zoomButton.centerYAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: zoomButton.centerYAnchor),
            titleCenterConstraint
        ])

        applySidebarVisibility(appState.isSidebarVisible, animated: false)
    }

    private func configureToggleButton() {
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.image = NSImage(
            systemSymbolName: "sidebar.left",
            accessibilityDescription: "Toggle Sidebar"
        )
        toggleButton.imagePosition = .imageOnly
        toggleButton.isBordered = false
        toggleButton.target = self
        toggleButton.action = #selector(toggleSidebar(_:))
        toggleButton.setButtonType(.momentaryPushIn)
    }

    private func configureTitleLabel() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = appState.selectedSection.title
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func bindState() {
        appState.$isSidebarVisible
            .sink { [weak self] isVisible in
                self?.applySidebarVisibility(isVisible, animated: true)
            }
            .store(in: &cancellables)

        appState.$selectedSection
            .sink { [weak self] section in
                self?.titleLabel.stringValue = section.title
            }
            .store(in: &cancellables)
    }

    private func applySidebarVisibility(_ isVisible: Bool, animated: Bool) {
        if isVisible {
            collapsedToggleConstraint?.isActive = false
            expandedToggleConstraint?.isActive = true
        } else {
            expandedToggleConstraint?.isActive = false
            collapsedToggleConstraint?.isActive = true
        }

        titleCenterConstraint?.constant = isVisible ? sidebarWidth / 2 : 0
        toggleButton.toolTip = isVisible ? "Hide Sidebar" : "Show Sidebar"

        guard animated, let titlebarView = toggleButton.superview else {
            toggleButton.superview?.layoutSubtreeIfNeeded()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            titlebarView.layoutSubtreeIfNeeded()
        }
    }
}
