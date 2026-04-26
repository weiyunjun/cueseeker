import AppKit
import Combine

@MainActor
final class TitlebarControlsCoordinator: NSObject {
    private weak var window: NSWindow?
    private let appState: AppState
    private let collapsedToggleGap: CGFloat = 10

    private let toggleButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "")
    private var cancellables: Set<AnyCancellable> = []

    init(window: NSWindow, appState: AppState) {
        self.window = window
        self.appState = appState
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

        let toggleConstraint = toggleButton.leadingAnchor.constraint(
            equalTo: zoomButton.trailingAnchor,
            constant: collapsedToggleGap
        )
        let titleCenterConstraint = titleLabel.centerXAnchor.constraint(
            equalTo: titlebarView.centerXAnchor
        )

        NSLayoutConstraint.activate([
            toggleButton.widthAnchor.constraint(equalToConstant: 28),
            toggleButton.heightAnchor.constraint(equalToConstant: 28),
            toggleConstraint,
            toggleButton.centerYAnchor.constraint(equalTo: zoomButton.centerYAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: zoomButton.centerYAnchor),
            titleCenterConstraint
        ])

        applySidebarVisibility(appState.isSidebarVisible)
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
                self?.applySidebarVisibility(isVisible)
            }
            .store(in: &cancellables)

        appState.$selectedSection
            .sink { [weak self] section in
                self?.titleLabel.stringValue = section.title
            }
            .store(in: &cancellables)
    }

    private func applySidebarVisibility(_ isVisible: Bool) {
        toggleButton.toolTip = isVisible ? "Hide Sidebar" : "Show Sidebar"
    }
}
