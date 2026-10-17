# Implementation Record: Export to Anki Card Layout and Drag Redesign

- Date: 2026-10-17
- Requirement: `docs/human/requirements/20261017-UI-Export To Anki Card Layout And Drag Redesign.md`
- Design Authority:
  - `docs/human/design/ui/UI Design System.md`
  - `docs/human/design/ui/UI Components & Patterns.md`
  - `docs/human/design/ui/UI Layouts & Pages.md`

## Implementation Steps

1. **Tokens (`WorkbenchControlMetrics`)**:
   - Added `redesignAnkiExportSideTitleFontSize: CGFloat = 16` (`--font-size-anki-export-side-title`).
   - Replaced `redesignAnkiExportCardBoxMinHeight` (`208`) with fixed `redesignAnkiExportCardBoxHeight: CGFloat = 288` (`--height-anki-export-card-box`).
   - Updated `redesignAnkiExportDraggingOpacity` (`--opacity-anki-export-dragging`) from `0.35` to `0.5`.
   - Removed obsolete tokens `redesignAnkiExportAvailablePoolHeight`, `redesignAnkiExportDropSlotHeight`, and `redesignAnkiExportDropLineHeight`.
2. **Independent Card Item Management (`AnkiExportOptions` & `AnkiExportSession`)**:
   - Replaced global `availableItems` with side-specific `remainingItems(for side: AnkiExportSide)`.
   - Added `addItem(_:to:)`, `removeItem(_:from:)`, and `moveItem(_:on:to:)` so `Front` and `Back` manage items independently (no duplicates within the same side, while allowing the same item on both sides).
3. **Export to Anki Dialog Layout, `+` Button, Tooltip & 1D Drag Reordering (`AnkiExportDialog.swift` & `ContentView.swift`)**:
   - Removed the `Available Items` pool, `Card Layout` group label, and outer grey wrapper (`--color-settings-group-bg`).
   - Added the top header row for `Front` and `Back` (`16px` Semibold `600` title on the left, `32×32px` `+` `WorkbenchButton` on the right).
   - Configured the `+` button to open a downward `WorkbenchPopoverPanel` (`C-04.1 Dropdown Menu`) via `MenuGateClientView` when `remaining.count >= 2`, directly append the final item when `remaining.count == 1`, and disable when `remaining.isEmpty`.
   - Attached `.workbenchTooltip(scenarioID: "anki_export.card.add_item", ...)` for both enabled (`tooltip.anki_export.add_item`) and disabled (`tooltip.disabled.anki_export.all_items_added`) states across `en`, `zh-Hans`, and `zh-Hant`.
   - Replaced `NSItemProvider` `.onDrag`/`.onDrop` with a 1D vertical `DragGesture` inside each `288px` white card box, translating the dragged item at `0.5` opacity along the Y-axis and smoothly shifting sibling rows across midpoints (`40pt` step).
   - Removed the empty-card placeholder hint (`Drag items here`) while retaining centered danger validation messaging and red card border when `Front` or `Back` is empty on `Export`.
4. **Localization & Unit Tests**:
   - Removed obsolete `anki_export.available_items`, `anki_export.card_layout`, `anki_export.available.empty`, and `anki_export.card.empty_hint` keys and added `tooltip.anki_export.add_item` and `tooltip.disabled.anki_export.all_items_added` in `en.lproj`, `zh-Hans.lproj`, and `zh-Hant.lproj`.
   - Updated `AnkiPackageExporterTests.swift` and `TooltipTests.swift`.

## Verification

- Ran `swift test --filter "anki|Tooltip|Localization"` in `apps/macos-native`.
- Verified independent `Front`/`Back` item addition, removal, 1D reordering, validation, and localization parity across all three bundled languages.

## Outcome

- Matched the requirement specification in `docs/human/requirements/20261017-UI-Export To Anki Card Layout And Drag Redesign.md`.
