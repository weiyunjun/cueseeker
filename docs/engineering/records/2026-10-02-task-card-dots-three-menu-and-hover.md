# Task Card Dots Three Menu And Hover

Human-owned documents:

- `docs/human/requirements/20261002-UI-Task Card Dots Three Menu And Hover.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Toast Usage Registry.md`

## Why

1. **Card Action Consolidation & Secondary Confirmations**:
   - Task cards (Current and History) now expose actions through a consistent 32×32px `dots-three` pure icon button.
   - Current tasks offer `Remove Task` (Destructive style, `minus-circle`), while History records offer `Delete Record` (Destructive style, `trash`).
   - Clicking an available menu item dismisses the menu and triggers the existing secondary Confirmation Dialog (`Remove Task` or `Delete Record`).
2. **Card Hover Feedback and Token Hierarchy**:
   - Task cards previously used `--color-bg-dialog` as background without visual hover feedback.
   - Standardizing Task card normal background to `--color-table-bg` (`#FFFFFF` Light / `#26262A` Dark) and hover background to `--color-row-hover` (`#F9FAFB` Light / `#2E2E33` Dark) provides consistent hover feedback across themes while preserving `--color-border-control`.
   - The `dots-three` button hover and open state uses `--color-row-selected` (`#F3F4F6` Light / `#36363C` Dark).
3. **Button Availability & Menu Item State Alignment**:
   - The `dots-three` button is always enabled and clickable on both Task and File cards.
   - Task constraints (e.g. running folder removal or rename cannot be cancelled) and File constraints (blocked library operations) are reflected as disabled/grayed-out states inside the menu, rather than disabling the entry button.
4. **State Change Interception via Toast**:
   - If a task transitions from `In Progress` to `Completed` or `Incomplete` while the menu is open, clicking `Remove Task` is intercepted. The confirmation dialog is suppressed and a 3-second warning Toast (`Task status has changed` / `任务状态已经改变`) is displayed.

## What changed

- **Shared Card Menu Components**:
   - In `WorkbenchControls.swift`: Defined shared `WorkbenchCardMenuItem`, `WorkbenchCardMenuState`, and `WorkbenchCardMenuPopover`.
   - In `WorkbenchFileView.swift`: Aliased local menu structures to the shared components and removed the `.disabled` modifier on the `dots-three` button, keeping it always enabled.
- **TaskPanel**:
   - Updated `TaskCardContainer`: Added hover detection with `--color-row-hover` and default `--color-table-bg`.
   - Updated `TaskCurrentCard` and `TaskHistoryCard`: Added trailing 32×32px `dots-three` `WorkbenchIconButton` (`isOpen: isMenuOpen`, `hoverBackground: rowSelected`) with `redesignCardTrailingIconButtonTopOffset` (18px top margin).
   - Added coordinate space `TaskPanel.cardCoordinateSpace` and `MenuGateClientView(kind: .cardMenu)` overlay supporting keyboard navigation, Esc/outside click dismissal, and auto-flipping placement.
   - Connected secondary confirmation dialogs for `Cancel Task` and `Delete Record`.
   - Implemented real-time task state verification in `handleCancelTask`, intercepting ended tasks with `TaskToastRequest.taskStatusChanged`.
- **Toast & Localization**:
   - In `ContentView.swift`: Elevated `ToastStackView` to `zIndex(300)` above `dialogLayer` (`zIndex(200)`), ensuring toasts display on top of modal dialogs and backdrops.
   - In `Toast.swift`: Added `TaskToastRequest.taskStatusChanged` (scenarioID: `task.action.status_changed`, icon: `warning`, duration: 3.0s).
   - In `en`, `zh-Hans`, `zh-Hant` `Localizable.strings`: Added `task.menu.remove` ("Remove Task" / "移除任务" / "移除任務"), `task.menu.delete`, and `toast.task_status_changed`.
- **Automated Tests**:
   - Added `apps/macos-native/Tests/CueSeekerAppTests/TaskCardMenuTests.swift`:
     - Verified menu item properties and destructive styling for `Remove Task` and `Delete Record`.
     - Verified state change interception and Toast parameters.
     - Verified card geometry (68px baseline, 18px top and bottom margins, pinned top upon Line 3 expansion) and color tokens in Light and Dark modes.
     - Verified popover fitting size without overflow.

## Verification

- Automated tests:
  - `swift test --package-path apps/macos-native --filter TaskCardMenuTests`
  - `swift test --package-path apps/macos-native --filter FileCardMenuTests`
- Human owner will perform manual E2E acceptance.
