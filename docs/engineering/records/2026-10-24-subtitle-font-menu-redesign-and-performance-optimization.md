# 2026-10-24 Subtitle Font Menu Redesign And Performance Optimization

## Requirement Reference
- `docs/human/requirements/20261024-UI-Subtitle Font Menu Redesign And Performance Optimization.md`

## Referenced Design Documents
- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Page - Settings.md`

## Implementation Summary
1. **Standardized trigger button and menu shell (`SettingsSubtitleCategory.swift`, `WorkbenchControlMetrics.swift`, `Localizable.strings`)**:
   - Replaced the non-standard search-based font popup and its private size constants (`redesignSettingsFontMenuWidth` / `redesignSettingsFontMenuListMaxHeight`) with a standard `C-04.1 Menu / Dropdown Menu` (`--max-height-menu: 240px`, `C-07.1 Scrollbar / Vertical`) and removed the obsolete `settings.subtitle.font.search_placeholder` and `settings.subtitle.font.empty` keys across all localization bundles.
   - Updated the Font trigger button (`--width-settings-popup: 220px`) to follow standard button state rules (`Default` / `Hover` / `Pressed` / `Open`), keeping the elevated surface and primary text color while open without applying `--color-border-focus`.
   - Structured the dropdown menu with `System Font` first (`C-04.3 Radio Menu Item`), followed by a `C-04.4 Menu Divider`, followed by alphabetically sorted system font families rendered in standard `--font-family-base` without per-font face instantiation.
2. **Full menu modality in the Settings window (`SettingsView.swift`, `SettingsSubtitleCategory.swift`, `AppDelegate.swift`, `InterfaceLayerRegistry.swift`, `PointerHover.swift`, `CardHighlightModel.swift`, `MenuGate.swift`, `MenuHighlightModel.swift`)**:
   - Scoped `PointerHoverSession` and `CardHighlightModel` layer-freeze notifications to their owning `InterfaceLayerRegistry` and attached a dedicated `InterfaceLayerRegistry` and `MenuGate` to the Settings window so opening the Font menu freezes Settings scroll/hover interactions without affecting the main window.
   - Hosted the Font menu in an `NSHostingView` (`MenuHostingView`) positioned via `MenuPlacement.openingFrame(..., shrinksToFit: true)` and wired `MenuHighlightModel` for unified pointer hover & keyboard navigation (`Up` / `Down` / `Return` / `Space` / `Esc`), `300ms` wheel-scroll hover suppression, outside-click dismissal without click-through, and window deactivation cancellation.
3. **Cached font list and quantized row virtualization (`SettingsSubtitleCategory.swift`, `WorkbenchScrollView.swift`)**:
   - Cached sorted system font family strings once via `SubtitleFontFamilyCatalog` (`NSFontManager.shared.availableFontFamilies`) and precomputed the widest row width so menu panel width remains constant during scrolling.
   - Added `WorkbenchScrollViewController` to `WorkbenchScrollView` for $O(1)$ programmatic vertical range reveal (`revealVerticalRange(minY:maxY:)`) and scroll offset reporting, mounting only the visible slice (`overscanRows = 8`, `quantizeStep = 4`) while preserving exact spacer heights and divider placement.

## Verification
- Updated and added unit tests in `WorkbenchInputControlsTests.swift` (`subtitleFontMenuFollowsStandardDropdownStructureVirtualizesHundredsOfFontsAndRevealsKeyboardHighlight`), verifying standard structure (`System Font` + divider + sorted fonts), no default highlight on open, quantized virtualization across 500 fonts (mounting only 28 rows), minimum-scroll reveal on keyboard navigation, and selection updates.
- Ran `swift test --package-path apps/macos-native --filter "WorkbenchInputControlsTests|AppLocalizationTests|MenuHighlightModelTests|MenuInputBarrierTests|MenuPanelHeightTests"` (all 40 tests passed).
