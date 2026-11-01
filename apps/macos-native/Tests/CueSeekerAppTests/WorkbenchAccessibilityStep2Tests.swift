import AppKit
@testable import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite(.serialized)
@MainActor
struct WorkbenchAccessibilityStep2Tests {
    private func makeTestCoordinator() -> (AppCoordinator, String, UserDefaults) {
        let suiteName = "WorkbenchAccessibilityStep2Tests-\(UUID().uuidString)"
        let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
        let app = AppCoordinator(userDefaults: userDefaults)
        return (app, suiteName, userDefaults)
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags = [],
        isRepeat: Bool = false
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: isRepeat,
            keyCode: keyCode
        )!
    }

    @Test
    func confirmationDialogStartsUnfocusedIgnoresUnfocusedReturnAndUsesTwoStageEscape() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        app.workbenchAccessibility.setFocus(.topbarTaskButton)
        #expect(app.workbenchAccessibility.isActive)

        var didCancel = false
        var didConfirm = false
        app.confirmation.session = WorkbenchConfirmationSession(
            title: "Remove Folder",
            message: "Are you sure?",
            destructiveTitle: "Remove",
            cancelTitle: "Cancel",
            onDestructive: {
                didConfirm = true
                app.confirmation.session = nil
            },
            onCancel: {
                didCancel = true
                app.confirmation.session = nil
            }
        )
        app.reconcileWorkbenchAccessibilityFocus()
        app.reconcileDialogAccessibilityFocus()

        // Workbench page focus is cleared when a dialog opens; dialog starts with no focus ring.
        #expect(!app.workbenchAccessibility.isActive)
        #expect(!app.workbenchAccessibility.isDialogActive)
        #expect(app.activeDialogAccessibilityID() == .confirmation)
        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .confirmationAction("cancel"),
            .confirmationAction("destructive"),
        ])

        // Pressing Return or Space while no dialog control is focused does NOT trigger Cancel or Confirm.
        #expect(!app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 36)))
        #expect(!app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 49)))
        #expect(!didCancel)
        #expect(!didConfirm)
        #expect(app.confirmation.session != nil)

        // Tab focuses 1st target (.dialogCloseButton), Shift+Tab wraps to last (.confirmationAction("destructive")).
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode)))
        #expect(app.workbenchAccessibility.focusedDialogTarget == .dialogCloseButton)

        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: MenuGate.tabKeyCode, flags: .shift)))
        #expect(app.workbenchAccessibility.focusedDialogTarget == .confirmationAction("destructive"))

        // 1st Esc / East only clears dialog accessibility focus ring without closing the dialog.
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(!app.workbenchAccessibility.isDialogActive)
        #expect(app.confirmation.session != nil)

        // 2nd Esc / East closes the dialog.
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(app.confirmation.session == nil)
    }

    @Test
    func editCoverExcerptEditorAndRenameDialogsSyncTextInputFocusAndRespectDisabledButtons() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        // 1. Edit Cover Dialog (L-06.1)
        let coverSession = LibraryCoverEditingSession(
            target: .folder(path: "/Media/ShowA"),
            currentCoverPath: nil,
            currentCoverRevision: nil
        )
        app.library.coverEditingSession = coverSession
        app.reconcileDialogAccessibilityFocus()

        #expect(app.activeDialogAccessibilityID() == .editCover)
        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .editCoverChooseImage,
            .editCoverCancel,
            .editCoverSave,
        ])
        // Save is disabled before an image is chosen, but remains focusable in Tab sequence.
        #expect(!app.isDialogAccessibilityTargetEnabled(.editCoverSave))
        #expect(app.handleWorkbenchControllerInput(.button(.leftShoulder, isRepeat: false)))
        #expect(app.workbenchAccessibility.focusedDialogTarget == .editCoverSave)
        // Pressing South (X) on disabled Save does nothing.
        #expect(app.handleWorkbenchControllerInput(.button(.south, isRepeat: false)))
        #expect(app.library.coverEditingSession != nil)

        // Selecting a source switches to crop mode and removes .editCoverChooseImage from targets.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let ctx = CGContext(
            data: nil,
            width: 64,
            height: 36,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = ctx.makeImage() {
            coverSession.selectSource(LibraryUserCoverSource(image: cgImage))
        }
        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .editCoverCancel,
            .editCoverSave,
        ])
        #expect(app.isDialogAccessibilityTargetEnabled(.editCoverSave))
        app.library.coverEditingSession = nil

        // 2. Excerpt List Editor Dialog (L-06.2)
        let excerptSession = ExcerptListEditorSession(mode: .newList)
        app.excerpt.listEditorSession = excerptSession
        app.reconcileDialogAccessibilityFocus()

        var nameFieldFocused = false
        var descFieldFocused = false
        app.workbenchAccessibility.registerDialogTextInput(
            .excerptEditorName,
            setFocused: { nameFieldFocused = $0 },
            isCurrentlyFocused: { nameFieldFocused }
        )
        app.workbenchAccessibility.registerDialogTextInput(
            .excerptEditorDescription,
            setFocused: { descFieldFocused = $0 },
            isCurrentlyFocused: { descFieldFocused }
        )

        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .excerptEditorChooseImage,
            .excerptEditorNameField,
            .excerptEditorDescriptionField,
            .excerptEditorCancel,
            .excerptEditorSave,
        ])

        // Tab -> .dialogCloseButton -> .excerptEditorChooseImage -> .excerptEditorNameField
        _ = app.moveDialogAccessibilityFocus(forward: true)
        _ = app.moveDialogAccessibilityFocus(forward: true)
        _ = app.moveDialogAccessibilityFocus(forward: true)
        #expect(app.workbenchAccessibility.focusedDialogTarget == .excerptEditorNameField)
        #expect(nameFieldFocused)
        #expect(!descFieldFocused)

        // Tab -> .excerptEditorDescriptionField focuses Description and unfocuses Name.
        _ = app.moveDialogAccessibilityFocus(forward: true)
        #expect(app.workbenchAccessibility.focusedDialogTarget == .excerptEditorDescriptionField)
        #expect(!nameFieldFocused)
        #expect(descFieldFocused)

        // While on a text input, keyboard Return and Space are NOT consumed by dialog accessibility
        // so the text field / multiline text area receives them normally.
        #expect(!app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 36)))
        #expect(!app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 49)))

        // Tab -> .excerptEditorCancel unfocuses Description text input.
        _ = app.moveDialogAccessibilityFocus(forward: true)
        #expect(app.workbenchAccessibility.focusedDialogTarget == .excerptEditorCancel)
        #expect(!nameFieldFocused)
        #expect(!descFieldFocused)

        // Focus Name again, then press 1st Esc: clears outer focus ring while keeping typing focus!
        _ = app.moveDialogAccessibilityFocus(forward: false)
        #expect(app.workbenchAccessibility.focusedDialogTarget == .excerptEditorDescriptionField)
        #expect(descFieldFocused)
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(!app.workbenchAccessibility.isDialogActive)
        #expect(descFieldFocused)
        #expect(app.excerpt.listEditorSession != nil)

        // 2nd Esc closes Excerpt List Editor Dialog even while text input has typing focus.
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(app.excerpt.listEditorSession == nil)

        // 3. Rename Dialog (L-06.3)
        var renameFieldFocused = true
        app.workbenchAccessibility.registerDialogTextInput(
            .renameNewName,
            setFocused: { renameFieldFocused = $0 },
            isCurrentlyFocused: { renameFieldFocused }
        )
        app.workbenchAccessibility.setDialogTextInputActive(.renameNewName, isActive: true)
        app.library.renameSession = LibraryRenameSession(rootFolder: URL(fileURLWithPath: "/Media/ShowA"))
        app.reconcileDialogAccessibilityFocus()

        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .renameNewNameField,
            .renameCancel,
            .renameConfirm,
        ])
        // Pressing 1st Tab moves to .dialogCloseButton and unfocuses initial autofocus on New Name.
        #expect(app.moveDialogAccessibilityFocus(forward: true))
        #expect(app.workbenchAccessibility.focusedDialogTarget == .dialogCloseButton)
        #expect(!renameFieldFocused)
        app.library.renameSession = nil
    }

    @Test
    func remoteFolderDialogsConnectionAndBrowserSteps() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        let session = SMBFolderDialogSession()
        app.library.smbDialogSession = session
        app.reconcileDialogAccessibilityFocus()

        // Step 1 (Connection): SMB has 4 input fields.
        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .remoteAddressField,
            .remotePortField,
            .remoteUsernameField,
            .remotePasswordField,
            .remoteCancel,
            .remoteConnect,
        ])
        #expect(app.isDialogAccessibilityTargetEnabled(.remoteAddressField))
        #expect(app.isDialogAccessibilityTargetEnabled(.remoteConnect))

        // While submitting, fields and Connect remain in the Tab sequence but are disabled.
        session.isSubmitting = true
        #expect(!app.isDialogAccessibilityTargetEnabled(.remoteAddressField))
        #expect(!app.isDialogAccessibilityTargetEnabled(.remoteConnect))
        session.isSubmitting = false

        // Step 2 (Browser): Breadcrumb links (excluding last), enabled folder cards & enter buttons,
        // already-added folder enter buttons, and Back / Cancel / Add buttons.
        // Disabled folder cards and subtitle files are skipped.
        let rootURL = URL(string: "smb://nas.local:445/Media")!
        let subURL = URL(string: "smb://nas.local:445/Media/Anime")!
        let folderEnabledURL = URL(string: "smb://nas.local:445/Media/Anime/Season1")!
        let folderAddedURL = URL(string: "smb://nas.local:445/Media/Anime/Season2")!
        let subtitleFileURL = URL(string: "smb://nas.local:445/Media/Anime/ep01.srt")!

        let enabledFolderItem = WebDAVBrowserItem(url: folderEnabledURL, name: "Season1", kind: .folder)
        let addedFolderItem = WebDAVBrowserItem(url: folderAddedURL, name: "Season2", kind: .folder)
        let subtitleItem = WebDAVBrowserItem(url: subtitleFileURL, name: "ep01.srt", kind: .subtitle)

        session.existingRootFolders = [folderAddedURL.standardizedMediaURL]
        session.baseConfig = SMBRootConfig(
            name: "Media",
            address: "smb://nas.local:445/Media",
            username: "",
            password: ""
        )
        session.breadcrumbNodes = [
            RemoteFolderBreadcrumbNode(url: rootURL, title: "Media"),
            RemoteFolderBreadcrumbNode(url: subURL, title: "Anime"),
        ]
        session.items = [enabledFolderItem, addedFolderItem, subtitleItem]
        session.step = .browser

        let rootBreadcrumbID = session.breadcrumbNodes[0].id
        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .remoteBreadcrumb(rootBreadcrumbID),
            .remoteFolderCard(enabledFolderItem.id),
            .remoteFolderEnterButton(enabledFolderItem.id),
            .remoteFolderEnterButton(addedFolderItem.id),
            .remoteBack,
            .remoteCancel,
            .remoteAdd,
        ])

        // Activating .remoteFolderCard toggles selection on the folder item.
        app.workbenchAccessibility.setDialogFocus(.remoteFolderCard(enabledFolderItem.id), dialogID: .smb)
        #expect(app.activateDialogAccessibilityTarget(.remoteFolderCard(enabledFolderItem.id)))
        #expect(session.selectedFolderPaths.contains(enabledFolderItem.id))
        #expect(app.workbenchAccessibility.focusedDialogTarget == .remoteFolderCard(enabledFolderItem.id))

        app.library.smbDialogSession = nil
    }

    @Test
    func ankiExportDialogTargetsAndBadgeRemovalAutoExitsAccessibility() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        let session = AnkiExportSession(
            items: [],
            options: AnkiExportOptions(
                frontItems: [.cueText, .displayTitle],
                backItems: [.screenshot]
            ),
            folderURL: URL(fileURLWithPath: "/tmp"),
            onOptionsChange: { _ in }
        )
        app.tasks.ankiExportSession = session
        app.reconcileDialogAccessibilityFocus()

        #expect(app.currentDialogAccessibilityTargets() == [
            .dialogCloseButton,
            .ankiAddFront,
            .ankiRemoveItem(.front, .cueText),
            .ankiRemoveItem(.front, .displayTitle),
            .ankiAddBack,
            .ankiRemoveItem(.back, .screenshot),
            .ankiFileNameField,
            .ankiLocationField,
            .ankiChooseFolderButton,
            .ankiCancel,
            .ankiExport,
        ])

        // Focus .ankiRemoveItem(.front, .displayTitle) and activate it -> item is removed and
        // dialog accessibility focus automatically exits.
        let removeTarget = WorkbenchDialogAccessibilityTarget.ankiRemoveItem(.front, .displayTitle)
        app.workbenchAccessibility.setDialogFocus(removeTarget, dialogID: .ankiExport)
        #expect(app.workbenchAccessibility.focusedDialogTarget == removeTarget)

        #expect(app.activateDialogAccessibilityTarget(removeTarget))
        #expect(session.options.frontItems == [AnkiCardItem.cueText])
        #expect(app.workbenchAccessibility.focusedDialogTarget == nil)

        app.tasks.ankiExportSession = nil
    }

    @Test
    func filterDialogFileDetailAndTaskPanelStackingBehavior() {
        let (app, suiteName, userDefaults) = makeTestCoordinator()
        defer { userDefaults.removePersistentDomainAndPlist(forName: suiteName) }

        // 1. Filter Dialog (L-06.6)
        let filterSession = CueFacetFilterDialogSession(
            source: .search,
            filter: CueFacetFilter(),
            apply: { _ in }
        )
        app.filterDialog.session = filterSession
        app.reconcileDialogAccessibilityFocus()

        let filterTargets = app.currentDialogAccessibilityTargets()
        #expect(filterTargets.first == .dialogCloseButton)
        #expect(filterTargets.suffix(3) == [.filterReset, .filterCancel, .filterShow])
        // Reset is disabled when filter is empty.
        #expect(!app.isDialogAccessibilityTargetEnabled(.filterReset))

        // Activate a duration chip -> toggles chip and enables Reset.
        let durationChip = WorkbenchDialogAccessibilityTarget.filterChip(
            .duration,
            CueDurationFacet.underOneSecond.rawValue
        )
        #expect(filterTargets.contains(durationChip))
        app.workbenchAccessibility.setDialogFocus(durationChip, dialogID: .filter)
        #expect(app.activateDialogAccessibilityTarget(durationChip))
        #expect(filterSession.filter.durations.contains(.underOneSecond))
        #expect(app.workbenchAccessibility.focusedDialogTarget == durationChip)
        #expect(app.isDialogAccessibilityTargetEnabled(.filterReset))

        // Activate Reset -> clears filter and keeps focus on Reset.
        app.workbenchAccessibility.setDialogFocus(.filterReset, dialogID: .filter)
        #expect(app.activateDialogAccessibilityTarget(.filterReset))
        #expect(filterSession.filter.isEmpty)
        #expect(app.workbenchAccessibility.focusedDialogTarget == .filterReset)
        app.filterDialog.session = nil

        // 2. File / Folder Detail Dialog (L-06.8)
        app.library.fileDetailSession = FileDetailDialogSession(
            kind: .folder(
                FileDetailFolderInfo(
                    path: "/Media/ShowA",
                    name: "ShowA",
                    isRootFolder: true,
                    folderCount: 1,
                    videoCount: 1,
                    subtitleCount: 1,
                    addedAt: nil,
                    updatedAt: nil
                )
            )
        )
        #expect(app.currentDialogAccessibilityTargets() == [.dialogCloseButton])
        app.library.fileDetailSession = nil

        // 3. Task Panel & Stacked Confirmation Dialog (L-06.9 ~ L-06.11)
        app.tasks.openPanel()
        app.reconcileDialogAccessibilityFocus()
        #expect(app.activeDialogAccessibilityID() == .taskPanel)
        #expect(app.currentDialogAccessibilityTargets() == [
            .taskPanelTab(.current),
            .taskPanelTab(.completed),
            .taskPanelTab(.incomplete),
            .dialogCloseButton,
        ])

        // Focus and activate Completed tab -> switches tab and keeps focus on Completed tab.
        app.workbenchAccessibility.setDialogFocus(.taskPanelTab(.completed), dialogID: .taskPanel)
        #expect(app.activateDialogAccessibilityTarget(.taskPanelTab(.completed)))
        #expect(app.tasks.selectedTab == .completed)
        #expect(app.workbenchAccessibility.focusedDialogTarget == .taskPanelTab(.completed))

        // Opening a Confirmation Dialog on top of Task Panel clears Task Panel focus
        // and routes dialog accessibility to Confirmation Dialog.
        app.confirmation.session = WorkbenchConfirmationSession(
            title: "Delete Record",
            message: "Delete?",
            destructiveTitle: "Delete",
            cancelTitle: "Cancel",
            onDestructive: { app.confirmation.session = nil },
            onCancel: { app.confirmation.session = nil }
        )
        app.reconcileDialogAccessibilityFocus()
        #expect(app.activeDialogAccessibilityID() == .confirmation)
        #expect(app.workbenchAccessibility.focusedDialogTarget == nil)

        // Pressing Esc closes only the topmost Confirmation Dialog and leaves Task Panel open
        // in its default unfocused state.
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(app.confirmation.session == nil)
        #expect(app.tasks.isPanelOpen)
        #expect(app.activeDialogAccessibilityID() == .taskPanel)
        #expect(app.workbenchAccessibility.focusedDialogTarget == nil)

        // Pressing Esc again closes Task Panel.
        #expect(app.handleWorkbenchKeyDown(makeKeyEvent(keyCode: 53)))
        #expect(!app.tasks.isPanelOpen)
    }
}
