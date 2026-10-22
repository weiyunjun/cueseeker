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

    var canAddInBrowser: Bool {
        guard step == .browser,
              !isLoadingDirectory,
              directoryErrorMessage == nil,
              currentDirectoryURL != nil,
              baseConfig != nil
        else {
            return false
        }
        if isAtHostRoot {
            return !selectedFolderPaths.isEmpty
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
        guard item.kind == .folder else {
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
        if selectedFolderPaths.isEmpty {
            if isAtHostRoot {
                return []
            }
            return [currentDirectoryURL.standardizedMediaURL]
        }
        return items
            .filter { $0.kind == .folder && selectedFolderPaths.contains($0.id) }
            .map { $0.url.standardizedMediaURL }
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
    let addTitleKey: String
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

    var body: some View {
        Group {
            switch session.step {
            case .connection:
                connectionStepView
            case .browser:
                browserStepView
            }
        }
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private var connectionStepView: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L(style.titleKey))

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                connectionFields()
            }

            connectionActions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthMedium)
    }

    private var connectionActions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L(style.connectTitleKey),
                showsSpinner: session.isSubmitting,
                action: submitConnectionIfIdle
            )
            .disabled(session.isSubmitting)
            .accessibilityIdentifier(style.connectAccessibilityID)
        }
    }

    private var browserStepView: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L(style.titleKey))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            if !session.breadcrumbNodes.isEmpty {
                RemoteFolderBreadcrumbBar(
                    nodes: session.breadcrumbNodes,
                    onSelectNode: onSelectBreadcrumb
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }

            browserContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            browserActions
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .frame(height: min(WorkbenchControlMetrics.redesignTaskPanelHeight, availableSize.height))
    }

    @ViewBuilder
    private var browserContent: some View {
        if session.isLoadingDirectory {
            ZStack {
                WorkbenchSpinner()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = session.directoryErrorMessage {
            WorkbenchEmptyHint(message: errorMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.items.isEmpty {
            WorkbenchEmptyHint(message: L(style.emptyFolderItemsKey))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WorkbenchScrollView {
                LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    ForEach(session.items) { item in
                        WebDAVBrowserCard(
                            item: item,
                            folderIcon: style.folderIcon,
                            isSelected: item.kind == .folder && session.selectedFolderPaths.contains(item.id),
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

    private var browserActions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchButton(
                title: L("common.back"),
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
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L(style.addTitleKey),
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
                    BreadcrumbLink(title: node.title) {
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
    let item: WebDAVBrowserItem
    var folderIcon: AppIcon = .folderWebdav
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onOpenFolder: () -> Void

    @State private var isHovered = false

    var isFolder: Bool {
        item.kind == .folder
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

    /// Selected folder cards use the accent tint background and have no hover effect;
    /// unselected folder cards use the standard row hover background on hover;
    /// file cards never highlight on hover.
    var backgroundFillColor: Color {
        Self.resolveBackgroundFillColor(
            isFolder: isFolder,
            isSelected: isSelected,
            isHovered: isHovered
        )
    }

    var borderStrokeColor: Color {
        Self.resolveBorderStrokeColor(
            isFolder: isFolder,
            isSelected: isSelected
        )
    }

    static func resolveBackgroundFillColor(
        isFolder: Bool,
        isSelected: Bool,
        isHovered: Bool
    ) -> Color {
        if isFolder && isSelected {
            return WorkbenchRedesignColors.libraryMediaCardHoverBg
        }
        if isFolder && isHovered {
            return WorkbenchRedesignColors.rowHover
        }
        return WorkbenchRedesignColors.tableBg
    }

    static func resolveBorderStrokeColor(
        isFolder: Bool,
        isSelected: Bool
    ) -> Color {
        if isFolder && isSelected {
            return WorkbenchRedesignColors.borderActive
        }
        return WorkbenchRedesignColors.borderControl
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        )

        Button {
            guard isFolder else {
                return
            }
            if let event = NSApp.currentEvent,
               (event.type == .leftMouseUp || event.type == .leftMouseDown),
               event.clickCount >= 2 {
                onOpenFolder()
            } else {
                onToggleSelection()
            }
        } label: {
            HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                WorkbenchCardIcon(icon: icon)

                Text(item.name)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isFolder {
                    AppIconImage(
                        .caretRight,
                        size: WorkbenchControlMetrics.redesignCardChevronSize
                    )
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .frame(
                        width: WorkbenchControlMetrics.redesignCardChevronSize,
                        height: WorkbenchControlMetrics.redesignIconButtonSize
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
            .background(shape.fill(backgroundFillColor))
            .overlay(
                shape.strokeBorder(
                    borderStrokeColor,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .disabled(!isFolder)
        .onPointerHover { hovering in
            isHovered = isFolder ? hovering : false
        }
    }
}
