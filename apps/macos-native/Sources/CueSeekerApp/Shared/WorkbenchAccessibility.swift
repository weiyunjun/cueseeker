import AppKit
import CueSeekerCore
import CueSeekerPlayback
import SwiftUI

enum WorkbenchAccessibilityDebugLog {
    private static let lock = NSLock()
    private static let workspaceLogURL = URL(
        fileURLWithPath: "/Users/weiyunjun/Documents/Code/CueSeeker/logs/a11y-debug.log"
    )
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ event: String, _ details: String = "") {
        guard !ApplicationInfo.isRunningInUnitTestProcess else { return }
        let timestamp = isoFormatter.string(from: Date())
        let line = details.isEmpty
            ? "\(timestamp) [A11Y_DEBUG] \(event)\n"
            : "\(timestamp) [A11Y_DEBUG] \(event) | \(details)\n"
        AppLogger.shared.info(.app, "[A11Y_DEBUG] \(event)", details: details.isEmpty ? nil : details)
        NSLog("[A11Y_DEBUG] %@ | %@", event, details)
        lock.lock()
        defer { lock.unlock() }
        do {
            let dir = workspaceLogURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: workspaceLogURL.path) {
                try Data(line.utf8).write(to: workspaceLogURL, options: .atomic)
            } else {
                let handle = try FileHandle(forWritingTo: workspaceLogURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            }
        } catch {
            // Ignore file write errors in debug helper
        }
    }

    static func ptr(_ object: AnyObject?) -> String {
        guard let object else { return "nil" }
        return String(describing: Unmanaged.passUnretained(object).toOpaque())
    }
}

enum SchemaWorkbenchSelectionActionID: String, Hashable {
    case exportToAnki = "anki"
    case copyDeepLinks = "copy-deep-links"
    case copyTable = "copy-table"
    case moveTo = "move-to"
    case delete = "delete"
}

enum WorkbenchDialogAccessibilityID: String, Equatable, Hashable {
    case editCover = "editCover"
    case excerptListEditor = "excerptListEditor"
    case rename = "rename"
    case webdav = "webdav"
    case smb = "smb"
    case ftp = "ftp"
    case nfs = "nfs"
    case ankiExport = "ankiExport"
    case filter = "filter"
    case confirmation = "confirmation"
    case settingsConfirmation = "settingsConfirmation"
    case fileDetail = "fileDetail"
    case taskPanel = "taskPanel"
    case taskDetail = "taskDetail"
}

enum SettingsNumberFieldID: String, CaseIterable, Equatable, Hashable {
    case autoSwitchGap
    case subtitleSize
    case subtitleLetterSpacing
    case subtitleLineSpacing
    case subtitleMarginX
    case subtitleMarginY
    case subtitleOutlineWidth
    case subtitleBackgroundOpacity
    case subtitleBlur
    case subtitleShadowOpacity
    case subtitleShadowOffset
}

enum SettingsTextInputKind: Equatable, Hashable {
    case numberField(SettingsNumberFieldID)
    case subtitleColorField(SettingsSubtitleCategory.ColorFieldID)

    static var allCases: [SettingsTextInputKind] {
        SettingsNumberFieldID.allCases.map { .numberField($0) }
            + [
                .subtitleColorField(.textColor),
                .subtitleColorField(.outlineColor),
                .subtitleColorField(.backgroundColor),
                .subtitleColorField(.shadowColor),
            ]
    }

    var settingsTarget: SettingsAccessibilityTarget {
        switch self {
        case .numberField(let id):
            return .numberField(id)
        case .subtitleColorField(let id):
            return .subtitleColorField(id)
        }
    }
}

enum SettingsAccessibilityTarget: Equatable, Hashable {
    // Sidebar (L-02.2)
    case sidebarCategory(SettingsCategory)

    // General
    case appearanceMode(AppAppearanceMode)
    case searchShowCueGroup
    case searchPrefillCommandPanel
    case languageDropdown
    case deepLinkPlayFirstSearchResult

    // Play
    case playAutoPause
    case playAutoSwitch
    case numberField(SettingsNumberFieldID)
    case decodeMode(PlaybackDecodeMode)

    // Shortcuts (L-02.4)
    case shortcutRestoreDefault(PlaybackShortcutAction)

    // Subtitle (L-02.5)
    case subtitleFontDropdown
    case subtitleBold
    case subtitleItalic
    case subtitleColorField(SettingsSubtitleCategory.ColorFieldID)
    case subtitleColorPreset(SettingsSubtitleCategory.ColorFieldID, Int)
    case subtitleHorizontalAlignment(SRTSubtitleStyle.HorizontalAlignment)
    case subtitleVerticalAlignment(SRTSubtitleStyle.VerticalAlignment)
    case subtitleBorderType(SRTSubtitleStyle.BorderType)
    case subtitleRestoreDefaults

    // Maintenance
    case maintenanceRefresh
    case maintenanceCompactDatabase

    // Developer
    case developerEnableFTSDiagnostics
    case developerRefresh

    var textInputKind: SettingsTextInputKind? {
        switch self {
        case .numberField(let id):
            return .numberField(id)
        case .subtitleColorField(let id):
            return .subtitleColorField(id)
        default:
            return nil
        }
    }

    var colorWellID: SettingsSubtitleCategory.ColorFieldID? {
        switch self {
        case .subtitleColorField(let id), .subtitleColorPreset(let id, _):
            return id
        default:
            return nil
        }
    }
}

enum WorkbenchDialogTextInputKind: String, CaseIterable, Equatable, Hashable {
    case excerptEditorName
    case excerptEditorDescription
    case renameNewName
    case remoteAddress
    case remotePort
    case remoteUsername
    case remotePassword
    case ankiFileName
    case ankiLocation

    var dialogTarget: WorkbenchDialogAccessibilityTarget {
        switch self {
        case .excerptEditorName:
            return .excerptEditorNameField
        case .excerptEditorDescription:
            return .excerptEditorDescriptionField
        case .renameNewName:
            return .renameNewNameField
        case .remoteAddress:
            return .remoteAddressField
        case .remotePort:
            return .remotePortField
        case .remoteUsername:
            return .remoteUsernameField
        case .remotePassword:
            return .remotePasswordField
        case .ankiFileName:
            return .ankiFileNameField
        case .ankiLocation:
            return .ankiLocationField
        }
    }
}

enum WorkbenchDialogAccessibilityTarget: Equatable, Hashable {
    case dialogCloseButton
    // L-06.1 Edit Cover Dialog
    case editCoverChooseImage
    case editCoverCancel
    case editCoverSave
    // L-06.2 Excerpt List Editor Dialog
    case excerptEditorChooseImage
    case excerptEditorNameField
    case excerptEditorDescriptionField
    case excerptEditorCancel
    case excerptEditorSave
    // L-06.3 Rename Dialog
    case renameNewNameField
    case renameCancel
    case renameConfirm
    // L-06.4 Remote Folder Dialogs (WebDAV / SMB / FTP / NFS)
    case remoteAddressField
    case remotePortField
    case remoteUsernameField
    case remotePasswordField
    case remoteCancel
    case remoteConnect
    case remoteBreadcrumb(String)
    case remoteFolderCard(String)
    case remoteFolderCheckbox(String)
    case remoteBack
    case remoteAdd
    // L-06.5 Export to Anki Dialog
    case ankiAddFront
    case ankiRemoveItem(AnkiExportSide, AnkiCardItem)
    case ankiAddBack
    case ankiFileNameField
    case ankiLocationField
    case ankiChooseFolderButton
    case ankiCancel
    case ankiExport
    // L-06.6 Filter Dialog
    case filterChip(CueFacetKind, String)
    case filterReset
    case filterCancel
    case filterShow
    // L-06.7 Confirmation Dialog
    case confirmationAction(String)
    // L-06.8 File Detail Dialog
    case fileDetailPairedSwitcher
    // L-06.9 Task Panel
    case taskPanelTab(TaskQueueTab)
    case taskCardActionButton(String)

    var dialogTextInputKind: WorkbenchDialogTextInputKind? {
        switch self {
        case .excerptEditorNameField:
            return .excerptEditorName
        case .excerptEditorDescriptionField:
            return .excerptEditorDescription
        case .renameNewNameField:
            return .renameNewName
        case .remoteAddressField:
            return .remoteAddress
        case .remotePortField:
            return .remotePort
        case .remoteUsernameField:
            return .remoteUsername
        case .remotePasswordField:
            return .remotePassword
        case .ankiFileNameField:
            return .ankiFileName
        case .ankiLocationField:
            return .ankiLocation
        default:
            return nil
        }
    }
}

enum WorkbenchAccessibilityTarget: Hashable {
    // Topbar (L-01.2)
    case topbarSidebarToggle
    case topbarBackButton
    case topbarForwardButton
    case topbarRecentSegment(WorkbenchRecentSection)
    case topbarTaskButton
    case topbarSettingsButton

    // Sidebar (L-01.1)
    case sidebarItem(WorkbenchPanelMode)

    // Cover Summary Card (Library Detail & Excerpt Detail)
    case coverSummaryPrimaryButton
    case coverSummaryEditCoverButton
    case coverSummaryMoreButton

    // Toolbar (Library Overview, Excerpt Overview, Search & Excerpt Detail)
    case toolbarSearchField
    case toolbarSearchClearButton
    case toolbarFilterButton
    case toolbarSortButton
    case excerptNewListButton
    case toolbarExitSelectButton
    case toolbarSelectionAction(SchemaWorkbenchSelectionActionID)

    // Subtitle Table (Search & Excerpt Detail)
    case tableHeaderCheckbox
    case tableRowCheckbox(Int)
    case tableRowCueText(Int)
    case tableRowActionButton(Int)

    // Card Grids (Recent, Library Overview & Detail, Excerpt Overview)
    case mediaCard(String)
    case mediaCardActionButton(String)

    // File Page (Level 1 / 2 / 3)
    case fileAddFolderButton
    case fileIndexNowButton
    case fileStatusIndicatorText
    case fileBreadcrumb(String)
    case fileCard(String)
    case fileCardActionButton(String)
    case fileRowActionButton(String)

    var mediaCardID: String? {
        switch self {
        case .mediaCard(let id), .mediaCardActionButton(let id):
            return id
        default:
            return nil
        }
    }

    var isTableTarget: Bool {
        switch self {
        case .tableHeaderCheckbox, .tableRowCheckbox, .tableRowCueText, .tableRowActionButton:
            return true
        default:
            return false
        }
    }

    var tableRowIndex: Int? {
        switch self {
        case .tableRowCheckbox(let row), .tableRowCueText(let row), .tableRowActionButton(let row):
            return row
        default:
            return nil
        }
    }
}

enum PlaybackAccessibilitySurface: Equatable, Hashable {
    case playerStage
    case playbackOverlay
    case commandPanel(PlaybackCommandPanelPage)
}

enum PlaybackAccessibilityTarget: Equatable, Hashable {
    // L-07 Player Stage - Topbar (L-07.1)
    case playerReturn
    case playerCommandPanel
    case playerTask
    case playerSettings

    // L-07 Player Stage - Cue Queue Control Bar (L-07.2)
    case playerAutoPause
    case playerAutoSwitch
    case playerAutoSwitchGapDecrease
    case playerAutoSwitchGapIncrease

    // L-07 Player Stage - Bottom Control Bar (L-07.2)
    case playerPlayPause
    case playerPrevious
    case playerNext
    case playerMute
    case playerPlaybackOverlay
    case playerRepeat
    case playerCopyScreenshot
    case playerSubtitlesMenu
    case playerSpeedMenu
    case playerMoreMenu
    case playerFullscreen

    // L-08 Playback Overlay - Topbar (L-08.1)
    case overlayReturn
    case overlayTab(PlaybackOverlayModule)
    case overlayCollageButton
    case overlayCommandPanel
    case overlayTask
    case overlaySettings

    // L-08 Playback Overlay - Video Playlist Content (L-08.2)
    case overlayVideoCard(String)
    case overlayVideoCardActionButton(String)

    // L-08 Playback Overlay - Bottom Bar (L-08.3)
    case overlayFooterAction(String)

    // L-09 Command Panel - Root (L-09.1)
    case commandPanelSearchField
    case commandPanelSearchClearButton
    case commandPanelRootOption(Int)

    // L-09 Command Panel - Secondary Header (L-09.2)
    case commandPanelBackButton
    case commandPanelFilterButton
    case commandPanelSortButton

    // L-09 Command Panel - Recent Videos / Excerpt Lists Grid (L-09.2)
    case commandPanelRecentCard(String)
    case commandPanelRecentCardActionButton(String)

    // L-09 Command Panel - Footer (L-09.1 / L-09.2 / L-09.3)
    case commandPanelFooterAction(String)

    var isPlayerStageTarget: Bool {
        switch self {
        case .playerReturn,
             .playerCommandPanel,
             .playerTask,
             .playerSettings,
             .playerAutoPause,
             .playerAutoSwitch,
             .playerAutoSwitchGapDecrease,
             .playerAutoSwitchGapIncrease,
             .playerPlayPause,
             .playerPrevious,
             .playerNext,
             .playerMute,
             .playerPlaybackOverlay,
             .playerRepeat,
             .playerCopyScreenshot,
             .playerSubtitlesMenu,
             .playerSpeedMenu,
             .playerMoreMenu,
             .playerFullscreen:
            return true
        default:
            return false
        }
    }

    var overlayVideoCardID: String? {
        switch self {
        case .overlayVideoCard(let id), .overlayVideoCardActionButton(let id):
            return id
        default:
            return nil
        }
    }

    var commandPanelRecentCardID: String? {
        switch self {
        case .commandPanelRecentCard(let id), .commandPanelRecentCardActionButton(let id):
            return id
        default:
            return nil
        }
    }

    var commandPanelRootOptionOrdinal: Int? {
        switch self {
        case .commandPanelRootOption(let ordinal):
            return ordinal
        default:
            return nil
        }
    }
}

@MainActor
final class WorkbenchAccessibilityCoordinator: ObservableObject {
    @Published private(set) var focusedTarget: WorkbenchAccessibilityTarget?
    @Published var activeDialogID: WorkbenchDialogAccessibilityID?
    @Published private(set) var focusedDialogTarget: WorkbenchDialogAccessibilityTarget?

    // Settings Window (Step 3: L-02 Settings)
    @Published var selectedSettingsCategory: SettingsCategory = .general
    @Published private(set) var focusedSettingsTarget: SettingsAccessibilityTarget?
    @Published private(set) var focusedSettingsDialogTarget: WorkbenchDialogAccessibilityTarget?
    @Published var activeSubtitleColorPopover: SettingsSubtitleCategory.ColorFieldID?
    @Published var isShortcutRecording: Bool = false

    // Playback Surfaces (Step 4: L-07 Player Stage, L-08 Playback Overlay, L-09 Command Panel)
    @Published var activePlaybackSurface: PlaybackAccessibilitySurface?
    @Published private(set) var focusedPlaybackTarget: PlaybackAccessibilityTarget?

    /// Current column count of the active Workbench card grid (`Recent`,
    /// `Library` Overview & Detail, `Excerpt` Overview), updated by
    /// `LibraryOverviewGrid` layout.
    var cardGridColumnCount: Int = 1

    /// Current SubtitleTableView coordinator when `Search` or `Excerpt` Detail
    /// is mounted on the Workbench page.
    weak var activeSubtitleTableCoordinator: SubtitleTableView.Coordinator? {
        didSet {
            if activeSubtitleTableCoordinator !== oldValue {
                WorkbenchAccessibilityDebugLog.log(
                    "Coordinator.activeSubtitleTableCoordinator.didSet",
                    "old=\(oldValue?.tableName ?? "nil")(\(WorkbenchAccessibilityDebugLog.ptr(oldValue))) new=\(activeSubtitleTableCoordinator?.tableName ?? "nil")(\(WorkbenchAccessibilityDebugLog.ptr(activeSubtitleTableCoordinator)))"
                )
            }
        }
    }
    var tableTargetsOverrideForTesting: (() -> [WorkbenchAccessibilityTarget])?

    /// Weak reference to the active Workbench search field's native text field,
    /// so focusing `.toolbarSearchField` places the insertion point inside it
    /// and leaving `.toolbarSearchField` resigns first responder.
    weak var activeSearchTextField: WorkbenchNativeSingleLineTextField? {
        didSet {
            if activeSearchTextField !== oldValue {
                WorkbenchAccessibilityDebugLog.log(
                    "Coordinator.activeSearchTextField.didSet",
                    "old=\(WorkbenchAccessibilityDebugLog.ptr(oldValue)) new=\(WorkbenchAccessibilityDebugLog.ptr(activeSearchTextField)) newWindow=\(activeSearchTextField?.window != nil)"
                )
            }
        }
    }

    private struct RegisteredCardMenuOpener {
        let ownerToken: ObjectIdentifier?
        let openMenu: () -> Void
    }

    /// Closures registered by card grids (`Recent` Excerpt Lists, `Library` Overview,
    /// `Excerpt` Overview) to open the card's `dots-three` menu by card ID.
    private var mediaCardMenuOpeners: [String: RegisteredCardMenuOpener] = [:]

    /// Closure registered by the active `SchemaWorkbenchSortMenuHost` to toggle
    /// its sort menu when `.toolbarSortButton` is activated.
    var onToggleToolbarSortMenu: (() -> Void)?

    /// Closure registered by `SchemaWorkbenchSearchToolbar` to open the Filter
    /// dialog when `.toolbarFilterButton` is activated.
    var onOpenToolbarFilterDialog: (() -> Void)?

    /// Closure registered by `SchemaWorkbenchSearchToolbar` to exit batch
    /// selection mode when `.toolbarExitSelectButton` is activated.
    var onExitTableSelectionMode: (() -> Void)?

    /// Closure registered by `SchemaWorkbenchSearchToolbar` to perform a batch
    /// selection action when `.toolbarSelectionAction(id)` is activated.
    var onPerformSelectionAction: ((SchemaWorkbenchSelectionActionID) -> Void)?

    /// Whether the active Workbench table (`Search` or `Excerpt` Detail) is
    /// currently in batch selection mode (`Select Mode`).
    var isTableInSelectionMode: Bool = false {
        didSet {
            if isTableInSelectionMode != oldValue {
                WorkbenchAccessibilityDebugLog.log(
                    "Coordinator.isTableInSelectionMode.didSet",
                    "old=\(oldValue) new=\(isTableInSelectionMode) focused=\(String(describing: focusedTarget))"
                )
            }
        }
    }

    /// Closure registered by `WorkbenchLibraryView` or `WorkbenchExcerptTableView`
    /// to toggle the Cover Summary `More` menu when `.coverSummaryMoreButton` is activated.
    var onToggleCoverSummaryMoreMenu: (() -> Void)?

    /// Closure registered by `WorkbenchExcerptTableView` to toggle the `Move to`
    /// menu in batch selection mode when `.toolbarSelectionAction(.moveTo)` is activated.
    var onToggleSelectionMoveToMenu: (() -> Void)?

    /// Closure registered by `WorkbenchFileView` to toggle the `Add Folder`
    /// menu when `.fileAddFolderButton` is activated.
    var onToggleFileAddFolderMenu: (() -> Void)?

    /// Closures registered by `WorkbenchFileView` cards and file rows for
    /// opening their `dots-three` menu by ID.
    private var fileCardMenuOpeners: [String: () -> Void] = [:]

    private struct RegisteredDialogTextInput {
        let ownerToken: ObjectIdentifier?
        let setFocused: (Bool) -> Void
        let isCurrentlyFocused: () -> Bool
    }

    private var dialogTextInputs: [WorkbenchDialogTextInputKind: RegisteredDialogTextInput] = [:]
    private var activeDialogTextInputs: Set<WorkbenchDialogTextInputKind> = []

    /// Closures registered by `TaskPanel` cards (`current-<id>`, `history-<id>`)
    /// to open their `dots-three` menu by ID.
    private var taskCardMenuOpeners: [String: RegisteredCardMenuOpener] = [:]

    /// Closure registered by the active Remote Folder Dialog (Step 1) to run
    /// its `connect()` validation and connection workflow when `.remoteConnect` is activated.
    var onRemoteDialogConnect: (() -> Void)?

    /// Closures registered by `AnkiExportDialog` for activating the Front / Back `+` buttons.
    var onTriggerAnkiAddFront: (() -> Void)?
    var onTriggerAnkiAddBack: (() -> Void)?

    /// Closure registered by `WorkbenchFileDetailDialog` to open the paired
    /// file switcher dropdown menu when `.fileDetailPairedSwitcher` is activated.
    var onToggleFileDetailPairedMenu: (() -> Void)?

    /// Closures registered by Settings dropdown triggers (`General` -> `Language`,
    /// `Subtitle` -> `Font`).
    var onToggleSettingsLanguageMenu: (() -> Void)?
    var onToggleSettingsSubtitleFontMenu: (() -> Void)?

    private var settingsTextInputs: [SettingsTextInputKind: RegisteredDialogTextInput] = [:]
    private var activeSettingsTextInputs: Set<SettingsTextInputKind> = []

    /// Weak reference to the Command Panel Root search field's native text field.
    weak var activeCommandPanelSearchTextField: WorkbenchNativeSingleLineTextField?

    /// Closures registered by `PlaybackLibraryOverlay` (`Video Playlist`) cards
    /// to open their `dots-three` menu by card ID.
    private var playbackOverlayCardMenuOpeners: [String: RegisteredCardMenuOpener] = [:]

    /// Closures registered by `PlaybackCommandPanel` (`Recent Videos` & `Recent Excerpt Lists`)
    /// cards to open their `dots-three` menu by card ID.
    private var commandPanelCardMenuOpeners: [String: RegisteredCardMenuOpener] = [:]

    /// Closures registered by `PlaybackCommandPanelSearchResults` for Filter and Sort triggers.
    var onOpenCommandPanelFilterDialog: (() -> Void)?
    var onToggleCommandPanelSortMenu: (() -> Void)?

    var isActive: Bool {
        focusedTarget != nil
    }

    var isDialogActive: Bool {
        focusedDialogTarget != nil
    }

    var isSettingsActive: Bool {
        focusedSettingsTarget != nil
    }

    var isSettingsDialogActive: Bool {
        focusedSettingsDialogTarget != nil
    }

    var isPlaybackActive: Bool {
        focusedPlaybackTarget != nil
    }

    var focusedCardID: String? {
        focusedTarget?.mediaCardID
    }

    func isFocused(_ target: WorkbenchAccessibilityTarget) -> Bool {
        focusedTarget == target
    }

    func isPlaybackFocused(_ target: PlaybackAccessibilityTarget) -> Bool {
        focusedPlaybackTarget == target
    }

    func isSettingsFocused(_ target: SettingsAccessibilityTarget) -> Bool {
        focusedSettingsTarget == target
    }

    func isSettingsDialogFocused(_ target: WorkbenchDialogAccessibilityTarget) -> Bool {
        focusedSettingsDialogTarget == target
    }

    func isDialogFocused(
        _ target: WorkbenchDialogAccessibilityTarget,
        dialogID: WorkbenchDialogAccessibilityID? = nil
    ) -> Bool {
        if dialogID == .settingsConfirmation {
            return focusedSettingsDialogTarget == target
        }
        guard focusedDialogTarget == target else {
            return false
        }
        if let dialogID, let activeDialogID {
            return dialogID == activeDialogID
        }
        return true
    }

    func setSettingsDialogFocus(_ target: WorkbenchDialogAccessibilityTarget?) {
        if focusedSettingsDialogTarget != target {
            focusedSettingsDialogTarget = target
        }
    }

    @discardableResult
    func clearSettingsDialog() -> Bool {
        let hadFocus = focusedSettingsDialogTarget != nil
        focusedSettingsDialogTarget = nil
        return hadFocus
    }

    func setSettingsFocus(
        _ target: SettingsAccessibilityTarget?,
        isTargetEnabled: Bool = true
    ) {
        let previous = focusedSettingsTarget
        if focusedSettingsTarget != target {
            focusedSettingsTarget = target
        }
        if let colorWellID = target?.colorWellID {
            if activeSubtitleColorPopover != colorWellID {
                activeSubtitleColorPopover = colorWellID
            }
        } else if target != nil {
            if activeSubtitleColorPopover != nil {
                activeSubtitleColorPopover = nil
            }
        }
        syncSettingsTextInputFocus(
            from: previous,
            to: target,
            isTargetEnabled: isTargetEnabled
        )
    }

    @discardableResult
    func clearSettings(
        keepTextInputFocus: Bool = true,
        keepColorPopoverOpen: Bool = true
    ) -> Bool {
        let hadFocus = focusedSettingsTarget != nil
        focusedSettingsTarget = nil
        if !keepTextInputFocus {
            unfocusAllSettingsTextInputs()
        }
        if !keepColorPopoverOpen {
            activeSubtitleColorPopover = nil
        }
        return hadFocus
    }

    func registerSettingsTextInput(
        _ kind: SettingsTextInputKind,
        ownerToken: ObjectIdentifier? = nil,
        setFocused: @escaping (Bool) -> Void,
        isCurrentlyFocused: @escaping () -> Bool
    ) {
        settingsTextInputs[kind] = RegisteredDialogTextInput(
            ownerToken: ownerToken,
            setFocused: setFocused,
            isCurrentlyFocused: isCurrentlyFocused
        )
        if isCurrentlyFocused() {
            activeSettingsTextInputs.insert(kind)
        }
    }

    func unregisterSettingsTextInput(
        _ kind: SettingsTextInputKind,
        ownerToken: ObjectIdentifier? = nil
    ) {
        if let ownerToken,
           let existing = settingsTextInputs[kind],
           let existingToken = existing.ownerToken,
           existingToken != ownerToken {
            return
        }
        settingsTextInputs.removeValue(forKey: kind)
        activeSettingsTextInputs.remove(kind)
    }

    func setSettingsTextInputActive(_ kind: SettingsTextInputKind, isActive: Bool) {
        if isActive {
            activeSettingsTextInputs.insert(kind)
        } else {
            activeSettingsTextInputs.remove(kind)
        }
    }

    func isSettingsTextInputActive(_ kind: SettingsTextInputKind) -> Bool {
        if let entry = settingsTextInputs[kind], entry.isCurrentlyFocused() {
            return true
        }
        return activeSettingsTextInputs.contains(kind)
    }

    var isAnySettingsTextInputFocused: Bool {
        for kind in SettingsTextInputKind.allCases {
            if isSettingsTextInputActive(kind) {
                return true
            }
        }
        return !activeSettingsTextInputs.isEmpty
    }

    func focusSettingsTextInput(_ kind: SettingsTextInputKind, isEnabled: Bool = true) {
        guard isEnabled else {
            unfocusAllSettingsTextInputs()
            return
        }
        unfocusAllSettingsTextInputs(except: kind)
        activeSettingsTextInputs.insert(kind)
        settingsTextInputs[kind]?.setFocused(true)
    }

    func unfocusSettingsTextInput(_ kind: SettingsTextInputKind) {
        activeSettingsTextInputs.remove(kind)
        settingsTextInputs[kind]?.setFocused(false)
    }

    func unfocusAllSettingsTextInputs(except keptKind: SettingsTextInputKind? = nil) {
        for kind in SettingsTextInputKind.allCases where kind != keptKind {
            activeSettingsTextInputs.remove(kind)
            settingsTextInputs[kind]?.setFocused(false)
        }
        if keptKind == nil,
           let window = NSApp.keyWindow,
           (window.firstResponder is NSText || window.firstResponder is NSTextField) {
            _ = window.makeFirstResponder(nil)
        }
    }

    private func syncSettingsTextInputFocus(
        from previous: SettingsAccessibilityTarget?,
        to next: SettingsAccessibilityTarget?,
        isTargetEnabled: Bool
    ) {
        if let inputKind = next?.textInputKind {
            focusSettingsTextInput(inputKind, isEnabled: isTargetEnabled)
        } else if next != nil {
            unfocusAllSettingsTextInputs()
        } else if let prevKind = previous?.textInputKind {
            _ = prevKind
        }
    }

    func setDialogFocus(
        _ target: WorkbenchDialogAccessibilityTarget?,
        dialogID: WorkbenchDialogAccessibilityID? = nil,
        isTargetEnabled: Bool = true
    ) {
        if let dialogID, activeDialogID != dialogID {
            activeDialogID = dialogID
        }
        let previous = focusedDialogTarget
        if focusedDialogTarget != target {
            focusedDialogTarget = target
        }
        syncDialogTextInputFocus(
            from: previous,
            to: target,
            isTargetEnabled: isTargetEnabled
        )
    }

    @discardableResult
    func clearDialog(keepTextInputFocus: Bool = true) -> Bool {
        let hadFocus = focusedDialogTarget != nil
        focusedDialogTarget = nil
        if !keepTextInputFocus {
            unfocusAllDialogTextInputs()
        }
        return hadFocus
    }

    func registerDialogTextInput(
        _ kind: WorkbenchDialogTextInputKind,
        ownerToken: ObjectIdentifier? = nil,
        setFocused: @escaping (Bool) -> Void,
        isCurrentlyFocused: @escaping () -> Bool
    ) {
        dialogTextInputs[kind] = RegisteredDialogTextInput(
            ownerToken: ownerToken,
            setFocused: setFocused,
            isCurrentlyFocused: isCurrentlyFocused
        )
        if isCurrentlyFocused() {
            activeDialogTextInputs.insert(kind)
        }
    }

    func unregisterDialogTextInput(
        _ kind: WorkbenchDialogTextInputKind,
        ownerToken: ObjectIdentifier? = nil
    ) {
        if let ownerToken,
           let existing = dialogTextInputs[kind],
           let existingToken = existing.ownerToken,
           existingToken != ownerToken {
            return
        }
        dialogTextInputs.removeValue(forKey: kind)
        activeDialogTextInputs.remove(kind)
    }

    func setDialogTextInputActive(_ kind: WorkbenchDialogTextInputKind, isActive: Bool) {
        if isActive {
            activeDialogTextInputs.insert(kind)
        } else {
            activeDialogTextInputs.remove(kind)
        }
    }

    func isDialogTextInputActive(_ kind: WorkbenchDialogTextInputKind) -> Bool {
        if let entry = dialogTextInputs[kind], entry.isCurrentlyFocused() {
            return true
        }
        return activeDialogTextInputs.contains(kind)
    }

    var isAnyDialogTextInputFocused: Bool {
        for kind in WorkbenchDialogTextInputKind.allCases {
            if isDialogTextInputActive(kind) {
                return true
            }
        }
        return !activeDialogTextInputs.isEmpty
    }

    func focusDialogTextInput(_ kind: WorkbenchDialogTextInputKind, isEnabled: Bool = true) {
        guard isEnabled else {
            unfocusAllDialogTextInputs()
            return
        }
        unfocusAllDialogTextInputs(except: kind)
        activeDialogTextInputs.insert(kind)
        dialogTextInputs[kind]?.setFocused(true)
    }

    func unfocusDialogTextInput(_ kind: WorkbenchDialogTextInputKind) {
        activeDialogTextInputs.remove(kind)
        dialogTextInputs[kind]?.setFocused(false)
    }

    func unfocusAllDialogTextInputs(except keptKind: WorkbenchDialogTextInputKind? = nil) {
        for kind in WorkbenchDialogTextInputKind.allCases where kind != keptKind {
            activeDialogTextInputs.remove(kind)
            dialogTextInputs[kind]?.setFocused(false)
        }
        if keptKind == nil,
           let window = NSApp.keyWindow,
           (window.firstResponder is NSText || window.firstResponder is NSTextField) {
            _ = window.makeFirstResponder(nil)
        }
    }

    private func syncDialogTextInputFocus(
        from previous: WorkbenchDialogAccessibilityTarget?,
        to next: WorkbenchDialogAccessibilityTarget?,
        isTargetEnabled: Bool
    ) {
        if let inputKind = next?.dialogTextInputKind {
            focusDialogTextInput(inputKind, isEnabled: isTargetEnabled)
        } else if next != nil {
            unfocusAllDialogTextInputs()
        } else if let prevKind = previous?.dialogTextInputKind {
            _ = prevKind
        }
    }

    func registerTaskCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil,
        openMenu: @escaping () -> Void
    ) {
        taskCardMenuOpeners[id] = RegisteredCardMenuOpener(
            ownerToken: ownerToken,
            openMenu: openMenu
        )
    }

    func unregisterTaskCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil
    ) {
        if let ownerToken,
           let existing = taskCardMenuOpeners[id],
           let existingToken = existing.ownerToken,
           existingToken != ownerToken {
            return
        }
        taskCardMenuOpeners.removeValue(forKey: id)
    }

    @discardableResult
    func activateTaskCardAction(id: String) -> Bool {
        guard let entry = taskCardMenuOpeners[id] else {
            return false
        }
        entry.openMenu()
        return true
    }

    func setFocus(_ target: WorkbenchAccessibilityTarget?) {
        let previous = focusedTarget
        if focusedTarget != target {
            focusedTarget = target
        }
        WorkbenchAccessibilityDebugLog.log(
            "Coordinator.setFocus",
            "from=\(String(describing: previous)) to=\(String(describing: target)) isTableInSelectionMode=\(isTableInSelectionMode) tableIsSelectionMode=\(String(describing: activeSubtitleTableCoordinator?.isSelectionMode)) searchField=\(WorkbenchAccessibilityDebugLog.ptr(activeSearchTextField))"
        )
        if target?.mediaCardID != nil {
            PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        }
        CardHighlightModel.broadcastWorkbenchAccessibilitySelectedCardChanged(target?.mediaCardID)
        syncNativeSearchFieldFocus(from: previous, to: target)
        activeSubtitleTableCoordinator?.syncWorkbenchAccessibilityFocus(target)
    }

    @discardableResult
    func clear() -> Bool {
        guard let previous = focusedTarget else {
            return false
        }
        let caller = Thread.callStackSymbols.dropFirst(1).prefix(4).joined(separator: " <- ")
        WorkbenchAccessibilityDebugLog.log(
            "Coordinator.clear",
            "cleared=\(String(describing: previous)) isTableInSelectionMode=\(isTableInSelectionMode) caller=\(caller)"
        )
        focusedTarget = nil
        CardHighlightModel.broadcastWorkbenchAccessibilitySelectedCardChanged(nil)
        activeSubtitleTableCoordinator?.syncWorkbenchAccessibilityFocus(nil)
        return true
    }

    @discardableResult
    func resignActiveSearchTextFieldIfFocused() -> Bool {
        guard let field = activeSearchTextField, field.isCurrentlyFocused else {
            return false
        }
        WorkbenchAccessibilityDebugLog.log(
            "Coordinator.resignActiveSearchTextFieldIfFocused",
            "field=\(WorkbenchAccessibilityDebugLog.ptr(field))"
        )
        _ = field.window?.makeFirstResponder(nil)
        return true
    }

    func registerMediaCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil,
        openMenu: @escaping () -> Void
    ) {
        mediaCardMenuOpeners[id] = RegisteredCardMenuOpener(
            ownerToken: ownerToken,
            openMenu: openMenu
        )
    }

    func unregisterMediaCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil
    ) {
        if let ownerToken,
           let existing = mediaCardMenuOpeners[id],
           let existingToken = existing.ownerToken,
           existingToken != ownerToken {
            WorkbenchAccessibilityDebugLog.log(
                "Coordinator.unregisterMediaCardAction.ignoredStaleOwner",
                "id=\(id) existingToken=\(existingToken) staleToken=\(ownerToken)"
            )
            return
        }
        mediaCardMenuOpeners.removeValue(forKey: id)
    }

    func activateMediaCardAction(id: String) -> Bool {
        guard let entry = mediaCardMenuOpeners[id] else {
            WorkbenchAccessibilityDebugLog.log(
                "Coordinator.activateMediaCardAction.failed",
                "id=\(id) registeredCount=\(mediaCardMenuOpeners.count)"
            )
            return false
        }
        WorkbenchAccessibilityDebugLog.log(
            "Coordinator.activateMediaCardAction.invoke",
            "id=\(id)"
        )
        entry.openMenu()
        return true
    }

    func registerFileCardAction(id: String, openMenu: @escaping () -> Void) {
        fileCardMenuOpeners[id] = openMenu
    }

    func unregisterFileCardAction(id: String) {
        fileCardMenuOpeners.removeValue(forKey: id)
    }

    @discardableResult
    func activateFileCardAction(id: String) -> Bool {
        guard let openMenu = fileCardMenuOpeners[id] else {
            return false
        }
        openMenu()
        return true
    }

    func setPlaybackFocus(
        _ target: PlaybackAccessibilityTarget?,
        surface: PlaybackAccessibilitySurface? = nil
    ) {
        if let surface, activePlaybackSurface != surface {
            activePlaybackSurface = surface
        }
        let previous = focusedPlaybackTarget
        if focusedPlaybackTarget != target {
            focusedPlaybackTarget = target
        }
        syncCommandPanelSearchFieldFocus(from: previous, to: target)
    }

    @discardableResult
    func clearPlayback(keepTextInputFocus: Bool = true) -> Bool {
        let hadFocus = focusedPlaybackTarget != nil
        focusedPlaybackTarget = nil
        if !keepTextInputFocus,
           let field = activeCommandPanelSearchTextField,
           field.isCurrentlyFocused
        {
            _ = field.window?.makeFirstResponder(nil)
        }
        return hadFocus
    }

    func registerPlaybackOverlayCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil,
        openMenu: @escaping () -> Void
    ) {
        playbackOverlayCardMenuOpeners[id] = RegisteredCardMenuOpener(
            ownerToken: ownerToken,
            openMenu: openMenu
        )
    }

    func unregisterPlaybackOverlayCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil
    ) {
        if let ownerToken,
           let existing = playbackOverlayCardMenuOpeners[id],
           let existingToken = existing.ownerToken,
           existingToken != ownerToken {
            return
        }
        playbackOverlayCardMenuOpeners.removeValue(forKey: id)
    }

    @discardableResult
    func activatePlaybackOverlayCardAction(id: String) -> Bool {
        guard let entry = playbackOverlayCardMenuOpeners[id] else {
            return false
        }
        entry.openMenu()
        return true
    }

    func registerCommandPanelCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil,
        openMenu: @escaping () -> Void
    ) {
        commandPanelCardMenuOpeners[id] = RegisteredCardMenuOpener(
            ownerToken: ownerToken,
            openMenu: openMenu
        )
    }

    func unregisterCommandPanelCardAction(
        id: String,
        ownerToken: ObjectIdentifier? = nil
    ) {
        if let ownerToken,
           let existing = commandPanelCardMenuOpeners[id],
           let existingToken = existing.ownerToken,
           existingToken != ownerToken {
            return
        }
        commandPanelCardMenuOpeners.removeValue(forKey: id)
    }

    @discardableResult
    func activateCommandPanelCardAction(id: String) -> Bool {
        guard let entry = commandPanelCardMenuOpeners[id] else {
            return false
        }
        entry.openMenu()
        return true
    }

    private func syncCommandPanelSearchFieldFocus(
        from previous: PlaybackAccessibilityTarget?,
        to next: PlaybackAccessibilityTarget?
    ) {
        _ = previous
        if next == .commandPanelSearchField {
            activeCommandPanelSearchTextField?.focusFromAccessibility()
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.focusedPlaybackTarget == .commandPanelSearchField
                else {
                    return
                }
                self.activeCommandPanelSearchTextField?.focusFromAccessibility()
            }
        } else if next != nil {
            if let field = activeCommandPanelSearchTextField, field.isCurrentlyFocused {
                _ = field.window?.makeFirstResponder(nil)
            } else {
                let activeWindow = NSApplication.shared.keyWindow
                    ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
                if let textView = activeWindow?.firstResponder as? NSTextView,
                   textView.isEditable
                {
                    _ = activeWindow?.makeFirstResponder(nil)
                }
            }
        }
    }

    private func syncNativeSearchFieldFocus(
        from previous: WorkbenchAccessibilityTarget?,
        to next: WorkbenchAccessibilityTarget?
    ) {
        if next == .toolbarSearchField {
            WorkbenchAccessibilityDebugLog.log(
                "Coordinator.syncNativeSearchFieldFocus.schedule",
                "from=\(String(describing: previous)) activeSearchTextField=\(WorkbenchAccessibilityDebugLog.ptr(activeSearchTextField))"
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                WorkbenchAccessibilityDebugLog.log(
                    "Coordinator.syncNativeSearchFieldFocus.async",
                    "focusedTarget=\(String(describing: self.focusedTarget)) activeSearchTextField=\(WorkbenchAccessibilityDebugLog.ptr(self.activeSearchTextField)) window=\(self.activeSearchTextField?.window != nil)"
                )
                guard self.focusedTarget == .toolbarSearchField else { return }
                self.activeSearchTextField?.focusFromAccessibility()
            }
        } else if next != nil {
            if let field = activeSearchTextField, field.isCurrentlyFocused {
                WorkbenchAccessibilityDebugLog.log(
                    "Coordinator.syncNativeSearchFieldFocus.resign",
                    "to=\(String(describing: next)) field=\(WorkbenchAccessibilityDebugLog.ptr(field))"
                )
                _ = field.window?.makeFirstResponder(nil)
            }
        }
    }
}

private struct WorkbenchAccessibilityCoordinatorKey: EnvironmentKey {
    static let defaultValue: WorkbenchAccessibilityCoordinator? = nil
}

private struct WorkbenchDialogAccessibilityIDKey: EnvironmentKey {
    static let defaultValue: WorkbenchDialogAccessibilityID? = nil
}

extension EnvironmentValues {
    var workbenchAccessibility: WorkbenchAccessibilityCoordinator? {
        get { self[WorkbenchAccessibilityCoordinatorKey.self] }
        set { self[WorkbenchAccessibilityCoordinatorKey.self] = newValue }
    }

    var workbenchDialogID: WorkbenchDialogAccessibilityID? {
        get { self[WorkbenchDialogAccessibilityIDKey.self] }
        set { self[WorkbenchDialogAccessibilityIDKey.self] = newValue }
    }
}

struct WorkbenchAccessibilityReader<Content: View>: View {
    @Environment(\.workbenchAccessibility) private var coordinator
    @ViewBuilder let content: (WorkbenchAccessibilityCoordinator?) -> Content

    var body: some View {
        if let coordinator {
            ObservedCoordinatorView(coordinator: coordinator, content: content)
        } else {
            content(nil)
        }
    }

    private struct ObservedCoordinatorView: View {
        @ObservedObject var coordinator: WorkbenchAccessibilityCoordinator
        @ViewBuilder let content: (WorkbenchAccessibilityCoordinator?) -> Content

        var body: some View {
            content(coordinator)
        }
    }
}

struct WorkbenchAccessibilityScrollRevealProbe: NSViewRepresentable {
    let isFocused: Bool

    init(isFocused: Bool) {
        self.isFocused = isFocused
    }

    init(isActive: Bool) {
        self.isFocused = isActive
    }

    func makeNSView(context _: Context) -> ProbeView {
        ProbeView()
    }

    func updateNSView(_ nsView: ProbeView, context _: Context) {
        nsView.update(isFocused: isFocused)
    }

    final class ProbeView: NSView {
        private var wasFocused = false

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        func update(isFocused: Bool) {
            let becameFocused = isFocused && !wasFocused
            wasFocused = isFocused
            guard becameFocused else { return }
            DispatchQueue.main.async { [weak self] in
                self?.revealInEnclosingScrollView()
            }
        }

        private func revealInEnclosingScrollView() {
            guard wasFocused,
                  bounds.width > 0,
                  bounds.height > 0,
                  let scrollView = enclosingScrollView,
                  let documentView = scrollView.documentView
            else {
                return
            }
            let clipView = scrollView.contentView
            let rectInDocument = documentView.convert(bounds, from: self).insetBy(dx: -6, dy: -6)
            let visible = clipView.documentVisibleRect
            guard visible.height > 0 else { return }
            var targetOriginY = visible.origin.y
            if rectInDocument.minY < visible.minY {
                targetOriginY = max(0, rectInDocument.minY)
            } else if rectInDocument.maxY > visible.maxY {
                targetOriginY = max(0, rectInDocument.maxY - visible.height)
            }
            if abs(targetOriginY - visible.origin.y) > 0.5 {
                clipView.scroll(to: CGPoint(x: visible.origin.x, y: targetOriginY))
                scrollView.reflectScrolledClipView(clipView)
            }
        }
    }
}

extension View {
    func workbenchAccessibilityFocusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = WorkbenchControlMetrics.redesignCornerRadius,
        isCircular: Bool = false,
        isCapsule: Bool = false,
        isPlayerChrome: Bool = false
    ) -> some View {
        let expansion = WorkbenchControlMetrics.redesignFocusRingPathExpansion
        let lineWidth = WorkbenchControlMetrics.redesignFocusRingWidth
        let color = isPlayerChrome ? PlaybackTheme.focusRing : WorkbenchRedesignColors.focusRing
        return self
            .background(WorkbenchAccessibilityScrollRevealProbe(isFocused: isFocused))
            .overlay {
                if isFocused {
                    if isCircular {
                        Circle()
                            .stroke(color, lineWidth: lineWidth)
                            .padding(-expansion)
                            .allowsHitTesting(false)
                    } else if isCapsule {
                        Capsule(style: .continuous)
                            .stroke(color, lineWidth: lineWidth)
                            .padding(-expansion)
                            .allowsHitTesting(false)
                    } else {
                        RoundedRectangle(
                            cornerRadius: cornerRadius + expansion,
                            style: .continuous
                        )
                        .stroke(color, lineWidth: lineWidth)
                        .padding(-expansion)
                        .allowsHitTesting(false)
                    }
                }
            }
    }
}
