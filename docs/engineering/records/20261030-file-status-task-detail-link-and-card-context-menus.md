# 2026-10-30 File Status Task Detail Link and Card Context Menus

## Requirement Reference
- `docs/human/requirements/20261030-UI-File Status Task Detail Link And Card Context Menus.md`

## Summary of Changes
1. **File Page Status Indicator Refinement & Interactive Task Detail Link (`WorkbenchStatusIndicator.swift`, `WorkbenchFileView.swift`, `PointerHover.swift`, `InterfaceLayerRegistry.swift`)**:
   - Removed the leading `arrow-clockwise` icon in the `.idle` state of the File page status indicator so both `Last Updated: yy-MM-dd HH:mm` and `Last Updated: --` display plain text only, while preserving the leading icons for temporary states (`In Progress`: `Spinner`; `Completed`: `check-circle`; `Failed`: `warning`).
   - Added `onTapText: (() -> Void)?` support to `WorkbenchStatusIndicator` so only the status text region is interactive (`onPointerHover(showsHand: true)`), leaving any leading icon in temporary states non-interactive.
   - When hovered, clickable status text keeps its existing text color (`--color-text-secondary` for Idle/In Progress, `--color-success-text` for Completed, `--color-danger-text` for Failed), displays a bottom underline matching the text color with thickness `--width-interactive-text-underline` (`1px`) and offset `--offset-interactive-text-underline` (`2px`) below `.firstTextBaseline`, and switches the window cursor to `Grab` (`pointingHand`).
   - When never indexed (`Last Updated: --`), `onTapText` is `nil`, preserving static text with default arrow cursor and no Hover underline.
2. **File Status Target Task Mapping & Deleted Record Toast (`IndexingStore.swift`, `TaskQueueStore.swift`, `AppCoordinator.swift`, `AppCoordinator+Indexing.swift`, `Toast.swift`, `Localizable.strings`)**:
   - Added `TaskRecordKind.isFileStatusTask` covering the 4 library task kinds (`Index All`, `Index`, `Add Folder`, `Remove Folder`), excluding Rename and Anki Export tasks.
   - Tracked `activeFileStatusTaskID`, `lastFileStatusNoticeTaskID`, and `lastCompletedFileStatusTaskID` on `TaskQueueStore`, and persisted `lastUpdatedTaskID` alongside `lastUpdatedDate` in `IndexingStore` (with startup fallback seeding from `lastCompletedFileStatusTaskID` for pre-existing installations).
   - Implemented `AppCoordinator.openFileStatusTaskDetail(for:)` to open the corresponding task's `Task Info` (`TaskDetailDialog`) directly without opening `TaskPanel`, or show `TaskToastRequest.taskRecordNotFound` (`scenarioID: "task.detail.record_not_found"`, `icon: .warning`, `duration: ToastDuration.alert` `3.0s`) localized in English (`Task record no longer exists`), Simplified Chinese (`任务记录已不存在`), and Traditional Chinese (`任務記錄已不存在`) when the target task record has been deleted.
3. **File Card & Task Card Right-Click Context Menus (`WorkbenchPopoverControls.swift`, `WorkbenchFileView.swift`, `TaskPanel.swift`)**:
   - Added `WorkbenchCardRightClickMonitor` and updated `WorkbenchCardMenuState.anchorFrame` to optional `CGRect?` (`isButtonAnchored: Bool`) so cards distinguish between a menu anchored to the `...` button (`isButtonMenuOpen == true`, `isCardMenuOpen == true`) and a menu opened by right-clicking the card (`isButtonMenuOpen == false`, `isCardMenuOpen == true`).
   - Wired right-click context menu opening across all File cards (Level 1 root folder cards, Level 2 subfolder cards, Level 2/3 video and subtitle cards; excluding episode group header bars) and all Task cards across `Current`, `Completed`, and `Incomplete` tabs in `TaskPanel`, supporting direct right-click menu relay across cards.

## Verification
- Added unit tests in `FileRouteNavigationTests.swift`, `TaskCardMenuTests.swift`, and `PointerHoverGateTests.swift` covering File status task target mapping across all status states, direct `TaskDetailDialog` presentation without opening `TaskPanel`, deleted task record warning Toast and trilingual localization, interactive status text `Grab` cursor behavior, and `isButtonAnchored` state separation between `...` button clicks and card right-clicks.
- Ran `swift test --package-path apps/macos-native --filter "FileRouteNavigationTests|TaskCardMenuTests|PointerHoverGateTests"`.
- Outcome matched expectations.
