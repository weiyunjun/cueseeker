import AppKit
import CueSeekerCore
import SwiftUI

@MainActor
final class FileDetailDialogSession: ObservableObject, Identifiable {
    enum DetailKind: Equatable {
        case folder(FileDetailFolderInfo)
        case video(FileDetailVideoInfo)
        case subtitle(FileDetailSubtitleInfo)
    }

    let id = UUID()
    let pairedItems: [FileDetailPairedItem]
    @Published private(set) var kind: DetailKind
    @Published private(set) var selectedIndex: Int

    init(kind: DetailKind) {
        self.kind = kind
        switch kind {
        case .folder:
            self.pairedItems = []
            self.selectedIndex = 0
        case .video(let info):
            self.pairedItems = [.video(info)]
            self.selectedIndex = 0
        case .subtitle(let info):
            self.pairedItems = [.subtitle(info)]
            self.selectedIndex = 0
        }
    }

    init(pairedItems: [FileDetailPairedItem], initialSelectedIndex: Int = 0) {
        precondition(!pairedItems.isEmpty, "pairedItems must not be empty")
        let clampedIndex = min(max(0, initialSelectedIndex), pairedItems.count - 1)
        self.pairedItems = pairedItems
        self.selectedIndex = clampedIndex
        self.kind = Self.detailKind(for: pairedItems[clampedIndex])
    }

    var isFileDetail: Bool {
        switch kind {
        case .folder:
            return false
        case .video, .subtitle:
            return true
        }
    }

    var dialogTitle: String {
        switch kind {
        case .folder:
            return L("file_detail.folder_title")
        case .video, .subtitle:
            return L("file_detail.title")
        }
    }

    var fileName: String {
        switch kind {
        case .folder(let info):
            return info.name
        case .video(let info):
            return info.name
        case .subtitle(let info):
            return info.name
        }
    }

    var icon: AppIcon {
        switch kind {
        case .folder(let info):
            return FileFolderGroupingResolver.folderIcon(forFolderPath: info.path)
        case .video:
            return .video
        case .subtitle:
            return .subtitles
        }
    }

    var selectedItemID: String {
        switch kind {
        case .folder(let info):
            return "folder:\(info.path)"
        case .video(let info):
            return "video:\(info.path)"
        case .subtitle(let info):
            return "subtitle:\(info.path)"
        }
    }

    func selectItem(at index: Int) {
        guard pairedItems.indices.contains(index) else { return }
        selectedIndex = index
        kind = Self.detailKind(for: pairedItems[index])
    }

    private static func detailKind(for item: FileDetailPairedItem) -> DetailKind {
        switch item {
        case .video(let info):
            return .video(info)
        case .subtitle(let info):
            return .subtitle(info)
        }
    }
}

struct WorkbenchFileDetailDialog: View {
    private static let menuCoordinateSpaceName = "fileDetailPairedMenuSpace"

    @ObservedObject var session: FileDetailDialogSession
    var menuGate: MenuGate? = nil
    let onClose: () -> Void

    @Environment(\.workbenchDialogAvailableSize) private var availableSize
    @Environment(\.interfaceLayers) private var interfaceLayers
    @State private var languageRevision = 0
    @State private var isMenuOpen = false
    @State private var triggerFrame: CGRect = .zero
    @State private var dialogSize: CGSize = .zero
    @State private var menuPanelHeight: CGFloat = 0
    @StateObject private var menuHighlight = MenuHighlightModel()
    @State private var scrollController = WorkbenchScrollViewController()

    private var resolvedMenuGate: MenuGate? {
        menuGate ?? interfaceLayers?.menuGate
    }

    var body: some View {
        let _ = languageRevision
        if case .folder(let folderInfo) = session.kind {
            WorkbenchDetailDialogContainer(
                dialogTitle: session.dialogTitle,
                icon: session.icon,
                headerTitle: session.fileName,
                onClose: onClose
            ) {
                folderContent(folderInfo)
            }
        } else {
            fileDetailDialogBody
        }
    }

    private var fileDetailDialogBody: some View {
        WorkbenchDialogColumn(
            spacing: WorkbenchControlMetrics.redesignSpacing4,
            maxHeight: availableSize.height - WorkbenchControlMetrics.redesignDialogTopPadding
        ) {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                WorkbenchDialogHeader(title: session.dialogTitle)

                FileDetailPairedSwitcherTrigger(
                    icon: session.icon,
                    title: session.fileName,
                    isOpen: isMenuOpen,
                    action: {
                        toggleMenu()
                    }
                )
                .background(
                    GeometryReader { triggerProxy in
                        Color.clear
                            .onAppear {
                                triggerFrame = triggerProxy.frame(in: .named(Self.menuCoordinateSpaceName))
                            }
                            .onChange(of: triggerProxy.frame(in: .named(Self.menuCoordinateSpaceName))) { newFrame in
                                triggerFrame = newFrame
                            }
                    }
                )
                .accessibilityIdentifier("file-detail-paired-switcher-trigger")
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            WorkbenchScrollView(controller: scrollController) {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    switch session.kind {
                    case .folder(let folderInfo):
                        folderContent(folderInfo)
                    case .video(let videoInfo):
                        videoContent(videoInfo)
                    case .subtitle(let subtitleInfo):
                        subtitleContent(subtitleInfo)
                    }
                }
                .id(session.selectedItemID)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
                .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .background(
            GeometryReader { dialogProxy in
                Color.clear
                    .onAppear {
                        dialogSize = dialogProxy.size
                    }
                    .onChange(of: dialogProxy.size) { newSize in
                        dialogSize = newSize
                    }
            }
        )
        .coordinateSpace(name: Self.menuCoordinateSpaceName)
        .overlay(alignment: .topLeading) {
            if isMenuOpen {
                let menuOriginX = triggerFrame.width > 0
                    ? triggerFrame.minX
                    : WorkbenchControlMetrics.redesignDialogInset
                let menuOriginY = triggerFrame.height > 0
                    ? (triggerFrame.maxY + WorkbenchControlMetrics.redesignSpacing1)
                    : 116
                let menuWidth = triggerFrame.width > 0
                    ? triggerFrame.width
                    : (WorkbenchControlMetrics.redesignDialogWidthXLarge - 2 * WorkbenchControlMetrics.redesignDialogInset)
                let availableBelow = dialogSize.height > menuOriginY
                    ? max(120, dialogSize.height - menuOriginY - WorkbenchControlMetrics.redesignSpacing4)
                    : MenuMetrics.maximumHeight
                let maxMenuHeight = min(MenuMetrics.maximumHeight, availableBelow)
                let menuFrame = CGRect(
                    x: menuOriginX,
                    y: menuOriginY,
                    width: menuWidth,
                    height: max(
                        menuPanelHeight,
                        WorkbenchControlMetrics.redesignMenuItemHeight + 2 * MenuMetrics.padding
                    )
                )

                ZStack(alignment: .topLeading) {
                    MenuGateClientView(
                        gate: resolvedMenuGate,
                        owner: .dialog,
                        kind: .excerptDestinationMenu,
                        menuFrame: menuFrame,
                        anchorFrame: triggerFrame,
                        handleKey: { keyCode, _ in
                            handleMenuKey(keyCode: keyCode)
                        },
                        dismiss: { _ in
                            dismissMenu()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    FileDetailPairedSwitcherMenuPopover(
                        items: session.pairedItems,
                        width: menuWidth,
                        maximumHeight: maxMenuHeight,
                        highlight: menuHighlight,
                        onHeightChange: { height in
                            menuPanelHeight = height
                        },
                        onSelect: { index in
                            selectPairedItem(at: index)
                        }
                    )
                    .offset(x: menuOriginX, y: menuOriginY)
                }
                .zIndex(1000)
            }
        }
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(
            closesOnEscape: !isMenuOpen,
            onClose: {
                dismissMenu()
                onClose()
            }
        )
        .subtitleTableTextSelectionNonInteractiveRegion()
        .onReceive(NotificationCenter.default.publisher(for: .cueSeekerAppLanguageChanged)) { _ in
            languageRevision &+= 1
        }
        .onChange(of: session.selectedIndex) { _ in
            scrollController.scrollToTop()
        }
        .onDisappear {
            dismissMenu()
        }
    }

    func toggleMenu() {
        if isMenuOpen {
            dismissMenu()
        } else {
            menuHighlight.open(selectablePositions: Array(session.pairedItems.indices))
            isMenuOpen = true
        }
    }

    func dismissMenu() {
        guard isMenuOpen else { return }
        isMenuOpen = false
        menuHighlight.close()
    }

    func selectPairedItem(at index: Int) {
        dismissMenu()
        session.selectItem(at: index)
        scrollController.scrollToTop()
    }

    @discardableResult
    func handleMenuKey(keyCode: UInt16) -> Bool {
        guard isMenuOpen else { return false }
        return menuHighlight.handleStandardMenuKey(
            keyCode: keyCode,
            onActivate: {
                if let highlighted = menuHighlight.activeTriggerPosition {
                    selectPairedItem(at: highlighted)
                }
            },
            onDismiss: { dismissMenu() }
        )
    }

    // MARK: - Folder Content

    @ViewBuilder
    private func folderContent(_ info: FileDetailFolderInfo) -> some View {
        SettingsGroup(title: L("file_detail.section.folder_info")) {
            FileDetailRow(
                label: L("file_detail.path"),
                value: RemoteAddressParser.decodedDisplayAddress(info.path)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.folder_count"),
                value: "\(info.folderCount)"
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.video_count"),
                value: "\(info.videoCount)"
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.subtitle_count"),
                value: "\(info.subtitleCount)"
            )
        }

        SettingsGroup(title: L("file_detail.section.index_info")) {
            FileDetailRow(
                label: L("file_detail.added"),
                value: Self.dateText(info.addedAt)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.updated"),
                value: Self.dateText(info.updatedAt)
            )
        }
    }

    // MARK: - Video Content

    @ViewBuilder
    private func videoContent(_ info: FileDetailVideoInfo) -> some View {
        SettingsGroup(title: L("file_detail.video")) {
            FileDetailRow(
                label: L("file_detail.resolution"),
                value: Self.resolutionText(width: info.videoWidth, height: info.videoHeight)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.frame_rate"),
                value: Self.frameRateText(info.frameRate)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.codec"),
                value: Self.codecText(info.videoCodec)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.bit_depth"),
                value: Self.bitDepthText(info.videoBitDepth)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.pixel_format"),
                value: Self.pixelFormatText(info.videoPixelFormat)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.bitrate"),
                value: Self.bitrateText(fileSize: info.fileSize, duration: info.duration)
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.duration"),
                value: Self.durationText(info.duration)
            )
        }

        let validAudioTracks = Self.validAudioTrackPropertyGroups(for: info.audioTracks)
        ForEach(Array(validAudioTracks.enumerated()), id: \.offset) { index, items in
            SettingsGroup(title: "\(L("file_detail.audio")) #\(index + 1)") {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    if itemIndex > 0 {
                        SettingsRowDivider()
                    }
                    FileDetailRow(label: L(item.labelKey), value: item.value)
                }
            }
        }

        SettingsGroup(title: L("file_detail.subtitles")) {
            WorkbenchDetailIndexedRows(
                values: info.subtitles.map { URL.fromMediaPath($0.subtitlePath).lastPathComponent }
            )
        }

        fileDetailsSection(
            path: info.path,
            fileSize: info.fileSize,
            containerFormat: info.containerFormat,
            createdAt: info.createdAt,
            modifiedAt: info.modifiedAt
        )
    }

    static func validAudioTrackPropertyGroups(
        for tracks: [VideoAudioTrack]
    ) -> [[MediaDetailPropertyItem]] {
        let locale = AppLocalization.locale
        return tracks
            .map { MediaDetailFormatter.audioTrackProperties(for: $0, locale: locale) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Subtitle Content

    @ViewBuilder
    private func subtitleContent(_ info: FileDetailSubtitleInfo) -> some View {
        SettingsGroup(title: L("file_detail.subtitle_specs")) {
            FileDetailRow(label: L("file_detail.encoding"), value: info.encoding)
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.raw_lines"),
                value: "\(info.rawCueCount)"
            )
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.valid_lines"),
                value: "\(info.cueCount)"
            )
        }

        SettingsGroup(title: L("file_detail.associated_video")) {
            let videoNames: [String] = {
                guard let videoPath = info.associatedVideoPath, !videoPath.isEmpty else { return [] }
                return [URL.fromMediaPath(videoPath).lastPathComponent]
            }()
            WorkbenchDetailIndexedRows(values: videoNames)
        }

        fileDetailsSection(
            path: info.path,
            fileSize: info.fileSize,
            createdAt: info.createdAt,
            modifiedAt: info.modifiedAt
        )
    }

    // MARK: - File Details Common Section

    private func fileDetailsSection(
        path: String,
        fileSize: Int64,
        containerFormat: String? = nil,
        createdAt: Date?,
        modifiedAt: Date?
    ) -> some View {
        SettingsGroup(title: L("file_detail.file_details")) {
            FileDetailRow(label: L("file_detail.file_size"), value: Self.fileSizeText(fileSize))
            SettingsRowDivider()
            FileDetailRow(
                label: L("file_detail.format"),
                value: Self.fileFormatText(path: path, containerFormat: containerFormat)
            )
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.path"), value: path)
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.created"), value: Self.dateText(createdAt))
            SettingsRowDivider()
            FileDetailRow(label: L("file_detail.modified"), value: Self.dateText(modifiedAt))
        }
    }

    // MARK: - Format Helpers

    static func fileSizeText(_ bytes: Int64) -> String {
        MediaDetailFormatter.fileSizeText(bytes)
    }

    static func dateText(_ date: Date?) -> String {
        MediaDetailFormatter.dateText(date)
    }

    static func durationText(_ duration: Double?) -> String {
        MediaDetailFormatter.durationText(duration)
    }

    static func resolutionText(width: Int?, height: Int?) -> String {
        MediaDetailFormatter.resolutionText(width: width, height: height)
    }

    static func frameRateText(_ fps: Double?) -> String {
        MediaDetailFormatter.frameRateText(fps)
    }

    static func bitrateText(fileSize: Int64, duration: Double?) -> String {
        MediaDetailFormatter.bitrateText(fileSize: fileSize, duration: duration)
    }

    static func codecText(_ codec: String?) -> String {
        MediaDetailFormatter.codecText(codec)
    }

    static func bitDepthText(_ bitDepth: Int?) -> String {
        MediaDetailFormatter.bitDepthText(bitDepth)
    }

    static func pixelFormatText(_ pixelFormat: String?) -> String {
        MediaDetailFormatter.pixelFormatText(pixelFormat)
    }

    static func channelsText(_ channels: Int?) -> String? {
        MediaDetailFormatter.channelsText(channels)
    }

    static func sampleRateText(_ sampleRate: Int?) -> String? {
        MediaDetailFormatter.sampleRateText(sampleRate)
    }

    static func audioBitDepthText(_ bitDepth: Int?) -> String? {
        MediaDetailFormatter.audioBitDepthText(bitDepth)
    }

    static func languageText(_ languageCode: String?) -> String? {
        MediaDetailFormatter.languageText(languageCode, locale: AppLocalization.locale)
    }

    static func fileFormatText(path: String, containerFormat: String? = nil) -> String {
        MediaDetailFormatter.fileFormatText(path: path, containerFormat: containerFormat)
    }
}

struct FileDetailPairedSwitcherTrigger: View {
    let icon: AppIcon
    let title: String
    let isOpen: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                WorkbenchCardIcon(
                    icon: icon,
                    size: WorkbenchControlMetrics.redesignDetailFileIconContainerSize
                )

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: 2 * WorkbenchControlMetrics.redesignDetailFileTitleLineHeight,
                        alignment: .leading
                    )

                AppIconImage(
                    .caretDown,
                    size: WorkbenchControlMetrics.redesignCardChevronSize
                )
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .frame(
                    width: WorkbenchControlMetrics.redesignCardChevronSize,
                    height: WorkbenchControlMetrics.redesignCardChevronSize
                )
            }
            .padding(.vertical, WorkbenchControlMetrics.redesignSpacing3)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                    style: .continuous
                )
                .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                    style: .continuous
                )
                .strokeBorder(
                    borderColor,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion()
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    static func resolvedBackgroundColor(isPressed: Bool, isOpen: Bool, isHovered: Bool) -> Color {
        if isPressed {
            return WorkbenchRedesignColors.bgPressed
        }
        if isOpen || isHovered {
            return WorkbenchRedesignColors.bgHover
        }
        return WorkbenchRedesignColors.tableBg
    }

    static func resolvedBorderColor(isPressed: Bool, isOpen: Bool, isHovered: Bool) -> Color {
        if isPressed || isOpen || isHovered {
            return WorkbenchRedesignColors.borderControlHover
        }
        return WorkbenchRedesignColors.borderControl
    }

    private var backgroundColor: Color {
        Self.resolvedBackgroundColor(isPressed: isPressed, isOpen: isOpen, isHovered: isHovered)
    }

    private var borderColor: Color {
        Self.resolvedBorderColor(isPressed: isPressed, isOpen: isOpen, isHovered: isHovered)
    }
}

struct FileDetailPairedSwitcherMenuPopover: View {
    let items: [FileDetailPairedItem]
    let width: CGFloat
    let maximumHeight: CGFloat
    @ObservedObject var highlight: MenuHighlightModel
    var onHeightChange: ((CGFloat) -> Void)? = nil
    let onSelect: (Int) -> Void

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let cornerRadius = WorkbenchControlMetrics.redesignMenuRadius
        ScrollViewReader { proxy in
            FileDetailPairedMenuHeightCap(width: width, height: maximumHeight) {
                WorkbenchScrollView(
                    scrollbarInset: MenuMetrics.scrollbarOuterGap
                ) {
                    FileDetailPairedMenuItemStack(
                        menuWidth: width,
                        padding: MenuMetrics.padding,
                        strip: MenuMetrics.scrollbarStrip,
                        cap: maximumHeight
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { position, item in
                                FileDetailPairedMenuItemRow(
                                    title: item.name,
                                    icon: item.isVideo ? .video : .subtitles,
                                    isHighlighted: highlight.isSelected(position),
                                    isRowHovered: highlight.isHovered(position),
                                    isAccessibilityFocused: highlight.isAccessibilityFocused(position),
                                    action: {
                                        onSelect(position)
                                    },
                                    onHoverChange: { isHovered in
                                        highlight.noteHover(isHovered, at: position)
                                    }
                                )
                                .id(position)
                            }
                        }
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .onAppear {
                                        contentHeight = contentGeo.size.height
                                    }
                                    .onChange(of: contentGeo.size.height) { newHeight in
                                        contentHeight = newHeight
                                    }
                            }
                        )
                    }
                }
            }
            .frame(width: width)
            .background(
                GeometryReader { panelGeo in
                    Color.clear
                        .onAppear {
                            onHeightChange?(panelGeo.size.height)
                        }
                        .onChange(of: panelGeo.size.height) { newHeight in
                            onHeightChange?(newHeight)
                        }
                }
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(WorkbenchRedesignColors.bgPopover)
                    .shadowToken(
                        WorkbenchRedesignColors.shadowPopover,
                        cornerRadius: cornerRadius
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        WorkbenchRedesignColors.borderControl,
                        lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                    )
            )
            .subtitleTableTextSelectionNonInteractiveRegion(
                cornerRadius: cornerRadius
            )
            .onChange(of: highlight.keyboardMoveCount) { _ in
                guard contentHeight + 2 * MenuMetrics.padding > floor(maximumHeight),
                      let position = highlight.revealPosition
                else {
                    return
                }
                proxy.scrollTo(position)
            }
        }
    }
}

struct FileDetailPairedMenuItemRow: View {
    let title: String
    let icon: AppIcon
    var isHighlighted = false
    var isRowHovered = false
    var isAccessibilityFocused = false
    let action: () -> Void
    var onHoverChange: ((Bool) -> Void)?

    private static let iconFirstLineTopOffset: CGFloat = max(
        0,
        (WorkbenchControlMetrics.redesignDetailFileTitleLineHeight
            - WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS) / 2
    )

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing2) {
                AppIconImage(
                    icon,
                    size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                )
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .frame(
                    width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS,
                    height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                )
                .padding(.top, Self.iconFirstLineTopOffset)

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
            .padding(.vertical, WorkbenchControlMetrics.redesignSettingsRowVerticalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: WorkbenchControlMetrics.redesignMenuItemHeight,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                    style: .continuous
                )
                .fill(isHighlighted || isRowHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
            )
            .overlay(
                Group {
                    if isAccessibilityFocused {
                        RoundedRectangle(
                            cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius
                                + WorkbenchControlMetrics.redesignFocusRingPathExpansion,
                            style: .continuous
                        )
                        .stroke(
                            WorkbenchRedesignColors.focusRing,
                            lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                        )
                        .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                        .allowsHitTesting(false)
                    }
                }
            )
            .contentShape(Rectangle())
            .onHover { inside in
                onHoverChange?(inside)
            }
        }
        .buttonStyle(StaticButtonStyle())
        .subtitleTableTextSelectionInteractiveRegion()
        .focusable(false)
    }
}

private struct FileDetailPairedMenuHeightCap: Layout {
    let width: CGFloat
    let height: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let resolvedWidth = proposal.width ?? width
        let wanted = subview.sizeThatFits(ProposedViewSize(width: resolvedWidth, height: nil))
        return CGSize(
            width: resolvedWidth,
            height: max(0, min(ceil(wanted.height), floor(height)))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        subview.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}

private struct FileDetailPairedMenuItemStack: Layout {
    let menuWidth: CGFloat
    let padding: CGFloat
    let strip: CGFloat
    let cap: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let resolvedMenuWidth = proposal.width ?? menuWidth
        let (_, contentHeight) = resolvedLayout(
            for: subview,
            menuWidth: resolvedMenuWidth
        )
        return CGSize(
            width: resolvedMenuWidth,
            height: contentHeight + 2 * padding
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        let (itemWidth, contentHeight) = resolvedLayout(
            for: subview,
            menuWidth: bounds.width
        )
        subview.place(
            at: CGPoint(x: bounds.minX + padding, y: bounds.minY + padding),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: itemWidth,
                height: contentHeight
            )
        )
    }

    private func resolvedLayout(
        for subview: LayoutSubview,
        menuWidth: CGFloat
    ) -> (itemWidth: CGFloat, contentHeight: CGFloat) {
        let unreservedWidth = max(0, menuWidth - 2 * padding)
        let unreservedHeight = ceil(
            subview.sizeThatFits(ProposedViewSize(width: unreservedWidth, height: nil)).height
        )
        guard unreservedHeight + 2 * padding > floor(cap) else {
            return (unreservedWidth, unreservedHeight)
        }
        let reservedWidth = max(0, menuWidth - 2 * padding - strip)
        let reservedHeight = ceil(
            subview.sizeThatFits(ProposedViewSize(width: reservedWidth, height: nil)).height
        )
        return (reservedWidth, reservedHeight)
    }
}
