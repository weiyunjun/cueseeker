import AppKit
import SwiftUI
import CueSeekerCore

protocol RemoteFolderDialogConfigProtocol: Equatable, Sendable {
    var name: String { get }
    var rootURL: URL { get }
    func scopedConfig(for folderURL: URL) -> Self
}

extension WebDAVRootConfig: RemoteFolderDialogConfigProtocol {}
extension SMBRootConfig: RemoteFolderDialogConfigProtocol {}
extension FTPRootConfig: RemoteFolderDialogConfigProtocol {}
extension NFSRootConfig: RemoteFolderDialogConfigProtocol {}

enum RemoteFolderDialogStep: Equatable {
    case connection
    case browser
}

struct RemoteFolderBreadcrumbNode: Identifiable, Equatable {
    let url: URL
    let title: String

    var id: String {
        url.mediaPath
    }

    init(url: URL, title: String? = nil) {
        let normalized = url.standardizedMediaURL
        self.url = normalized
        if let title {
            self.title = title
        } else if normalized.isSMBURL {
            self.title = SMBAddress.defaultDisplayName(for: normalized)
        } else if normalized.isFTPURL {
            self.title = FTPAddress.defaultDisplayName(for: normalized)
        } else if normalized.isNFSURL {
            self.title = NFSAddress.defaultDisplayName(for: normalized)
        } else {
            self.title = WebDAVAddress.defaultDisplayName(for: normalized)
        }
    }
}

@MainActor
protocol RemoteFolderDialogSessionProtocol: AnyObject, ObservableObject, Identifiable where ID == UUID {
    associatedtype Config: RemoteFolderDialogConfigProtocol
    typealias Step = RemoteFolderDialogStep
    typealias BreadcrumbNode = RemoteFolderBreadcrumbNode

    var id: UUID { get }
    var step: RemoteFolderDialogStep { get set }
    var validationMessage: String? { get set }
    var isSubmitting: Bool { get set }

    var baseConfig: Config? { get set }
    var breadcrumbNodes: [RemoteFolderBreadcrumbNode] { get set }
    var items: [WebDAVBrowserItem] { get set }
    var selectedFolderPaths: Set<String> { get set }
    var existingRootFolders: [URL] { get set }
    var isLoadingDirectory: Bool { get set }
    var directoryErrorMessage: String? { get set }

    var validationTask: Task<Void, Never>? { get set }
    var directoryTask: Task<Void, Never>? { get set }

    var isAtHostRoot: Bool { get }
}

extension RemoteFolderDialogSessionProtocol {
    var isAtHostRoot: Bool {
        false
    }

    var currentDirectoryURL: URL? {
        breadcrumbNodes.last?.url ?? baseConfig?.rootURL
    }

    func isFolderAlreadyAdded(_ folderURL: URL) -> Bool {
        LibraryRootGroups.coveringRoot(
            of: folderURL.standardizedMediaURL,
            in: existingRootFolders
        ) != nil
    }

    func isFolderItemDisabled(_ item: WebDAVBrowserItem) -> Bool {
        guard item.kind == .folder else {
            return true
        }
        return isFolderAlreadyAdded(item.url)
    }

    var activeSelectedFolderItems: [WebDAVBrowserItem] {
        items.filter {
            $0.kind == .folder
                && !isFolderItemDisabled($0)
                && selectedFolderPaths.contains($0.id)
        }
    }

    var browserAddButtonTitle: String {
        let count = activeSelectedFolderItems.count
        if count == 0 {
            return L("remote.browser.add_current_folder")
        } else if count == 1 {
            return L("remote.browser.add_folders.one")
        } else {
            return L("remote.browser.add_folders.other", count)
        }
    }

    var canAddInBrowser: Bool {
        guard step == .browser,
              !isLoadingDirectory,
              directoryErrorMessage == nil,
              let currentDirectoryURL,
              baseConfig != nil
        else {
            return false
        }
        if !activeSelectedFolderItems.isEmpty {
            return true
        }
        if isAtHostRoot {
            return false
        }
        if isFolderAlreadyAdded(currentDirectoryURL) {
            return false
        }
        let folderItems = items.filter { $0.kind == .folder }
        if !folderItems.isEmpty && folderItems.allSatisfy({ isFolderItemDisabled($0) }) {
            return false
        }
        return true
    }

    func enterBrowser(config: Config, initialItems: [WebDAVBrowserItem]) {
        baseConfig = config
        breadcrumbNodes = [BreadcrumbNode(url: config.rootURL, title: config.name)]
        items = initialItems
        selectedFolderPaths.removeAll()
        isLoadingDirectory = false
        directoryErrorMessage = nil
        step = .browser
    }

    func toggleFolderSelection(_ item: WebDAVBrowserItem) {
        guard item.kind == .folder, !isFolderItemDisabled(item) else {
            return
        }
        if selectedFolderPaths.contains(item.id) {
            selectedFolderPaths.remove(item.id)
        } else {
            selectedFolderPaths.insert(item.id)
        }
    }

    func targetFoldersToAdd() -> [URL] {
        guard let currentDirectoryURL else {
            return []
        }
        let selectedItems = activeSelectedFolderItems
        if !selectedItems.isEmpty {
            return selectedItems.map { $0.url.standardizedMediaURL }
        }
        guard canAddInBrowser else {
            return []
        }
        return [currentDirectoryURL.standardizedMediaURL]
    }

    func returnToConnection() {
        directoryTask?.cancel()
        directoryTask = nil
        selectedFolderPaths.removeAll()
        isLoadingDirectory = false
        directoryErrorMessage = nil
        step = .connection
    }

    func cancelValidation() {
        validationTask?.cancel()
        validationTask = nil
        directoryTask?.cancel()
        directoryTask = nil
        isSubmitting = false
        isLoadingDirectory = false
    }
}

struct RemoteFolderDialogStyle {
    let titleKey: String
    let connectTitleKey: String
    let emptyFolderItemsKey: String
    let folderIcon: AppIcon
    let connectAccessibilityID: String
    let backAccessibilityID: String
    let addAccessibilityID: String
    let browserFallbackID: String
}

struct RemoteFolderDialogContainer<
    Session: RemoteFolderDialogSessionProtocol,
    ConnectionFields: View
>: View {
    @ObservedObject var session: Session
    let style: RemoteFolderDialogStyle
    let onConfirm: () -> Void
    let onClose: () -> Void
    var onBack: (() -> Void)? = nil
    var onOpenFolder: ((WebDAVBrowserItem) -> Void)? = nil
    var onSelectBreadcrumb: ((RemoteFolderBreadcrumbNode) -> Void)? = nil
    @ViewBuilder let connectionFields: () -> ConnectionFields

    @Environment(\.workbenchDialogAvailableSize) private var availableSize
    @Environment(\.workbenchDialogID) private var dialogID

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            Group {
                switch session.step {
                case .connection:
                    connectionStepView(accessibility: accessibility)
                case .browser:
                    browserStepView(accessibility: accessibility)
                }
            }
        }
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private func connectionStepView(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L(style.titleKey))

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                connectionFields()
            }

            connectionActions(accessibility: accessibility)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthMedium)
    }

    private func connectionActions(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isFocused: accessibility?.isDialogFocused(.remoteCancel, dialogID: dialogID) == true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L(style.connectTitleKey),
                showsSpinner: session.isSubmitting,
                isFocused: accessibility?.isDialogFocused(.remoteConnect, dialogID: dialogID) == true,
                action: submitConnectionIfIdle
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier(style.connectAccessibilityID)
        }
    }

    private func browserStepView(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L(style.titleKey))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            if !session.breadcrumbNodes.isEmpty {
                RemoteFolderBreadcrumbBar(
                    nodes: session.breadcrumbNodes,
                    dialogID: dialogID,
                    accessibility: accessibility,
                    onSelectNode: onSelectBreadcrumb
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }

            browserContent(accessibility: accessibility)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            browserActions(accessibility: accessibility)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .frame(height: min(WorkbenchControlMetrics.redesignTaskPanelHeight, availableSize.height))
    }

    @ViewBuilder
    private func browserContent(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        if session.isLoadingDirectory {
            ZStack {
                WorkbenchSpinner()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = session.directoryErrorMessage {
            WorkbenchEmptyHint(icon: .folderQuestion, message: errorMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.items.isEmpty {
            WorkbenchEmptyHint(icon: .folder, message: L(style.emptyFolderItemsKey))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WorkbenchScrollView {
                LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    ForEach(session.items) { item in
                        WebDAVBrowserCard(
                            item: item,
                            folderIcon: style.folderIcon,
                            isDisabled: item.kind == .folder && session.isFolderItemDisabled(item),
                            isSelected: item.kind == .folder && session.selectedFolderPaths.contains(item.id),
                            isCardFocused: item.kind == .folder && accessibility?.isDialogFocused(.remoteFolderCard(item.id), dialogID: dialogID) == true,
                            isEnterButtonFocused: item.kind == .folder && accessibility?.isDialogFocused(.remoteFolderEnterButton(item.id), dialogID: dialogID) == true,
                            onToggleSelection: {
                                session.toggleFolderSelection(item)
                            },
                            onOpenFolder: {
                                onOpenFolder?(item)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }
            .id(session.currentDirectoryURL?.mediaPath ?? style.browserFallbackID)
        }
    }

    private func browserActions(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchButton(
                title: L("common.back"),
                isFocused: accessibility?.isDialogFocused(.remoteBack, dialogID: dialogID) == true,
                action: {
                    if let onBack {
                        onBack()
                    } else {
                        session.returnToConnection()
                    }
                }
            )
            .accessibilityIdentifier(style.backAccessibilityID)

            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isFocused: accessibility?.isDialogFocused(.remoteCancel, dialogID: dialogID) == true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: session.browserAddButtonTitle,
                isFocused: accessibility?.isDialogFocused(.remoteAdd, dialogID: dialogID) == true,
                action: submitAddIfReady
            )
            .disabled(!session.canAddInBrowser)
            .accessibilityIdentifier(style.addAccessibilityID)
        }
    }

    private func submitConnectionIfIdle() {
        guard !session.isSubmitting else {
            return
        }
        onConfirm()
    }

    private func submitAddIfReady() {
        guard session.canAddInBrowser else {
            return
        }
        onConfirm()
    }
}

struct RemoteFolderBreadcrumbBar: View {
    let nodes: [RemoteFolderBreadcrumbNode]
    var dialogID: WorkbenchDialogAccessibilityID? = nil
    var accessibility: WorkbenchAccessibilityCoordinator? = nil
    var onSelectNode: ((RemoteFolderBreadcrumbNode) -> Void)? = nil

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    AppIconImage(
                        .caretRight,
                        size: WorkbenchControlMetrics.redesignBreadcrumbSeparatorSize
                    )
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                }

                if index < nodes.count - 1 {
                    BreadcrumbLink(
                        title: node.title,
                        isFocused: accessibility?.isDialogFocused(.remoteBreadcrumb(node.id), dialogID: dialogID) == true
                    ) {
                        onSelectNode?(node)
                    }
                } else {
                    Text(node.title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeBody,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WebDAVBrowserCard: View {
    static let enterButtonWidth: CGFloat =
        WorkbenchControlMetrics.redesignCardChevronSize
        + WorkbenchControlMetrics.redesignControlPaddingX * 2

    let item: WebDAVBrowserItem
    var folderIcon: AppIcon = .folderWebdav
    var isDisabled: Bool = false
    let isSelected: Bool
    var isCardFocused: Bool = false
    var isEnterButtonFocused: Bool = false
    let onToggleSelection: () -> Void
    let onOpenFolder: () -> Void

    @State private var isCardHovered = false
    @State private var isCardPressed = false
    @State private var isEnterButtonHovered = false
    @State private var isEnterButtonPressed = false

    var isFolder: Bool {
        item.kind == .folder
    }

    var isCardInteractive: Bool {
        isFolder && !isDisabled
    }

    var showsAddedBadge: Bool {
        isFolder && isDisabled
    }

    var showsEnterButton: Bool {
        isFolder
    }

    var icon: AppIcon {
        switch item.kind {
        case .folder:
            return folderIcon
        case .video:
            return .video
        case .subtitle:
            return .subtitles
        }
    }

    var backgroundFillColor: Color {
        Self.resolveBackgroundFillColor(
            isFolder: isFolder,
            isDisabled: isDisabled,
            isSelected: isSelected,
            isHovered: isCardHovered,
            isPressed: isCardPressed
        )
    }

    var borderStrokeColor: Color {
        Self.resolveBorderStrokeColor(
            isFolder: isFolder,
            isDisabled: isDisabled,
            isSelected: isSelected
        )
    }

    var enterButtonBackgroundFillColor: Color {
        Self.resolveEnterButtonBackgroundFillColor(
            isHovered: isEnterButtonHovered,
            isPressed: isEnterButtonPressed
        )
    }

    var enterButtonIconColor: Color {
        Self.resolveEnterButtonIconColor(
            isHovered: isEnterButtonHovered,
            isPressed: isEnterButtonPressed
        )
    }

    static func resolveBackgroundFillColor(
        isFolder: Bool,
        isDisabled: Bool = false,
        isSelected: Bool = false,
        isHovered: Bool,
        isPressed: Bool = false
    ) -> Color {
        guard isFolder, !isDisabled else {
            return WorkbenchRedesignColors.tableBg
        }
        if isSelected {
            if isPressed {
                return WorkbenchRedesignColors.filterChipSelectedBgPressed
            }
            if isHovered {
                return WorkbenchRedesignColors.filterChipSelectedBgHover
            }
            return WorkbenchRedesignColors.filterChipSelectedBg
        }
        if isPressed {
            return WorkbenchRedesignColors.fileFolderCardBgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.rowHover
        }
        return WorkbenchRedesignColors.tableBg
    }

    static func resolveBorderStrokeColor(
        isFolder: Bool,
        isDisabled: Bool = false,
        isSelected: Bool = false
    ) -> Color {
        if isFolder && !isDisabled && isSelected {
            return WorkbenchRedesignColors.filterChipSelectedContent
        }
        return WorkbenchRedesignColors.borderControl
    }

    static func resolveEnterButtonBackgroundFillColor(
        isHovered: Bool,
        isPressed: Bool = false
    ) -> Color {
        if isPressed {
            return WorkbenchRedesignColors.fileFolderCardBgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.rowHover
        }
        return WorkbenchRedesignColors.tableBg
    }

    static func resolveEnterButtonIconColor(
        isHovered: Bool,
        isPressed: Bool = false
    ) -> Color {
        (isHovered || isPressed)
            ? WorkbenchRedesignColors.textPrimary
            : WorkbenchRedesignColors.textMuted
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        )

        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                WorkbenchCardIcon(icon: icon)
                    .allowsHitTesting(false)

                Text(item.name)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                if showsAddedBadge {
                    WorkbenchBadge(
                        title: L("remote.browser.added"),
                        foregroundColor: WorkbenchRedesignColors.watchStatusFinishedText,
                        fillColor: WorkbenchRedesignColors.watchStatusFinishedBg
                    )
                    .allowsHitTesting(false)
                }
            }
            .padding(WorkbenchControlMetrics.redesignSpacing4)
            .frame(
                maxWidth: .infinity,
                minHeight: WorkbenchControlMetrics.redesignCardBaselineHeight,
                alignment: .leading
            )
            .background {
                ZStack {
                    shape.fill(backgroundFillColor)
                    WorkbenchAccessibilityScrollRevealProbe(isActive: isCardFocused)

                    if isCardInteractive {
                        Button(action: onToggleSelection) {
                            Color.clear
                                .contentShape(shape)
                        }
                        .buttonStyle(PressableButtonStyle(isPressed: $isCardPressed, isHovered: $isCardHovered))
                        .focusable(false)
                    }
                }
            }
            .overlay(
                shape.strokeBorder(
                    borderStrokeColor,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
                .allowsHitTesting(false)
            )
            .workbenchAccessibilityFocusRing(
                isFocused: isCardFocused,
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
            )
            .contentShape(shape)
            .onPointerHover { hovering in
                isCardHovered = isCardInteractive ? hovering : false
            }

            if showsEnterButton {
                Button(action: onOpenFolder) {
                    AppIconImage(
                        .caretRight,
                        size: WorkbenchControlMetrics.redesignCardChevronSize
                    )
                    .foregroundStyle(enterButtonIconColor)
                    .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
                    .frame(
                        width: Self.enterButtonWidth,
                        height: WorkbenchControlMetrics.redesignCardBaselineHeight
                    )
                    .contentShape(shape)
                }
                .buttonStyle(PressableButtonStyle(isPressed: $isEnterButtonPressed, isHovered: $isEnterButtonHovered))
                .focusable(false)
                .background {
                    ZStack {
                        shape.fill(enterButtonBackgroundFillColor)
                        WorkbenchAccessibilityScrollRevealProbe(isActive: isEnterButtonFocused)
                    }
                }
                .overlay(
                    shape.strokeBorder(
                        WorkbenchRedesignColors.borderControl,
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
                    .allowsHitTesting(false)
                )
                .workbenchAccessibilityFocusRing(
                    isFocused: isEnterButtonFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
                )
                .contentShape(shape)
                .onPointerHover { isEnterButtonHovered = $0 }
            } else {
                Color.clear
                    .frame(
                        width: Self.enterButtonWidth,
                        height: WorkbenchControlMetrics.redesignCardBaselineHeight
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}
