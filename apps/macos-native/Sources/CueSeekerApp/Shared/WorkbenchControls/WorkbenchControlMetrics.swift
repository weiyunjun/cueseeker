import SwiftUI
import AppKit

enum WorkbenchControlMetrics {
    static let hairlineWidth: CGFloat = 0.5

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
    /// --width-task-detail-progress-bar: 140px
    static let redesignTaskDetailProgressBarWidth: CGFloat = 140
    /// --size-card-icon-container: 36px (matches 36px 2-line text height)
    static let redesignCardIconContainerSize: CGFloat = 36
    /// --opacity-card-icon-accent-base: 0.32
    static let redesignCardIconAccentBaseOpacity: CGFloat = 0.32
    /// --opacity-card-icon-accent-folder-tab: 0.52
    static let redesignCardIconAccentFolderTabOpacity: CGFloat = 0.52
    /// --opacity-card-icon-accent-anki-line: 0.59
    static let redesignCardIconAccentAnkiLineOpacity: CGFloat = 0.59
    /// --opacity-card-icon-accent-foreground: 1.0
    static let redesignCardIconAccentForegroundOpacity: CGFloat = 1.0
    /// --color-empty-icon-search-card alpha: 0.30
    static let redesignEmptyIconSearchCardOpacity: CGFloat = 0.30
    /// --color-empty-icon-search-line alpha: 0.58
    static let redesignEmptyIconSearchLineOpacity: CGFloat = 0.58
    /// --color-empty-icon-magnifier-fill alpha: 0.22
    static let redesignEmptyIconMagnifierFillOpacity: CGFloat = 0.22
    /// --color-empty-icon-badge-fill alpha: 0.24
    static let redesignEmptyIconBadgeFillOpacity: CGFloat = 0.24
    /// --color-empty-icon-base alpha: 0.32
    static let redesignEmptyIconBaseOpacity: CGFloat = 0.32
    /// --color-empty-icon-mid alpha: 0.52
    static let redesignEmptyIconMidOpacity: CGFloat = 0.52
    /// --color-empty-icon-foreground alpha: 1.0
    static let redesignEmptyIconForegroundOpacity: CGFloat = 1.0
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
    /// --size-empty-state-icon: 68px duotone icon container above an empty state's copy.
    static let redesignEmptyStateIconSize: CGFloat = 68
    /// --gap-empty-state-icon-to-text: 14px vertical gap between the 68px duotone icon and copy.
    static let redesignEmptyStateIconToTextGap: CGFloat = 14
    /// --gap-empty-state-title-to-message: 4px (--spacing-1)
    static let redesignEmptyStateTitleToMessageGap = redesignSpacing1
    /// --font-size-empty-state-title: 15px (--font-size-library-list-title)
    static let redesignEmptyStateTitleFontSize = redesignFontSizeLibraryListTitle
    /// --max-width-empty-state-message: 380px
    static let redesignEmptyStateMessageMaxWidth: CGFloat = 380
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
    /// --opacity-library-cover-action-bg: Light 0.56, Dark 0.44
    static let redesignLibraryCoverActionBackgroundLightOpacity: CGFloat = 0.56
    static let redesignLibraryCoverActionBackgroundDarkOpacity: CGFloat = 0.44
    /// --opacity-library-cover-action-bg-hover: Light 0.72, Dark 0.58
    static let redesignLibraryCoverActionHoverBackgroundLightOpacity: CGFloat = 0.72
    static let redesignLibraryCoverActionHoverBackgroundDarkOpacity: CGFloat = 0.58
    /// --opacity-library-cover-action-bg-pressed: Light 0.88, Dark 0.76
    static let redesignLibraryCoverActionPressedBackgroundLightOpacity: CGFloat = 0.88
    static let redesignLibraryCoverActionPressedBackgroundDarkOpacity: CGFloat = 0.76
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
