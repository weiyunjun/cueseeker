import SwiftUI
import AppKit

enum WorkbenchControlMetrics {
    static let searchFieldHeight: CGFloat = 46
    static let controlHeight: CGFloat = 40
    static let cornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
    static let iconSize: CGFloat = 21

    // ==========================================
    // Redesign Tokens (对接新的 Token 规范)
    // ==========================================
    /// --height-control: 36px
    static let redesignHeight: CGFloat = 36
    /// --radius-control: 8px
    static let redesignCornerRadius: CGFloat = 8
    /// --height-field: 30px
    static let redesignFieldHeight: CGFloat = 30
    /// --height-control (Search box, unified): 36px
    static let redesignSearchHeight: CGFloat = redesignHeight
    /// --radius-field: 6px
    static let redesignFieldRadius: CGFloat = 6
    /// --radius-search: 9999px
    static let redesignSearchRadius: CGFloat = 9999
    /// --size-inline-clear-button: 24px
    static let redesignInlineClearButtonSize: CGFloat = 24
    /// --padding-control-x: 14px
    static let redesignControlPaddingX: CGFloat = 14
    /// --padding-field-x: 10px
    static let redesignFieldPaddingX: CGFloat = 10
    /// --width-form-label: 72px
    static let redesignFormLabelWidth: CGFloat = 72
    /// Provisional --size-inline-clear-symbol-font-size-macos: 14px icon box (document: 11pt)
    static let inlineClearSymbolFontSizeMacOS: CGFloat = 14
    /// --size-inline-clear-icon: 16px
    static let inlineClearIconSize: CGFloat = 16
    /// --border-width-control: 1px
    static let redesignControlBorderWidth: CGFloat = 1
    /// --focus-ring-width: 2px
    static let redesignFocusRingWidth: CGFloat = 2
    /// --focus-ring-offset: 2px
    static let redesignFocusRingOffset: CGFloat = 2
    /// Centerline expansion that preserves the documented edge-to-ring offset.
    static let redesignFocusRingPathExpansion: CGFloat =
        redesignFocusRingOffset + redesignFocusRingWidth / 2
    /// --radius-inline-clear-button: 9999px
    static let redesignInlineClearButtonRadius: CGFloat = 9999
    /// Provisional --size-control-icon: 21px icon box (document: 16px)
    static let redesignControlIconSize: CGFloat = 21
    /// --weight-control-icon: medium
    static let redesignControlIconWeight: Font.Weight = .medium
    /// Provisional --size-dialog-close-icon: 16px icon box (document: 12px)
    static let redesignDialogCloseIconSize: CGFloat = 16
    /// --size-dialog-close-button: 24px
    static let redesignDialogCloseButtonSize: CGFloat = 24
    /// The close button is placed by what the eye sees, so the glyph's own
    /// ink is the figure the offsets are built from. Phosphor's `x` draws its
    /// two strokes across 144 of its 256-unit grid, and each round cap adds
    /// half the line width beyond that on either end.
    static let redesignDialogCloseGlyphInk: CGFloat =
        redesignDialogCloseIconSize * 144 / 256
        + (AppIconLineWidth.bySize[redesignDialogCloseIconSize] ?? 0)
    /// The slack the close button's box keeps around its glyph on each side.
    static let redesignDialogCloseBoxSlack: CGFloat =
        (redesignDialogCloseButtonSize - redesignDialogCloseGlyphInk) / 2
    /// --inset-dialog: 24px. Every dialog edge keeps the same visual inset,
    /// measured to what is visible: the text box for a text's horizontal edge,
    /// the cap line for the title's top, the visible border for a control, and
    /// the glyph ink for an icon button.
    static let redesignDialogInset: CGFloat = 24
    /// --radius-dialog: 10px, a circular corner. The corner the system sheet
    /// cut every dialog to, over the dialog's own.
    static let redesignDialogCornerRadius: CGFloat = 10
    /// --width-dialog-small: 360px. Every dialog's width is one of these tiers.
    static let redesignDialogWidthSmall: CGFloat = 360
    /// --width-dialog-medium: 480px
    static let redesignDialogWidthMedium: CGFloat = 480
    /// --width-dialog-large: 600px
    static let redesignDialogWidthLarge: CGFloat = 600
    /// --width-dialog-x-large: 720px
    static let redesignDialogWidthXLarge: CGFloat = 720
    /// What a dialog keeps clear of the window's edges: --spacing-6.
    static let redesignDialogWindowMargin = redesignSpacing6
    /// --gap-cover-dialog-region: 20px. The gap between the header, the main
    /// region and the footer of the two dialogs that carry a cover.
    static let redesignCoverDialogRegionGap: CGFloat = 20
    /// The Excerpt List Editor's cover: the small dialog's content width, which
    /// its one-column layout is, so the cover keeps one size in both layouts.
    static let redesignExcerptListEditorCoverWidth =
        redesignDialogWidthSmall - 2 * redesignDialogInset
    /// The two-column layout's form column: what the x-large dialog leaves
    /// beside the cover.
    static let redesignExcerptListEditorWideFormWidth =
        redesignDialogWidthXLarge - 2 * redesignDialogInset
        - redesignSpacing6 - redesignExcerptListEditorCoverWidth
    /// The Description box ends on the bottom of the cover's first support-text
    /// line, so its reserved validation message line sits opposite the second
    /// support-text line. Above the box the form column holds the List Name
    /// field — label, field and its reserved message line — and the
    /// Description's own label. Both layouts keep this height.
    static let redesignExcerptListEditorDescriptionHeight: CGFloat = {
        func lineHeight(size: CGFloat, weight: NSFont.Weight) -> CGFloat {
            NSLayoutManager().defaultLineHeight(
                for: NSFont.systemFont(ofSize: size, weight: weight)
            )
        }
        let label = lineHeight(size: redesignFontSizeControl, weight: .medium)
        let message = lineHeight(size: redesignFontSizeCaption, weight: .regular)
        let supportLine = lineHeight(size: redesignFontSizeBody, weight: .regular)
        let coverHeight = redesignExcerptListEditorCoverWidth / redesignLibraryCoverAspectRatio
        return (coverHeight + redesignSpacing3 + supportLine)
            - (label + redesignSpacing2 + redesignFieldHeight + redesignSpacing1 + message)
            - redesignSpacing2
            - (label + redesignSpacing2)
    }()
    /// Dialog title type. The cap-line give-back below is derived from it, so
    /// the two must stay together.
    static let redesignDialogTitleFontSize: CGFloat = 20
    /// A single line of text starts below its own top edge by the half-leading
    /// plus the run from the ascender down to the cap height. The inset is
    /// measured to the cap line, so the container's top padding gives that
    /// distance back. This is what CSS spells `text-box-edge: cap`.
    static let redesignDialogTitleCapTopInset: CGFloat = {
        let font = NSFont.systemFont(ofSize: redesignDialogTitleFontSize, weight: .semibold)
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let halfLeading = (lineHeight - (font.ascender - font.descender)) / 2
        return halfLeading + font.ascender - font.capHeight
    }()
    /// The dialog's own top padding. The other three edges use the inset.
    static let redesignDialogTopPadding: CGFloat =
        redesignDialogInset - redesignDialogTitleCapTopInset
    /// Where the close button's box sits so that its glyph lands on the inset.
    static let redesignDialogCloseAnchorInset: CGFloat =
        redesignDialogInset - redesignDialogCloseBoxSlack
    /// --size-detail-file-icon-container: 40px
    static let redesignDetailFileIconContainerSize: CGFloat = 40
    /// --size-detail-file-icon-glyph: 20px
    static let redesignDetailFileIconGlyphSize: CGFloat = 20
    /// --line-height-detail-file-title: 20px
    static let redesignDetailFileTitleLineHeight: CGFloat = 20
    /// --min-width-detail-label: 100px
    static let redesignDetailLabelMinWidth: CGFloat = 100
    /// --min-width-detail-index-label: 40px
    static let redesignDetailIndexLabelMinWidth: CGFloat = 40
    /// Provisional --size-checkbox: 21px icon box (document: 16px)
    static let redesignCheckboxSize: CGFloat = 21
    /// Provisional --size-select-indicator: 16px icon box (document: 12pt)
    static let redesignSelectIndicatorSymbolFontSizeMacOS: CGFloat = 16
    /// --weight-select-indicator: semibold
    static let redesignSelectIndicatorWeightMacOS: Font.Weight = .semibold
    /// --font-size-control: 14px
    static let redesignFontSizeControl: CGFloat = 14
    /// --font-weight-control: 500
    static let redesignFontWeightControl: Font.Weight = .medium
    /// Provisional --size-button-icon: 18px icon box (document: 14px)
    static let redesignButtonIconSize: CGFloat = 18
    /// --weight-button-icon: medium
    static let redesignButtonIconWeight: Font.Weight = .medium
    /// Provisional --size-inline-add-symbol-font-size-macos: 21px icon box (document: 16pt)
    static let redesignInlineAddSymbolFontSizeMacOS: CGFloat = 21
    /// Provisional --size-menu-item-symbol-font-size-macos: 18px icon box (document: 14pt)
    static let redesignMenuItemSymbolFontSizeMacOS: CGFloat = 18
    /// --padding-menu-item: 10px
    static let redesignMenuItemHorizontalPadding: CGFloat = 10
    /// Menu Item padding on a side whose slot holds an icon rather than text.
    ///
    /// A glyph carries transparent room inside its own box, so matching the
    /// text side's padding reads looser than it measures. Trimming two points
    /// puts the two sides back in visual balance.
    static let redesignMenuItemTrailingIconPadding: CGFloat =
        redesignMenuItemHorizontalPadding - 2
    /// --height-action-menu-item, --height-select-menu-item: 32px
    ///
    /// A menu is a list to read down, not a row of controls to hit, so it is
    /// denser than a button: the 14px label's 20px line box plus six points
    /// above and below it.
    static let redesignMenuItemHeight: CGFloat = 32
    /// --radius-menu: 16px -> 12px
    static let redesignMenuRadius: CGFloat = 12
    /// --radius-action-menu-item, --radius-select-menu-item: 6px
    ///
    /// Concentric with the menu around it: the menu's own radius less the
    /// padding between the two. Equal radii would leave the corners of the
    /// highlight bulging into corners of the menu.
    static let redesignMenuItemRadius: CGFloat =
        redesignMenuRadius - MenuMetrics.padding
    /// --inset-menu-divider
    ///
    /// Where a divider's ends sit, measured from the menu's edge: the menu's
    /// own padding plus the item's. That is where an item's content starts,
    /// whether the content begins with an icon or straight with the label, so
    /// one figure covers menus that have leading icons and menus that do not.
    static let redesignMenuDividerInset: CGFloat =
        MenuMetrics.padding + redesignMenuItemHorizontalPadding
    /// --gap-menu-divider: the room a divider keeps above and below itself.
    static let redesignMenuDividerGap: CGFloat = 4
    /// --size-icon-button: 32px
    static let redesignIconButtonSize: CGFloat = 32
    /// --height-filter-chip: 32px
    static let redesignFilterChipHeight: CGFloat = 32
    /// --width-filter-chip-count-placeholder: 24px, the still block in place
    /// of a count that is not known yet.
    static let redesignFilterChipCountPlaceholderWidth: CGFloat = 24
    /// --height-filter-chip-count-placeholder: 12px
    static let redesignFilterChipCountPlaceholderHeight: CGFloat = 12
    /// --max-width-filter-chip: 332px, two chips to a line with five-digit
    /// counts; a longer name ends in an ellipsis.
    static let redesignFilterChipMaxWidth: CGFloat = 332
    /// --size-spinner: 16px
    static let redesignSpinnerSize: CGFloat = 16
    /// --width-spinner-stroke: 2px
    static let redesignSpinnerStrokeWidth: CGFloat = 2
    /// --duration-spinner-motion: 1s, one turn at --easing-spinner-motion
    /// (linear).
    static let redesignSpinnerMotionDuration: Double = 1
    /// --height-table-header: 44px
    static let redesignTableHeaderHeight: CGFloat = 44
    /// --spacing-1: 4px
    static let redesignSpacing1: CGFloat = 4
    /// --spacing-2: 8px
    static let redesignSpacing2: CGFloat = 8
    /// --spacing-3: 12px
    static let redesignSpacing3: CGFloat = 12
    /// --spacing-4: 16px
    static let redesignSpacing4: CGFloat = 16
    /// --spacing-5: 20px
    static let redesignSpacing5: CGFloat = 20
    /// --spacing-6: 24px
    static let redesignSpacing6: CGFloat = 24
    /// --spacing-8: 32px
    static let redesignSpacing8: CGFloat = 32
    /// --height-keycap: 22px
    static let redesignKeycapHeight: CGFloat = 22
    /// --radius-keycap: 4px
    static let redesignKeycapRadius = redesignSpacing1
    /// Keycap Padding Inline: --spacing-1
    static let redesignKeycapHorizontalPadding = redesignSpacing1
    /// --gap-app-topbar-content: 12px
    static let redesignAppTopbarContentAfterToggleGap: CGFloat = 12
    /// --gap-app-topbar-toggle-after-window-controls: 20px
    static let redesignAppTopbarToggleGapAfterWindowControls: CGFloat = 20
    /// --padding-header-trigger-x: 12px
    static let redesignPaddingHeaderTriggerX: CGFloat = 12
    /// --radius-table-cell-hover: 8px
    static let redesignTableCellHoverRadius: CGFloat = 8
    /// --padding-table-cell-hover-x: 12px
    static let redesignTableCellHoverPaddingX = redesignPaddingHeaderTriggerX
    /// --padding-table-cell-hover-y: 8px
    static let redesignTableCellHoverPaddingY: CGFloat = 8
    /// --font-size-table: 14px
    static let redesignFontSizeTable: CGFloat = 14
    /// --font-size-table-header: 14px
    static let redesignFontSizeTableHeader: CGFloat = 14
    /// --font-size-body: 14px
    static let redesignFontSizeBody: CGFloat = 14
    /// --font-size-caption: 12px
    static let redesignFontSizeCaption: CGFloat = 12
    /// --font-size-toast: 16px
    static let redesignFontSizeToast: CGFloat = 16
    /// --size-toast-icon: 23px, one of the sizes the Icon Registry documents.
    static let redesignToastIconSize: CGFloat = 23
    /// --width-toast-max: 400px
    static let redesignToastMaxWidth: CGFloat = 400
    /// --width-tooltip-max: 280px
    static let redesignTooltipMaxWidth: CGFloat = 280
    /// --delay-tooltip-hover: 1s
    static let redesignTooltipHoverDelay: TimeInterval = 1.0
    /// --delay-tooltip-skip-window: 0.3s
    static let redesignTooltipSkipWindowDelay: TimeInterval = 0.3
    /// Vertical padding derived from --height-control (36px) and the single-line
    /// height of --font-size-control (14px, 500), so single-line tooltips are
    /// 36px tall and wrapped tooltips preserve identical top/bottom padding.
    static let redesignTooltipVerticalPadding: CGFloat = {
        let lineHeight = NSLayoutManager().defaultLineHeight(
            for: NSFont.systemFont(ofSize: redesignFontSizeControl, weight: .medium)
        )
        return (redesignHeight - lineHeight) / 2
    }()
    /// --radius-chip
    static let redesignChipRadius: CGFloat = 6
    /// --padding-chip-x
    static let redesignChipHorizontalPadding: CGFloat = 10
    /// --padding-chip-y
    static let redesignChipVerticalPadding: CGFloat = 4
    /// --height-app-sidebar-item: 32px
    static let redesignAppSidebarItemHeight: CGFloat = 32
    /// --height-app-topbar: 54px — unified topbar height across Workbench, Playback, and Playback Overlay.
    static let redesignAppTopbarHeight: CGFloat = 54
    /// Window controls band height: 45px — keeps native traffic light buttons centered at their original position.
    static let redesignWindowControlsBandHeight: CGFloat = 45
    /// --height-workbench-topbar: 54px — the Workbench topbar itself.
    static let redesignWorkbenchTopbarHeight: CGFloat = 54
    /// --width-app-sidebar: 240px
    static let redesignAppSidebarWidth: CGFloat = 240
    /// --width-window-default: 1000px
    static let redesignWindowDefaultWidth: CGFloat = 1_000
    /// --min-width-window / --min-width-workbench-page-content: 600px
    static let redesignWindowMinimumWidth: CGFloat = 600
    /// --min-height-window: 560px
    static let redesignWindowMinimumHeight: CGFloat = 560
    /// --duration-sidebar-motion: 0.18s
    static let redesignSidebarMotionDuration: Double = 0.18
    /// --width-border-hairline: 1px
    static let redesignBorderHairlineWidth: CGFloat = 1
    /// --width-settings-sidebar: 184px
    static let redesignSettingsSidebarWidth: CGFloat = 184
    /// --width-settings-window: 880px, the Settings window's default width
    /// and also its minimum
    static let redesignSettingsWindowWidth: CGFloat = 880
    /// --height-settings-window: 640px, the Settings window's default height
    static let redesignSettingsWindowHeight: CGFloat = 640
    /// --min-height-settings-window: 420px
    static let redesignSettingsWindowMinimumHeight: CGFloat = 420
    /// --height-settings-titlebar: 36px, the band the window controls sit in
    /// above the Settings sidebar and page
    static let redesignSettingsTitlebarHeight: CGFloat = 36
    /// --width-settings-number-field: 114px
    static let redesignSettingsNumberFieldWidth: CGFloat = 114
    /// --width-settings-popup: 180px
    static let redesignSettingsPopupWidth: CGFloat = 180
    /// --size-settings-color-swatch: 18px
    static let redesignSettingsColorSwatchSize: CGFloat = 18
    /// --radius-settings-color-swatch: 4px
    static let redesignSettingsColorSwatchRadius: CGFloat = 4
    /// --size-settings-color-preset-swatch: 22px
    static let redesignSettingsColorPresetSwatchSize: CGFloat = 22
    /// --columns-settings-color-preset: 6
    static let redesignSettingsColorPresetColumns: Int = 6
    /// --width-settings-font-menu: 240px
    static let redesignSettingsFontMenuWidth: CGFloat = 240
    /// --max-height-settings-font-menu-list: 220px
    static let redesignSettingsFontMenuListMaxHeight: CGFloat = 220
    /// --radius-settings-group: 10px
    static let redesignSettingsGroupRadius: CGFloat = 10
    /// --min-height-settings-row: 52px
    static let redesignSettingsRowMinHeight: CGFloat = 52
    /// --padding-settings-row-y: 6px
    static let redesignSettingsRowVerticalPadding: CGFloat = 6
    /// --height-segmented-control: 32px
    static let redesignSegmentedControlHeight: CGFloat = 32
    /// --padding-segmented-control: 3px
    static let redesignSegmentedControlPadding: CGFloat = 3
    /// --gap-segmented-control: 2px
    static let redesignSegmentedControlGap: CGFloat = 2
    /// --font-size-segmented-control: 12px
    static let redesignFontSizeSegmentedControl: CGFloat = 12
    /// The selected option's block fills the control inside its padding.
    static let redesignSegmentedControlSegmentHeight =
        redesignSegmentedControlHeight - redesignSegmentedControlPadding * 2
    /// Concentric with the control around it: the control's own radius less
    /// the padding between the two.
    static let redesignSegmentedControlSegmentRadius =
        redesignCornerRadius - redesignSegmentedControlPadding
    /// Provisional --size-app-sidebar-item-icon: 23px icon box (document: 18px)
    static let redesignAppSidebarItemIconSize: CGFloat = 23
    /// --width-interactive-text-underline: 1px
    static let redesignInteractiveTextUnderlineThickness: CGFloat = 1
    /// --offset-interactive-text-underline: 2px
    static let redesignInteractiveTextUnderlineOffset: CGFloat = 2
    /// --radius-app-sidebar-item: 8px
    static let redesignAppSidebarItemRadius: CGFloat = 8
    /// --padding-app-sidebar-x: 12px
    static let redesignAppSidebarHorizontalPadding: CGFloat = 12
    /// --padding-app-sidebar-y: 12px
    static let redesignAppSidebarVerticalPadding: CGFloat = 12
    /// --padding-app-sidebar-item-x: 10px
    static let redesignAppSidebarItemHorizontalPadding: CGFloat = 10
    /// Provisional --padding-app-topbar-content-x: 24px
    static let redesignAppTopbarContentHorizontalPadding: CGFloat = 24
    /// Trailing padding for App topbars: leading margin (24px) plus the Scrollbar channel (16px) = 40px,
    /// so the rightmost button visually aligns with the content boundary below.
    static let redesignAppTopbarContentTrailingPadding: CGFloat =
        redesignAppTopbarContentHorizontalPadding + redesignWorkbenchPageScrollbarChannel
    /// --font-size-app-sidebar-item: 13px
    static let redesignFontSizeAppSidebarItem: CGFloat = 13

    /// --spacing-2: the inline padding of a count of two digits or more. One
    /// digit takes none and stays a circle.
    static let redesignTaskCountBadgeHorizontalPadding = redesignSpacing2
    /// --font-size-task-count-badge: 13px
    static let redesignFontSizeTaskCountBadge: CGFloat = 13
    /// The compact count beside a Filter dialog group name: 18px tall, with
    /// 6px of inline padding once it has two digits or more, and
    /// --font-size-caption.
    static let redesignTaskCountBadgeCompactHeight: CGFloat = 18
    static let redesignTaskCountBadgeCompactHorizontalPadding: CGFloat = 6

    // ==========================================
    // Export to Anki Tokens
    // ==========================================
    /// --height-anki-export-card-box: 288px
    static let redesignAnkiExportCardBoxHeight: CGFloat = 288
    /// --size-anki-export-add-button: 24px
    static let redesignAnkiExportAddButtonSize: CGFloat = 24
    /// --size-anki-export-add-icon: 16px
    static let redesignAnkiExportAddIconSize: CGFloat = 16
    /// --size-anki-export-drag-handle: 12px
    static let redesignAnkiExportDragHandleSize: CGFloat = 12
    /// --size-anki-export-badge-remove-button: 14px
    static let redesignAnkiExportBadgeRemoveButtonSize: CGFloat = 14
    /// --radius-anki-export-badge-remove-button: 3px
    static let redesignAnkiExportBadgeRemoveButtonRadius: CGFloat = 3
    /// --size-anki-export-badge-remove-icon: 12px
    static let redesignAnkiExportBadgeRemoveIconSize: CGFloat = 12
    /// --opacity-anki-export-dragging: 0.5
    static let redesignAnkiExportDraggingOpacity: Double = 0.5
    /// --font-weight-task-count-badge: 600
    static let redesignFontWeightTaskCountBadge: Font.Weight = .semibold
    /// --spacing-2: horizontal gap between the icon and the Task Count Badge,
    /// unified with the Filter button.
    static let redesignTaskCountBadgeGap: CGFloat = redesignSpacing2
    /// --height-task-panel: 500px
    static let redesignTaskPanelHeight: CGFloat = 500
    /// --height-filter-dialog: 600px
    static let redesignFilterDialogHeight: CGFloat = 600
    /// --height-task-progress-bar: 4px
    static let redesignTaskProgressBarHeight = redesignLibraryProgressBarHeight
    /// --size-task-card-icon: 31px
    static let redesignSizeTaskCardIcon: CGFloat = 31
    /// --size-card-icon-container: 36px (matches 36px 2-line text height)
    static let redesignCardIconContainerSize: CGFloat = 36
    /// --size-card-icon-glyph: 20px
    static let redesignCardIconGlyphSize: CGFloat = 20
    /// --size-card-chevron: 16px
    static let redesignCardChevronSize: CGFloat = 16
    /// --size-breadcrumb-separator: 12px (C-05.6 Breadcrumb caret-right)
    static let redesignBreadcrumbSeparatorSize: CGFloat = 12
    /// Baseline card height: 68px (16px top + 36px text/icon + 16px bottom)
    static let redesignCardBaselineHeight: CGFloat = 68
    /// Trailing icon button (32px) top offset to vertically center within 68px baseline card (18px top margin vs 16px padding = 2px)
    static let redesignCardTrailingIconButtonTopOffset: CGFloat = 2
    /// Line 3 row height for task card (16px)
    static let redesignTaskCardLine3Height: CGFloat = 16

    /// --aspect-library-cover: 16 / 9
    static let redesignLibraryCoverAspectRatio: CGFloat = 16.0 / 9.0
    /// --height-library-progress-bar: 4px
    static let redesignLibraryProgressBarHeight: CGFloat = 4
    /// --width-library-recent-card-min: 220px
    static let redesignLibraryRecentCardMinWidth: CGFloat = 220
    /// --grid-max-columns-library-with-sidebar: 5
    static let redesignLibraryRecentGridMaxColumnsWithSidebar: Int = 5
    /// --grid-max-columns-library-without-sidebar: 6
    static let redesignLibraryRecentGridMaxColumnsWithoutSidebar: Int = 6
    /// --width-library-episode-row-min: 380px
    static let redesignLibraryEpisodeRowMinWidth: CGFloat = 380
    /// --width-library-list-cover: 204px
    static let redesignLibraryListCoverWidth: CGFloat = 204
    /// --height-library-list-cover: 115px
    static let redesignLibraryListCoverHeight: CGFloat = 115
    /// --width-library-folder-cover: 120px
    static let redesignLibraryFolderCoverWidth: CGFloat = 120
    /// --min-height-library-folder-card: 96px
    static let redesignLibraryFolderCardMinHeight: CGFloat = 96
    /// --radius-library-cover: 8px
    static let redesignLibraryCoverRadius: CGFloat = 8
    /// Provisional --size-library-cover-edit-overlay-icon: 42px icon box (document: 32px)
    static let redesignLibraryCoverEditOverlayIconSize: CGFloat = 42
    /// Provisional: the glyph a cover without artwork shows, 57px icon box.
    static let redesignCoverPlaceholderIconSize: CGFloat = 57
    /// Provisional: the glyph above an empty state's title, 47px icon box.
    static let redesignEmptyStateIconSize: CGFloat = 47
    /// Provisional: a glyph standing in for a key name inside a keycap, 16px icon box.
    static let redesignKeycapIconSize: CGFloat = 16
    /// --radius-library-time-badge: 4px
    static let redesignLibraryTimeBadgeRadius: CGFloat = 4
    /// --radius-library-folder-card: 8px
    static let redesignLibraryFolderCardRadius: CGFloat = 8
    /// --radius-library-media-card-hover: 20px
    static let redesignLibraryMediaCardHoverRadius: CGFloat = 20
    /// --radius-library-list-card: 16px
    static let redesignLibraryListCardRadius: CGFloat = 16
    /// --gap-library-recent-grid: 8px
    static let redesignLibraryRecentGridGap: CGFloat = 8
    /// --gap-library-episode-grid: 8px
    static let redesignLibraryEpisodeGridGap: CGFloat = 8
    /// --gap-library-list-item: 20px
    static let redesignLibraryListItemGap: CGFloat = 20
    /// --gap-library-list-info-vertical: 8px
    static let redesignLibraryListInfoVerticalGap: CGFloat = 8
    /// --gap-library-folder-card-content: 12px
    static let redesignLibraryFolderCardContentGap: CGFloat = 12
    /// --scale-library-cover-hover: 1.02
    static let redesignLibraryCoverHoverScale: CGFloat = 1.02
    /// --duration-library-cover-hover: 0.12s
    static let redesignLibraryCoverHoverDuration: Double = 0.12
    /// --scale-collage-group-hover: 1.02
    static let redesignCollageGroupHoverScale: CGFloat = 1.02
    /// --duration-collage-group-hover: 0.12s
    static let redesignCollageGroupHoverDuration: Double = 0.12
    /// --padding-library-folder-card: 12px 16px
    static let redesignLibraryFolderCardVerticalPadding: CGFloat = 12
    static let redesignLibraryFolderCardHorizontalPadding: CGFloat = 16
    /// --padding-library-time-badge: 2px 6px
    static let redesignLibraryTimeBadgeVerticalPadding: CGFloat = 2
    static let redesignLibraryTimeBadgeHorizontalPadding: CGFloat = 6
    /// --padding-library-media-card-hover: 12px
    static let redesignLibraryMediaCardHoverPadding: CGFloat = 12
    /// --padding-library-list-card: 12px 16px
    static let redesignLibraryListCardVerticalPadding: CGFloat = 12
    static let redesignLibraryListCardHorizontalPadding: CGFloat = 16
    /// --font-size-section-title: 18px
    static let redesignFontSizeSectionTitle: CGFloat = 18
    /// --font-size-page-title: 20px
    static let redesignFontSizePageTitle: CGFloat = 20
    /// --font-weight-page-title: 600
    static let redesignFontWeightPageTitle: Font.Weight = .semibold
    /// --font-size-library-title: 14px
    static let redesignFontSizeLibraryTitle: CGFloat = 14
    /// --font-size-library-meta: 12px
    static let redesignFontSizeLibraryMeta: CGFloat = 12
    /// --font-size-library-time-badge: 10px
    static let redesignFontSizeLibraryTimeBadge: CGFloat = 10
    /// --font-size-library-list-title: 15px
    static let redesignFontSizeLibraryListTitle: CGFloat = 15
    /// --font-size-library-list-subtitle: 13px
    static let redesignFontSizeLibraryListSubtitle: CGFloat = 13
    /// --font-size-library-list-meta: 12px
    static let redesignFontSizeLibraryListMeta: CGFloat = 12

    // Cover Summary tokens are provisional until visual acceptance is folded
    // into UI Design System.md.
    /// --min-width-cover-summary-content: 448px
    static let redesignCoverSummaryContentMinWidth: CGFloat = 448
    /// --max-width-cover-summary-content: 720px
    static let redesignCoverSummaryContentMaxWidth: CGFloat = 720
    /// --preferred-width-cover-summary-content: 50%
    static let redesignCoverSummaryContentPreferredFraction: CGFloat = 0.5
    /// --cover-summary-scrim-leading: 0% / 62%
    static let redesignCoverSummaryScrimLeadingLocation: CGFloat = 0
    static let redesignCoverSummaryScrimLeadingOpacity: Double = 0.62
    /// --cover-summary-scrim-strong: 24% / 54%
    static let redesignCoverSummaryScrimStrongLocation: CGFloat = 0.24
    static let redesignCoverSummaryScrimStrongOpacity: Double = 0.54
    /// --cover-summary-scrim-middle: 43% / 34%
    static let redesignCoverSummaryScrimMiddleLocation: CGFloat = 0.43
    static let redesignCoverSummaryScrimMiddleOpacity: Double = 0.34
    /// --cover-summary-scrim-trailing: 58% / 12%
    static let redesignCoverSummaryScrimTrailingLocation: CGFloat = 0.58
    static let redesignCoverSummaryScrimTrailingOpacity: Double = 0.12
    /// --cover-summary-scrim-transparent: 70% / 0%
    static let redesignCoverSummaryScrimTransparentLocation: CGFloat = 0.70
    /// --opacity-cover-summary-description: 76%
    static let redesignCoverSummaryDescriptionOpacity: Double = 0.76
    /// --opacity-cover-summary-button-bg: 14%
    static let redesignCoverSummaryButtonBackgroundOpacity: Double = 0.14
    /// --opacity-cover-summary-button-bg-hover: 24%
    static let redesignCoverSummaryButtonHoverBackgroundOpacity: Double = 0.24
    /// --opacity-cover-summary-button-bg-pressed: 34%
    static let redesignCoverSummaryButtonPressedBackgroundOpacity: Double = 0.34
    /// --opacity-cover-summary-button-border: 35%
    static let redesignCoverSummaryButtonBorderOpacity: Double = 0.35
    /// --opacity-cover-summary-button-disabled: 55%
    static let redesignCoverSummaryButtonDisabledOpacity: Double = 0.55
    /// --radius-cover-summary: 16px
    static let redesignCoverSummaryRadius: CGFloat = 16
    /// --padding-cover-summary-content: 40px
    static let redesignCoverSummaryContentPadding: CGFloat = 40
    /// Split-form cover width; its height follows the shared cover aspect ratio.
    static let redesignCoverSummarySplitCoverWidth: CGFloat = 320
    /// Split-form cover height derived from the shared 16:9 cover aspect ratio.
    static let redesignCoverSummarySplitCoverHeight =
        redesignCoverSummarySplitCoverWidth / redesignLibraryCoverAspectRatio
    /// Gap between the split-form cover and its content column.
    static let redesignCoverSummarySplitGap = redesignSpacing6
    /// Narrowest content column the split form keeps before it gives way to the
    /// backdrop form.
    static let redesignCoverSummarySplitContentMinWidth: CGFloat = 320
    /// Available width at which the Cover Summary switches between its split and
    /// backdrop forms.
    static let redesignCoverSummarySplitMinimumWidth =
        redesignCoverSummarySplitCoverWidth
            + redesignCoverSummarySplitGap
            + redesignCoverSummarySplitContentMinWidth
    /// Backdrop-form block padding, applied equally above and below the content
    /// column so there is only one value to keep correct.
    static let redesignCoverSummaryBackdropBlockPadding: CGFloat = 22.5
    /// Fixed backdrop-form card height. Derived from the block padding around a
    /// content column as tall as the split form's, so the text and action area
    /// keeps the same height across a form change and the card height steps once
    /// instead of tracking the width.
    static let redesignCoverSummaryBackdropHeight =
        redesignCoverSummarySplitCoverHeight
            + redesignCoverSummaryBackdropBlockPadding * 2
    /// --font-size-cover-summary-title: 22px
    static let redesignFontSizeCoverSummaryTitle: CGFloat = 22
    /// --font-weight-cover-summary-title: 700
    static let redesignFontWeightCoverSummaryTitle: Font.Weight = .bold
    /// --gap-cover-summary-title-meta: 8px
    static let redesignCoverSummaryTitleMetaGap: CGFloat = 8
    /// --gap-cover-summary-meta-lines: 6px
    static let redesignCoverSummaryMetaLinesGap: CGFloat = 6
    /// --gap-cover-summary-progress-label: 6px
    static let redesignCoverSummaryProgressLabelGap: CGFloat = 6
    /// --gap-cover-summary-progress-actions: 14px
    static let redesignCoverSummaryProgressActionsGap: CGFloat = 14
    /// --height-cover-summary-progress-track: 5px
    static let redesignCoverSummaryProgressTrackHeight: CGFloat = 5
    /// --width-cover-summary-progress: 290px
    static let redesignCoverSummaryProgressWidth: CGFloat = 290
    /// --gap-cover-summary-to-toolbar: 24px
    static let redesignCoverSummaryToolbarGap: CGFloat = 24
    /// Shared top padding for Workbench details led by Cover Summary.
    static let redesignCoverSummaryDetailTopPadding = redesignSpacing1
    /// Shared inline padding for Workbench pages with an explicit page title.
    static let redesignWorkbenchPageHorizontalPadding = redesignSpacing8
    /// Channel reserved past the trailing page padding for the page's vertical
    /// Scrollbar. Reserved at every width so showing or hiding the Scrollbar
    /// never shifts page content sideways.
    static let redesignWorkbenchPageScrollbarChannel =
        TableScrollbarPrimitiveMetrics.size + TableScrollbarPrimitiveMetrics.inset * 2
    /// Trailing inline padding for Workbench pages: the shared page padding plus
    /// the Scrollbar channel, so both visual page margins stay equal.
    static let redesignWorkbenchPageTrailingPadding =
        redesignWorkbenchPageHorizontalPadding + redesignWorkbenchPageScrollbarChannel
    /// Shared inline padding for Workbench containers hosting media card grids.
    /// Offsets the 12px card hover padding so unhovered cover images align with standard 32px page margins.
    static let redesignWorkbenchMediaCardGridHorizontalPadding = redesignSpacing5
    /// Trailing inline padding for Workbench containers hosting media card grids:
    /// 20px plus the 16px scrollbar channel (36px).
    static let redesignWorkbenchMediaCardGridTrailingPadding =
        redesignWorkbenchMediaCardGridHorizontalPadding + redesignWorkbenchPageScrollbarChannel
    /// Shared top padding for Workbench pages with an explicit page title.
    static let redesignWorkbenchPageTopPadding = redesignSpacing1
    /// Shared bottom padding for Workbench pages with an explicit page title.
    static let redesignWorkbenchPageBottomPadding = redesignSpacing6

    /// Available horizontal width for a media card grid inside a Workbench page
    /// after applying the page's minimum width floor and media card grid inline padding.
    static func workbenchMediaCardGridWidth(viewportWidth: CGFloat) -> CGFloat {
        let pageWidth = max(viewportWidth, AppShellLayout.pageContentMinimumWidth)
        return max(
            0,
            pageWidth
                - redesignWorkbenchMediaCardGridHorizontalPadding
                - redesignWorkbenchMediaCardGridTrailingPadding
        )
    }

    /// Resolves the number of columns in a media card grid for a given container
    /// width, minimum card width, inter-card gap, and maximum column cap.
    static func mediaCardGridColumnCount(
        containerWidth: CGFloat,
        minimumItemWidth: CGFloat = redesignLibraryRecentCardMinWidth,
        itemGap: CGFloat = redesignLibraryRecentGridGap,
        maxColumns: Int = redesignLibraryRecentGridMaxColumnsWithoutSidebar
    ) -> Int {
        let resolvedWidth = max(0, containerWidth)
        let resolvedMinimum = max(1, minimumItemWidth)
        let resolvedGap = max(0, itemGap)
        let resolvedMaxColumns = max(1, maxColumns)
        let fittingColumns = max(
            1,
            Int((resolvedWidth + resolvedGap) / (resolvedMinimum + resolvedGap))
        )
        return min(resolvedMaxColumns, fittingColumns)
    }

    /// The centre of a message's first line, measured down from the text's top
    /// edge. Both feedback surfaces set their message in `--font-weight-control`.
    static func firstLineCenter(fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        return (font.ascender - font.descender + font.leading) / 2
    }
}

extension View {
    /// Applies the shared Workbench page inline padding, keeping the visual
    /// left and right margins equal by reserving the vertical Scrollbar channel
    /// on the trailing side.
    func workbenchPageInlinePadding() -> some View {
        padding(.leading, WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding)
            .padding(.trailing, WorkbenchControlMetrics.redesignWorkbenchPageTrailingPadding)
    }

    /// Applies the Workbench media card grid inline padding (leading 20px, trailing 36px),
    /// allowing unhovered cover images to align with standard page boundaries while
    /// reserving space for the card hover background.
    func workbenchMediaCardGridInlinePadding() -> some View {
        padding(.leading, WorkbenchControlMetrics.redesignWorkbenchMediaCardGridHorizontalPadding)
            .padding(.trailing, WorkbenchControlMetrics.redesignWorkbenchMediaCardGridTrailingPadding)
    }
}

struct WorkbenchPageTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizePageTitle,
                weight: WorkbenchControlMetrics.redesignFontWeightPageTitle
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .workbenchTruncatedTextTooltip(
                scenarioID: "truncated.topbar.page_title",
                text: title,
                font: .system(
                    size: WorkbenchControlMetrics.redesignFontSizePageTitle,
                    weight: WorkbenchControlMetrics.redesignFontWeightPageTitle
                )
            )
            .allowsHitTesting(false)
    }
}

enum WorkbenchControlColors {
    static let surfaceFill = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let primaryText = Color(nsColor: .labelColor)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let activeBlue = Color(red: 0.035, green: 0.412, blue: 0.957)
    static let activeBlueFill = Color(red: 0.910, green: 0.952, blue: 1.0)
    static let hoverFill = Color(nsColor: .labelColor).opacity(0.06)
}


struct WorkbenchInlineClearButton: View {
    var isEnabled: Bool = true
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            AppIconImage(.x, size: WorkbenchControlMetrics.inlineClearSymbolFontSizeMacOS) // --size-inline-clear-symbol-font-size-macos: 11pt
                .frame(width: WorkbenchControlMetrics.inlineClearIconSize, height: WorkbenchControlMetrics.inlineClearIconSize) // --size-inline-clear-icon: 16px
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled)
                .frame(width: WorkbenchControlMetrics.redesignInlineClearButtonSize, height: WorkbenchControlMetrics.redesignInlineClearButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius, style: .continuous)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return WorkbenchRedesignColors.bgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.bgHover
        }
        return Color.clear
    }
}

struct WorkbenchSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isRedesign: Bool
    var autofocus: Bool
    var placesInsertionPointAtEndOnAutofocus: Bool
    var trailingStatusText: String?
    var onSubmit: (() -> Void)?
    var onMoveUp: (() -> Bool)?
    var onMoveDown: (() -> Bool)?
    var onCancel: (() -> Bool)?

    @FocusState private var isFocused: Bool
    @State private var isNativeFocused = false
    @Environment(\.isEnabled) private var isEnabled

    init(
        placeholder: String,
        text: Binding<String>,
        isRedesign: Bool = false,
        autofocus: Bool = false,
        placesInsertionPointAtEndOnAutofocus: Bool = false,
        trailingStatusText: String? = nil,
        onSubmit: (() -> Void)? = nil,
        onMoveUp: (() -> Bool)? = nil,
        onMoveDown: (() -> Bool)? = nil,
        onCancel: (() -> Bool)? = nil
    ) {
        self.placeholder = placeholder
        _text = text
        self.isRedesign = isRedesign
        self.autofocus = autofocus
        self.placesInsertionPointAtEndOnAutofocus =
            placesInsertionPointAtEndOnAutofocus
        self.trailingStatusText = trailingStatusText
        self.onSubmit = onSubmit
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onCancel = onCancel
    }

    static func placeInsertionPointAtEnd(in editor: NSTextView) {
        editor.setSelectedRange(NSRange(
            location: editor.string.utf16.count,
            length: 0
        ))
    }

    var body: some View {
        HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing2 : 12) {
            AppIconImage(.magnifyingGlass, size: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : 23)
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled) : WorkbenchControlColors.mutedText)

            WorkbenchSingleLineTextInput(
                placeholder: placeholder,
                text: Binding(
                    get: { text },
                    set: {
                        text = SearchInputNormalizer.singleLine($0)
                    }
                ),
                placeholderColor: isRedesign
                    ? WorkbenchRedesignColors.textPlaceholder
                    : WorkbenchControlColors.mutedText,
                textColor: isRedesign
                    ? (isEnabled
                        ? WorkbenchRedesignColors.textPrimary
                        : WorkbenchRedesignColors.textPlaceholder)
                    : WorkbenchControlColors.primaryText,
                fontSize: isRedesign
                    ? WorkbenchControlMetrics.redesignFontSizeControl
                    : 15,
                focus: $isFocused,
                accessibilityLabel: placeholder,
                onFocusChange: { isNativeFocused = $0 },
                onSubmit: onSubmit,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onCancel: onCancel
            )

            if isRedesign,
               let trailingStatusText,
               !trailingStatusText.isEmpty {
                Text(trailingStatusText)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if isRedesign && !text.isEmpty {
                WorkbenchInlineClearButton(isEnabled: isEnabled) {
                    text = ""
                }
                .workbenchTooltip(
                    scenarioID: "input.search.clear",
                    isActive: isEnabled,
                    label: L("tooltip.input.search.clear")
                )
            }
        }
        .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignControlPaddingX : 18)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignSearchHeight : WorkbenchControlMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: isRedesign ? WorkbenchControlMetrics.redesignSearchRadius : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .fill(isRedesign ? (isEnabled ? WorkbenchRedesignColors.bgControl : WorkbenchRedesignColors.bgDisabled) : WorkbenchControlColors.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isRedesign ? WorkbenchControlMetrics.redesignSearchRadius : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .strokeBorder(
                    isRedesign ? ((isNativeFocused || isFocused) ? WorkbenchRedesignColors.borderFocus : (isEnabled ? WorkbenchRedesignColors.borderControl : WorkbenchRedesignColors.borderDisabled)) : WorkbenchControlColors.border,
                    lineWidth: isRedesign ? WorkbenchControlMetrics.redesignControlBorderWidth : WorkbenchControlMetrics.hairlineWidth
                )
                .allowsHitTesting(false)
        )
        .overlay(
            WorkbenchSingleLineContainerOverlay(
                isEnabled: isEnabled,
                trailingExclusionSize: (isRedesign && !text.isEmpty)
                    ? NSSize(
                        width: WorkbenchControlMetrics.redesignInlineClearButtonSize,
                        height: WorkbenchControlMetrics.redesignInlineClearButtonSize
                    )
                    : nil,
                trailingExclusionRightInset: isRedesign
                    ? WorkbenchControlMetrics.redesignControlPaddingX
                    : 18
            )
        )
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .task {
            guard autofocus else {
                return
            }
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            isFocused = true
            guard placesInsertionPointAtEndOnAutofocus else {
                return
            }
            await Task.yield()
            guard !Task.isCancelled,
                  let editor = NSApplication.shared.keyWindow?.firstResponder
                    as? NSTextView,
                  editor.isEditable,
                  editor.string == text
            else {
                return
            }
            Self.placeInsertionPointAtEnd(in: editor)
        }
    }
}

struct WorkbenchButton: View {
    var title: String? = nil
    var icon: AppIcon? = nil
    var count: Int = 0
    var countBackground: Color = WorkbenchRedesignColors.badgeNeutralBg
    var countTextColor: Color = WorkbenchRedesignColors.textSecondary
    var isRedesign: Bool = false
    var isOpen: Bool = false
    /// Buttons never take the keyboard focus, so the one that opens focused -
    /// Confirmation's Cancel - is told to draw its Focused state.
    var isFocused: Bool = false
    var height: CGFloat? = nil
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, horizontalPadding)
                .frame(width: boxWidth, height: boxHeight)
                .background(
                    Group {
                        if isRedesign {
                            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                                .fill(backgroundColor)
                        } else {
                            WorkbenchControlBackground()
                        }
                    }
                )
                .overlay(
                    Group {
                        if isRedesign {
                            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 1)
                        }
                    }
                )
                .overlay(
                    Group {
                        if isRedesign && isFocused && isEnabled {
                            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingPathExpansion, style: .continuous)
                                .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                                .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                        }
                    }
                )
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var content: some View {
        HStack(spacing: contentSpacing) {
            if let icon {
                AppIconImage(icon, size: iconSize)
                    .foregroundStyle(iconForegroundColor)
            }

            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(
                        size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 14,
                        weight: isRedesign ? WorkbenchControlMetrics.redesignFontWeightControl : .medium
                    ))
                    .foregroundStyle(textForegroundColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if isRedesign && count > 0 {
                TaskCountBadge(
                    count: count,
                    background: isEnabled ? countBackground : countBackground.opacity(0.35),
                    textColor: countTextColor
                )
            }
        }
    }

    private var hasTitle: Bool {
        guard let title else { return false }
        return !title.isEmpty
    }

    private var boxHeight: CGFloat {
        height ?? (isRedesign ? WorkbenchControlMetrics.redesignHeight : 36)
    }

    private var boxWidth: CGFloat? {
        if !hasTitle && count == 0 {
            return boxHeight
        }
        return nil
    }

    private var horizontalPadding: CGFloat {
        if !hasTitle && count == 0 {
            return 0
        }
        if !hasTitle && count > 0 {
            return (boxHeight - WorkbenchControlMetrics.redesignControlIconSize) / 2
        }
        return isRedesign ? WorkbenchControlMetrics.redesignControlPaddingX : 14
    }

    private var contentSpacing: CGFloat {
        if isRedesign && !hasTitle && count > 0 {
            return WorkbenchControlMetrics.redesignTaskCountBadgeGap
        }
        return isRedesign ? WorkbenchControlMetrics.redesignSpacing2 : 8
    }

    private var iconSize: CGFloat {
        if isRedesign {
            return hasTitle ? WorkbenchControlMetrics.redesignButtonIconSize : WorkbenchControlMetrics.redesignControlIconSize
        }
        return WorkbenchControlMetrics.iconSize
    }

    private var iconForegroundColor: Color {
        guard isEnabled else {
            return isRedesign ? WorkbenchRedesignColors.textDisabled : WorkbenchControlColors.primaryText
        }
        return isRedesign ? WorkbenchRedesignColors.textSecondary : WorkbenchControlColors.primaryText
    }

    private var textForegroundColor: Color {
        guard isEnabled else {
            return isRedesign ? WorkbenchRedesignColors.textDisabled : WorkbenchControlColors.primaryText
        }
        return isRedesign ? WorkbenchRedesignColors.textSecondary : WorkbenchControlColors.primaryText
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        if isPressed {
            return WorkbenchRedesignColors.bgPressed
        }
        if isOpen || isHovered {
            return WorkbenchRedesignColors.bgHover
        }
        return WorkbenchRedesignColors.bgControl
    }

    private var borderColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.borderDisabled
        }
        if isPressed || isOpen || isHovered {
            return WorkbenchRedesignColors.borderControlHover
        }
        return WorkbenchRedesignColors.borderControl
    }
}

struct WorkbenchPrimaryButton: View {
    let title: String
    var icon: AppIcon? = nil
    var iconWeight: AppIconWeight? = nil
    /// A spinner in the icon's place, while the button waits for what its
    /// title needs.
    var showsSpinner: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if showsSpinner {
                    WorkbenchSpinner()
                } else if let icon {
                    AppIconImage(
                        icon,
                        size: WorkbenchControlMetrics.redesignButtonIconSize,
                        weight: iconWeight
                    )
                }

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(
                isEnabled
                    ? WorkbenchRedesignColors.primaryButtonText
                    : WorkbenchRedesignColors.textDisabled
            )
            .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
                .fill(backgroundColor)
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        if isPressed {
            return WorkbenchRedesignColors.primaryButtonBgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.primaryButtonBgHover
        }
        return WorkbenchRedesignColors.primaryButtonBg
    }
}

struct WorkbenchDestructiveButton: View {
    let title: String
    var icon: AppIcon? = nil
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if let icon {
                    AppIconImage(icon, size: WorkbenchControlMetrics.redesignButtonIconSize)
                        .foregroundStyle(isEnabled ? WorkbenchRedesignColors.dangerText : WorkbenchRedesignColors.textDisabled)
                }

                Text(title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: WorkbenchControlMetrics.redesignFontWeightControl))
                    .foregroundStyle(isEnabled ? WorkbenchRedesignColors.dangerText : WorkbenchRedesignColors.textDisabled)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignHeight)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        if isPressed {
            return WorkbenchRedesignColors.dangerBgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.dangerBgHover
        }
        return WorkbenchRedesignColors.bgControl
    }

    private var borderColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.borderDisabled
        }
        return (isPressed || isHovered)
            ? WorkbenchRedesignColors.borderControlHover
            : WorkbenchRedesignColors.borderControl
    }
}

struct WorkbenchBadge: View {
    let title: String
    var foregroundColor = WorkbenchControlColors.activeBlue
    var fillColor = WorkbenchControlColors.activeBlueFill

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fillColor)
            )
    }
}

struct WorkbenchPopoverRow: View {
    let title: String
    var isSelected = false
    var isHighlighted = false
    var icon: AppIcon?
    var iconWeight: AppIconWeight?
    var isRedesign: Bool = false
    var showsCheckmarkSlot = true
    var isEnabled = true
    var isDestructive = false
    var action: (() -> Void)? = nil
    var trailingIcon: AppIcon?
    var onHoverChange: ((Bool) -> Void)?
    @State private var isHovered = false

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(StaticButtonStyle())
            .disabled(!isEnabled)
            .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
            .focusable(false)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing2 : 12) {
            if showsCheckmarkSlot {
                if isRedesign {
                    if isSelected {
                        AppIconImage(.check, size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
                            .frame(width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS, height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
                            .foregroundStyle(iconColor)
                    } else {
                        Color.clear
                            .frame(width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS, height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS)
                    }
                } else {
                    if isSelected {
                        AppIconImage(.check, size: 17)
                    } else {
                        Color.clear
                            .frame(width: 17, height: 17)
                    }
                }
            }

            // Every menu glyph is drawn in the same square box, so the slot is
            // that box: a wider slot would only widen the gap before the label.
            if let icon {
                AppIconImage(
                    icon,
                    size: isRedesign ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS : 18,
                    weight: iconWeight
                )
                    .foregroundStyle(isRedesign ? iconColor : (isEnabled ? WorkbenchControlColors.primaryText : WorkbenchControlColors.mutedText))
                    .frame(width: isRedesign ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS : nil, height: isRedesign ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS : nil)
            }

            Text(title)
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeTable : 15, weight: .regular))
                .foregroundStyle(isRedesign ? labelColor : (isEnabled ? WorkbenchControlColors.primaryText : WorkbenchControlColors.mutedText))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            if let trailingIcon {
                AppIconImage(
                    trailingIcon,
                    size: isRedesign
                        ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                        : 18
                )
                    .foregroundStyle(
                        isRedesign
                            ? iconColor
                            : (isEnabled
                                ? WorkbenchControlColors.primaryText
                                : WorkbenchControlColors.mutedText)
                    )
                    // No fixed width: a lone trailing glyph centred in a
                    // wider slot would leave the space after it reading wider
                    // than the space before the leading icon.
                    .frame(
                        height: isRedesign
                            ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                            : nil
                    )
            }
        }
        .foregroundStyle(isRedesign ? labelColor : (isEnabled ? WorkbenchControlColors.primaryText : WorkbenchControlColors.mutedText))
        .padding(
            .leading,
            isRedesign
                ? WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
                : 12
        )
        .padding(.trailing, isRedesign ? redesignTrailingPadding : 12)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignMenuItemHeight : 40)
        .background(
            RoundedRectangle(
                cornerRadius: isRedesign
                    ? WorkbenchControlMetrics.redesignMenuItemRadius
                    : 8,
                style: .continuous
            )
            .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            onHoverChange?(inside)
            isHovered = isEnabled && inside
        }
    }

    /// A trailing icon sits closer to the edge than trailing text does, so the
    /// two sides of the row read as equally spaced.
    private var redesignTrailingPadding: CGFloat {
        trailingIcon == nil
            ? WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
            : WorkbenchControlMetrics.redesignMenuItemTrailingIconPadding
    }

    /// Only the owning menu's highlight paints a background. The row's own
    /// hover must not, or the keyboard highlight and the row under the pointer
    /// would both light up at once.
    private var rowBackground: Color {
        guard isEnabled, isHighlighted else { return .clear }
        guard isRedesign else { return WorkbenchControlColors.hoverFill }
        return isDestructive
            ? WorkbenchRedesignColors.dangerBgHover
            : WorkbenchRedesignColors.bgHover
    }

    private var labelColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return isDestructive
            ? WorkbenchRedesignColors.dangerText
            : WorkbenchRedesignColors.textPrimary
    }

    private var iconColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return isDestructive
            ? WorkbenchRedesignColors.dangerText
            : WorkbenchRedesignColors.textPrimary
    }
}

struct WorkbenchIconButton: View {
    let icon: AppIcon
    var isRedesign: Bool = false
    /// The button stays lit for as long as the menu or panel it hangs off is
    /// open, and for as long as the mode it switches on is on. Lit looks the
    /// same as hover, the way a shortcut button does.
    var isOpen: Bool = false
    /// Hover is read against the surface the button sits on, so a button drawn
    /// on another surface passes that surface's own step; the Workbench
    /// surface's is the default.
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    /// Pressed advances one step beyond hover on the surface the button sits on.
    var pressedBackground: Color = WorkbenchRedesignColors.bgPressed
    /// Open uses a translucent accent tint background by default, distinguishing
    /// the active state from hover. Surfaces like the player top bar pass their
    /// own open background step.
    var openBackground: Color? = nil
    /// The icon is read against the surface too: on the video page it takes
    /// the player's text color, because the Workbench's secondary text is dark
    /// on a dark video in Light appearance.
    var iconColor: Color? = nil
    /// Open uses the dynamic accent icon color by default, distinguishing
    /// the active state from hover. Surfaces like the player top bar can pass
    /// their own open icon color step if needed.
    var openIconColor: Color? = nil
    /// Input is blocked while a window or video size transition runs. The
    /// freeze is not a disabled state, so the button keeps the look it had
    /// before the transition started and nothing about it changes on screen.
    var isFrozen: Bool = false
    /// Dialog close buttons carry a smaller glyph than the rest of the icon
    /// buttons; everything else keeps the shared control icon size.
    var iconSize: CGFloat? = nil
    /// Dialog close buttons also carry a smaller box, so their hover block stays
    /// in proportion to the smaller glyph; everything else keeps the shared one.
    var boxSize: CGFloat? = nil
    /// The Task entry's or the Filter trigger's count, drawn beside the glyph
    /// inside the button, so hover and Open cover it and a click on it is a
    /// click on the button. At zero nothing is drawn and the box stays square.
    var count: Int = 0
    /// The count badge is filled with the accent color with white text for clear
    /// contrast across surfaces. A disabled button greys the count with its glyph.
    var countBackground: Color = WorkbenchRedesignColors.badgeNeutralBg
    var countTextColor: Color = WorkbenchRedesignColors.textSecondary
    var action: (() -> Void)? = nil

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
                .disabled(isFrozen)
                .focusable(false)
                .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
                .onPointerHover { isHovered = $0 }
            } else {
                label
            }
        }
    }

    private var label: some View {
        Group {
            if isRedesign && count > 0 {
                HStack(spacing: WorkbenchControlMetrics.redesignTaskCountBadgeGap) {
                    glyph
                    TaskCountBadge(
                        count: count,
                        background: isEnabled ? countBackground : countBackground.opacity(0.35),
                        textColor: countTextColor
                    )
                }
                // The count ends as far from the button's edge as the glyph
                // sits from its top.
                .padding(.horizontal, (boxLength - glyphLength) / 2)
                .frame(height: boxLength)
            } else {
                glyph
                    .frame(width: boxLength, height: boxLength)
            }
        }
        .background(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .fill(redesignBackgroundColor)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
    }

    private var glyph: some View {
        AppIconImage(icon, size: glyphLength)
            .foregroundStyle(isRedesign ? redesignIconColor : WorkbenchControlColors.primaryText)
    }

    private var glyphLength: CGFloat {
        isRedesign ? (iconSize ?? WorkbenchControlMetrics.redesignControlIconSize) : WorkbenchControlMetrics.iconSize
    }

    private var boxLength: CGFloat {
        isRedesign ? (boxSize ?? WorkbenchControlMetrics.redesignIconButtonSize) : WorkbenchControlMetrics.controlHeight
    }

    var redesignIconColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        if isOpen {
            return openIconColor ?? iconColor ?? WorkbenchRedesignColors.textSecondary
        }
        return iconColor ?? WorkbenchRedesignColors.textSecondary
    }

    private var redesignBackgroundColor: Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return pressedBackground
        }
        if isOpen {
            return openBackground ?? hoverBackground
        }
        if isHovered {
            return hoverBackground
        }
        return Color.clear
    }
}

/// Menu Divider.
///
/// Its ends line up with where the items' content starts, and it keeps room
/// above and below itself, so it reads as a break between two groups rather
/// than as an underline belonging to the row above it.
///
/// The inset is written as the distance from the menu's edge and then given
/// back the menu's padding, because the divider is laid out inside the item
/// stack, which that padding has already moved in.
struct WorkbenchMenuDivider: View {
    var body: some View {
        Divider()
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignMenuDividerInset - MenuMetrics.padding
            )
            .padding(.vertical, WorkbenchControlMetrics.redesignMenuDividerGap)
    }
}

/// The surface a menu is drawn on. Player Chrome menus sit over the video and
/// keep the Player Speed Menu's look.
enum MenuSurface {
    case workbench
    case playerChrome
}

struct WorkbenchPopoverPanel<Content: View>: View {
    var isRedesign: Bool = false
    var surface = MenuSurface.workbench
    /// How tall the panel may grow. It is the menu's own cap by default; a menu
    /// that opened on a side with less room than that is given the room it has,
    /// and scrolls whatever no longer fits.
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    /// The open menu's highlight. Keeping the highlighted item visible belongs
    /// to the surface every menu shares, not to each menu: a menu that grows
    /// past the cap then reveals its highlight without doing anything itself,
    /// and a menu that never scrolls is unaffected. Items must carry `.id` of
    /// their own position for the reveal to find them.
    @ObservedObject var highlight: MenuHighlightModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        let isPlayerChrome = surface == .playerChrome
        let cornerRadius: CGFloat = isPlayerChrome || isRedesign
            ? WorkbenchControlMetrics.redesignMenuRadius
            : 10
        // The scroll view spans the whole panel, and the item stack inside it
        // both applies the menu's padding and reserves the strip the scrollbar
        // needs — but only once the items outgrow the cap, so a menu that does
        // not scroll spends nothing on a scrollbar that never appears. The cap
        // makes the menu its items' own height until they pass it; width stays
        // whatever the items need, plus that strip when it is reserved.
        ScrollViewReader { proxy in
            MenuHeightCap(height: maximumHeight) {
                WorkbenchScrollView(
                    scrollbarInset: isRedesign || isPlayerChrome
                        ? MenuMetrics.scrollbarOuterGap
                        : TableScrollbarPrimitiveMetrics.inset
                ) {
                    if isRedesign || isPlayerChrome {
                        MenuItemStack(
                            padding: MenuMetrics.padding,
                            strip: MenuMetrics.scrollbarStrip,
                            cap: maximumHeight
                        ) {
                            content()
                        }
                    } else {
                        content()
                            .padding(8)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .background(
                Group {
                    if isPlayerChrome {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(PlaybackTheme.menuBackground)
                            .shadow(
                                color: PlaybackTheme.overlayShadowColor,
                                radius: PlaybackTheme.overlayShadowRadius,
                                y: PlaybackTheme.overlayShadowYOffset
                            )
                    } else if isRedesign {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(WorkbenchRedesignColors.bgPopover)
                            .shadowToken(
                                WorkbenchRedesignColors.shadowPopover,
                                cornerRadius: cornerRadius
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(WorkbenchControlColors.surfaceFill)
                            .shadow(
                                color: Color.black.opacity(0.14),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isPlayerChrome
                            ? PlaybackTheme.textTertiary.opacity(0.3)
                            : isRedesign ? WorkbenchRedesignColors.borderControl : WorkbenchControlColors.border.opacity(0.75),
                        lineWidth: isRedesign ? 1.0 : 0.5
                    )
            )
            .subtitleTableTextSelectionNonInteractiveRegion(
                cornerRadius: cornerRadius
            )
            // The item highlighted when the menu opens can already be out of
            // reach — `Save to Excerpt` opens on the list saved to most
            // recently — so opening reveals it the same way a keyboard move
            // does. The wheel and the scrollbar bump neither signal, so they
            // never pull the menu back to the highlight.
            .onAppear {
                revealHighlight(proxy)
            }
            .onChange(of: highlight.keyboardMoveCount) { _ in
                revealHighlight(proxy)
            }
        }
    }

    /// Scrolls the least amount that makes the highlighted item whole, without
    /// animating: the menu is already open and the item has to be there now.
    private func revealHighlight(_ proxy: ScrollViewProxy) {
        guard let position = highlight.highlightedPosition else {
            return
        }
        proxy.scrollTo(position)
    }
}

struct WorkbenchControlBackground: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.cornerRadius,
            style: .continuous
        )
        .fill(WorkbenchControlColors.surfaceFill)
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchControlColors.border,
                lineWidth: WorkbenchControlMetrics.hairlineWidth
            )
        )
    }
}

public struct WorkbenchDropdownAnchorPreferenceKey: PreferenceKey {
    public typealias Value = [String: CGRect]
    public static var defaultValue: Value { [:] }
    public static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    public func workbenchDropdownAnchor(id: String, in spaceName: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: WorkbenchDropdownAnchorPreferenceKey.self,
                        value: [id: geo.frame(in: .named(spaceName))]
                    )
            }
        )
    }
}

/// Toast and Playback Feedback both put the icon in its own column and wrap the
/// message beside it. The icon belongs to the first line, not to the block: on
/// the block's centre it would float into the gap between lines as soon as a
/// message wraps.
extension VerticalAlignment {
    private enum FeedbackFirstLineCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[VerticalAlignment.center]
        }
    }

    static let feedbackFirstLineCenter = VerticalAlignment(FeedbackFirstLineCenter.self)
}

struct WorkbenchCardIcon: View {
    let icon: AppIcon

    var body: some View {
        RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        )
        .fill(WorkbenchRedesignColors.bgHover)
        .frame(
            width: WorkbenchControlMetrics.redesignCardIconContainerSize,
            height: WorkbenchControlMetrics.redesignCardIconContainerSize
        )
        .overlay(
            AppIconImage(icon, size: WorkbenchControlMetrics.redesignCardIconGlyphSize)
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
        )
    }
}

struct WorkbenchCardMenuItem: Identifiable, Sendable {
    let title: String
    let icon: AppIcon
    var isEnabled: Bool = true
    var isDestructive: Bool = false
    let action: @MainActor @Sendable () -> Void

    var id: String {
        title
    }
}

struct WorkbenchCardMenuState: Identifiable {
    let id = UUID()
    let cardID: String
    let anchorFrame: CGRect
    let menuFrame: CGRect
    let items: [WorkbenchCardMenuItem]
}

struct WorkbenchCardMenuPopover: View {
    let items: [WorkbenchCardMenuItem]
    @ObservedObject var highlight: MenuHighlightModel
    let onDismiss: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                    WorkbenchPopoverRow(
                        title: item.title,
                        isHighlighted: highlight.highlightedPosition == position,
                        icon: item.icon,
                        isRedesign: true,
                        showsCheckmarkSlot: false,
                        isEnabled: item.isEnabled,
                        isDestructive: item.isDestructive,
                        action: {
                            onDismiss()
                            item.action()
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .frame(minWidth: 160, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}


