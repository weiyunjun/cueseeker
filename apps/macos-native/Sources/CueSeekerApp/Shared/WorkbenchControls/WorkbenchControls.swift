import SwiftUI
import AppKit

enum WorkbenchControlMetrics {
    static let searchFieldHeight: CGFloat = 46
    static let controlHeight: CGFloat = 40
    static let cornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
    static let iconSize: CGFloat = 16

    // ==========================================
    // Redesign Tokens (对接新的 Token 规范)
    // ==========================================
    /// --height-control / --height-filter-bar-control: 40px
    static let redesignHeight: CGFloat = 40
    /// --radius-control: 8px
    static let redesignCornerRadius: CGFloat = 8
    /// --height-field: 40px
    static let redesignFieldHeight: CGFloat = 40
    /// --height-form-text-area: 96px
    static let redesignFormTextAreaHeight: CGFloat = 96
    /// --height-filter-bar-control (Search box): 40px
    static let redesignSearchHeight: CGFloat = 40
    /// --radius-field: 8px
    static let redesignFieldRadius: CGFloat = 8
    /// --radius-search: 9999px
    static let redesignSearchRadius: CGFloat = 9999
    /// --size-inline-clear-button: 24px
    static let redesignInlineClearButtonSize: CGFloat = 24
    /// --padding-control-x: 14px
    static let redesignControlPaddingX: CGFloat = 14
    /// --padding-field-x: 16px
    static let redesignFieldPaddingX: CGFloat = 16
    /// --size-inline-clear-symbol-font-size-macos: 11pt
    static let inlineClearSymbolFontSizeMacOS: CGFloat = 11
    /// --size-inline-clear-icon: 16px
    static let inlineClearIconSize: CGFloat = 16
    /// --focus-ring-width: 2px
    static let redesignFocusRingWidth: CGFloat = 2
    /// --focus-ring-offset: 2px
    static let redesignFocusRingOffset: CGFloat = 2
    /// Centerline expansion that preserves the documented edge-to-ring offset.
    static let redesignFocusRingPathExpansion: CGFloat =
        redesignFocusRingOffset + redesignFocusRingWidth / 2
    /// --radius-inline-clear-button: 9999px
    static let redesignInlineClearButtonRadius: CGFloat = 9999
    /// --size-control-icon: 16px
    static let redesignControlIconSize: CGFloat = 16
    /// --size-checkbox: 16px
    static let redesignCheckboxSize: CGFloat = 16
    /// --min-width-filter-data-card: 200px
    static let redesignFilterDataCardMinWidth: CGFloat = 200
    /// --size-select-indicator: 12pt
    static let redesignSelectIndicatorSymbolFontSizeMacOS: CGFloat = 12
    /// --weight-select-indicator: semibold
    static let redesignSelectIndicatorWeightMacOS: Font.Weight = .semibold
    /// --font-size-control: 14px
    static let redesignFontSizeControl: CGFloat = 14
    /// --font-weight-control: 500
    static let redesignFontWeightControl: Font.Weight = .medium
    /// --size-button-icon: 14px
    static let redesignButtonIconSize: CGFloat = 14
    /// --weight-button-icon: medium
    static let redesignButtonIconWeight: Font.Weight = .medium
    /// --size-inline-add-symbol-font-size-macos: 16pt
    static let redesignInlineAddSymbolFontSizeMacOS: CGFloat = 16
    /// --size-menu-item-symbol-font-size-macos: 14pt
    static let redesignMenuItemSymbolFontSizeMacOS: CGFloat = 14
    /// --size-icon-button: 32px
    static let redesignIconButtonSize: CGFloat = 32
    /// --height-table-header: 40px
    static let redesignTableHeaderHeight: CGFloat = 40
    /// --spacing-1: 4px
    static let redesignSpacing1: CGFloat = 4
    /// --spacing-2: 8px
    static let redesignSpacing2: CGFloat = 8
    /// --spacing-3: 12px
    static let redesignSpacing3: CGFloat = 12
    /// --spacing-4: 16px
    static let redesignSpacing4: CGFloat = 16
    /// --spacing-6: 24px
    static let redesignSpacing6: CGFloat = 24
    /// --spacing-8: 32px
    static let redesignSpacing8: CGFloat = 32
    /// --gap-app-topbar-title-after-toggle: 12px
    static let redesignAppTopbarTitleAfterToggleGap: CGFloat = 12
    /// --padding-header-trigger-x: 12px
    static let redesignPaddingHeaderTriggerX: CGFloat = 12
    /// --radius-table-cell-hover: 8px
    static let redesignTableCellHoverRadius = redesignFieldRadius
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
    /// --radius-chip
    static let redesignChipRadius: CGFloat = 6
    /// --padding-chip-x
    static let redesignChipHorizontalPadding: CGFloat = 10
    /// --padding-chip-y
    static let redesignChipVerticalPadding: CGFloat = 4
    /// --height-app-sidebar-item: 32px
    static let redesignAppSidebarItemHeight: CGFloat = 32
    /// --height-app-topbar: 45px
    static let redesignAppTopbarHeight: CGFloat = 45
    /// --width-app-sidebar: 240px
    static let redesignAppSidebarWidth: CGFloat = 240
    /// --size-app-sidebar-item-icon: 18px
    static let redesignAppSidebarItemIconSize: CGFloat = 18
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
    /// --padding-app-topbar-title-x: 24px
    static let redesignAppTopbarTitleHorizontalPadding: CGFloat = 24
    /// --font-size-app-sidebar-item: 13px
    static let redesignFontSizeAppSidebarItem: CGFloat = 13

    /// --aspect-library-cover: 16 / 9
    static let redesignLibraryCoverAspectRatio: CGFloat = 16.0 / 9.0
    /// --height-library-progress-bar: 4px
    static let redesignLibraryProgressBarHeight: CGFloat = 4
    /// --width-library-recent-card-min: 180px
    static let redesignLibraryRecentCardMinWidth: CGFloat = 180
    /// --width-library-recent-card-max: 220px
    static let redesignLibraryRecentCardMaxWidth: CGFloat = 220
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
    /// --radius-library-time-badge: 4px
    static let redesignLibraryTimeBadgeRadius: CGFloat = 4
    /// --radius-library-folder-card: 8px
    static let redesignLibraryFolderCardRadius: CGFloat = 8
    /// --radius-library-media-card-hover: 20px
    static let redesignLibraryMediaCardHoverRadius: CGFloat = 20
    /// --radius-library-list-card: 16px
    static let redesignLibraryListCardRadius: CGFloat = 16
    /// --gap-library-recent-grid: 16px
    static let redesignLibraryRecentGridGap: CGFloat = 16
    /// --gap-library-episode-grid: 16px
    static let redesignLibraryEpisodeGridGap: CGFloat = 16
    /// --gap-library-list-item: 20px
    static let redesignLibraryListItemGap: CGFloat = 20
    /// --gap-library-list-info-vertical: 8px
    static let redesignLibraryListInfoVerticalGap: CGFloat = 8
    /// --gap-library-folder-card-content: 12px
    static let redesignLibraryFolderCardContentGap: CGFloat = 12
    /// --scale-library-media-card-pressed: 0.98
    static let redesignLibraryMediaCardPressedScale: CGFloat = 0.98
    /// --scale-library-cover-hover: 1.02
    static let redesignLibraryCoverHoverScale: CGFloat = 1.02
    /// --duration-library-cover-hover: 0.12s
    static let redesignLibraryCoverHoverDuration: Double = 0.12
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
    /// --height-cover-summary: 252px
    static let redesignCoverSummaryHeight: CGFloat = 252
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
    /// --opacity-cover-summary-button-border: 35%
    static let redesignCoverSummaryButtonBorderOpacity: Double = 0.35
    /// --opacity-cover-summary-button-disabled: 55%
    static let redesignCoverSummaryButtonDisabledOpacity: Double = 0.55
    /// --radius-cover-summary: 16px
    static let redesignCoverSummaryRadius: CGFloat = 16
    /// --padding-cover-summary-content: 40px
    static let redesignCoverSummaryContentPadding: CGFloat = 40
    /// --font-size-cover-summary-title: 28px
    static let redesignFontSizeCoverSummaryTitle: CGFloat = 28
    /// --font-weight-cover-summary-title: 700
    static let redesignFontWeightCoverSummaryTitle: Font.Weight = .bold
    /// --gap-cover-summary-to-toolbar: 24px
    static let redesignCoverSummaryToolbarGap: CGFloat = 24
    /// --height-cue-facet-filter-panel-pinned: 244px
    static let redesignCueFacetFilterPanelPinnedHeight: CGFloat = 244
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
    var isActiveContext: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: WorkbenchControlMetrics.inlineClearSymbolFontSizeMacOS, weight: .bold)) // --size-inline-clear-symbol-font-size-macos: 11pt
                .frame(width: WorkbenchControlMetrics.inlineClearIconSize, height: WorkbenchControlMetrics.inlineClearIconSize) // --size-inline-clear-icon: 16px
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted)
                .frame(width: WorkbenchControlMetrics.redesignInlineClearButtonSize, height: WorkbenchControlMetrics.redesignInlineClearButtonSize)
                .background(
                    Group {
                        if isEnabled && isHovered {
                            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius, style: .continuous)
                                .fill(isActiveContext ? WorkbenchRedesignColors.bgActiveClearHover : WorkbenchRedesignColors.bgHover)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
        .overlay(
            Group {
                if isFocused {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius, style: .continuous)
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                }
            }
        )
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

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(
        placeholder: String,
        text: Binding<String>,
        isRedesign: Bool = false,
        autofocus: Bool = false,
        placesInsertionPointAtEndOnAutofocus: Bool = false,
        trailingStatusText: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        _text = text
        self.isRedesign = isRedesign
        self.autofocus = autofocus
        self.placesInsertionPointAtEndOnAutofocus =
            placesInsertionPointAtEndOnAutofocus
        self.trailingStatusText = trailingStatusText
        self.onSubmit = onSubmit
    }

    static func placeInsertionPointAtEnd(in editor: NSTextView) {
        editor.setSelectedRange(NSRange(
            location: editor.string.utf16.count,
            length: 0
        ))
    }

    var body: some View {
        HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing2 : 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : 18, weight: .regular))
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted) : WorkbenchControlColors.mutedText)

            TextField(
                "",
                text: Binding(
                    get: { text },
                    set: {
                        text = SearchInputNormalizer.singleLine($0)
                    }
                ),
                prompt: Text(placeholder)
                    .foregroundColor(isRedesign ? WorkbenchRedesignColors.textPlaceholder : WorkbenchControlColors.mutedText)
            )
            .textFieldStyle(.plain)
            .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 15, weight: .regular))
            .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
            .focused($isFocused)
            .onSubmit {
                onSubmit?()
            }

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
                WorkbenchInlineClearButton(isEnabled: isEnabled, isActiveContext: false) {
                    text = ""
                }
            }
        }
        .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignControlPaddingX : 18)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignSearchHeight : WorkbenchControlMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: isRedesign ? WorkbenchControlMetrics.redesignSearchRadius : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .fill(isRedesign ? (isEnabled ? WorkbenchRedesignColors.bgSurface : WorkbenchRedesignColors.bgDisabled) : WorkbenchControlColors.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isRedesign ? WorkbenchControlMetrics.redesignSearchRadius : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .strokeBorder(
                    isRedesign ? (isFocused ? WorkbenchRedesignColors.borderFocus : WorkbenchRedesignColors.borderControl) : WorkbenchControlColors.border,
                    lineWidth: isRedesign ? 1.0 : WorkbenchControlMetrics.hairlineWidth
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

struct WorkbenchToolbarButton: View {
    let title: String
    let systemImage: String
    var showsChevron = false
    var isRedesign: Bool = false
    var isMenuOpen: Bool = false
    var action: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .disableFocusEffect()
            .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: isRedesign ? 8 : 10) {
            Image(systemName: systemImage)
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : WorkbenchControlMetrics.iconSize, weight: isRedesign ? .semibold : .medium))
                .frame(width: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil) // --size-control-icon
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.iconDisabled) : WorkbenchControlColors.primaryText)

            Text(title)
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 15, weight: isRedesign ? WorkbenchControlMetrics.redesignFontWeightControl : .medium))
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if showsChevron {
                if isRedesign {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS, weight: WorkbenchControlMetrics.redesignSelectIndicatorWeightMacOS))
                        .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize) // --size-control-icon
                        .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.iconDisabled)
                } else {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkbenchControlColors.mutedText)
                }
            }
        }
        .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignControlPaddingX : 14)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : WorkbenchControlMetrics.controlHeight)
        .background(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .fill(isEnabled ? ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface) : WorkbenchRedesignColors.bgDisabled)
                } else {
                    WorkbenchControlBackground()
                }
            }
        )
        .overlay(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .strokeBorder(isEnabled ? ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.borderControlHover : WorkbenchRedesignColors.borderControl) : WorkbenchRedesignColors.borderControl, lineWidth: 1)
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
        .onHover { isHovered = $0 }
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
    }
}

struct WorkbenchButton: View {
    let title: String
    var systemImage: String? = nil
    var isRedesign: Bool = false
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing2 : 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignButtonIconSize : WorkbenchControlMetrics.iconSize, weight: isRedesign ? WorkbenchControlMetrics.redesignButtonIconWeight : .regular))
                        .frame(width: isRedesign ? WorkbenchControlMetrics.redesignButtonIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignButtonIconSize : nil)
                        .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.iconDisabled) : WorkbenchControlColors.primaryText)
                }

                Text(title)
                    .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 14, weight: isRedesign ? WorkbenchControlMetrics.redesignFontWeightControl : .medium))
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : WorkbenchControlColors.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignControlPaddingX : 14)
            .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : 36)
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .fill(isEnabled ? (isHovered ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface) : WorkbenchRedesignColors.bgDisabled)
                    } else {
                        WorkbenchControlBackground()
                    }
                }
            )
            .overlay(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .strokeBorder(isEnabled ? (isHovered ? WorkbenchRedesignColors.borderControlHover : WorkbenchRedesignColors.borderControl) : WorkbenchRedesignColors.borderDisabled, lineWidth: 1)
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
        .buttonStyle(.plain)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
    }
}

struct WorkbenchPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignButtonIconSize,
                            weight: WorkbenchControlMetrics.redesignButtonIconWeight
                        ))
                        .frame(
                            width: WorkbenchControlMetrics.redesignButtonIconSize,
                            height: WorkbenchControlMetrics.redesignButtonIconSize
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
                .fill(
                    isEnabled
                        ? (
                            isHovered
                                ? WorkbenchRedesignColors.primaryButtonBgHover
                                : WorkbenchRedesignColors.primaryButtonBg
                        )
                        : WorkbenchRedesignColors.bgDisabled
                )
            )
            .overlay {
                if isFocused && isEnabled {
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
                            + WorkbenchControlMetrics.redesignFocusRingPathExpansion,
                        style: .continuous
                    )
                    .stroke(
                        WorkbenchRedesignColors.focusRing,
                        lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                    )
                    .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
    }
}

struct WorkbenchDestructiveButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: WorkbenchControlMetrics.redesignButtonIconSize, weight: WorkbenchControlMetrics.redesignButtonIconWeight))
                        .frame(width: WorkbenchControlMetrics.redesignButtonIconSize, height: WorkbenchControlMetrics.redesignButtonIconSize)
                        .foregroundStyle(isEnabled ? WorkbenchRedesignColors.dangerText : WorkbenchRedesignColors.iconDisabled)
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
                    .fill(isEnabled ? WorkbenchRedesignColors.dangerBgHover : WorkbenchRedesignColors.bgDisabled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .strokeBorder(isEnabled ? Color.clear : WorkbenchRedesignColors.borderDisabled, lineWidth: 1)
            )
            .overlay(
                Group {
                    if isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingPathExpansion, style: .continuous)
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
                    }
                }
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
    }
}

struct WorkbenchPlainActionButton: View {
    let title: String
    let systemImage: String
    var isRedesign: Bool = false
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: isRedesign ? WorkbenchControlMetrics.redesignSpacing2 : 10) {
                Image(systemName: systemImage)
                    .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignInlineAddSymbolFontSizeMacOS : WorkbenchControlMetrics.iconSize, weight: isRedesign ? (systemImage == "plus" ? .medium : .semibold) : .regular))
                    .frame(width: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil)
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : WorkbenchControlColors.primaryText)

                Text(title)
                    .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 15, weight: isRedesign ? WorkbenchControlMetrics.redesignFontWeightControl : .regular))
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : WorkbenchControlColors.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignControlPaddingX : 0)
            .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : WorkbenchControlMetrics.controlHeight)
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .fill(isEnabled && isHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
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
        .buttonStyle(.plain)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
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
    var systemImage: String?
    var isRedesign: Bool = false
    var showsCheckmarkSlot = true
    var isEnabled = true
    var action: (() -> Void)? = nil
    var trailingSystemImage: String?
    var onHoverChange: ((Bool) -> Void)?
    @State private var isHovered = false
    @State private var hasPushedCursor = false

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: isRedesign ? 12 : 12) {
            if showsCheckmarkSlot {
                if isRedesign {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS, weight: .semibold))
                            .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize)
                            .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.iconDisabled)
                    } else {
                        Color.clear
                            .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize)
                    }
                } else {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Color.clear
                            .frame(width: 13, height: 13)
                    }
                }
            }

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS : 14, weight: isRedesign ? .medium : .medium))
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.iconDisabled) : (isEnabled ? WorkbenchControlColors.primaryText : WorkbenchControlColors.mutedText))
                    .frame(width: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil)
            }

            Text(title)
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeTable : 15, weight: .regular))
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : (isEnabled ? WorkbenchControlColors.primaryText : WorkbenchControlColors.mutedText))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.system(
                        size: isRedesign
                            ? WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                            : 14,
                        weight: .medium
                    ))
                    .foregroundStyle(
                        isRedesign
                            ? (isEnabled
                                ? WorkbenchRedesignColors.iconDefault
                                : WorkbenchRedesignColors.iconDisabled)
                            : (isEnabled
                                ? WorkbenchControlColors.primaryText
                                : WorkbenchControlColors.mutedText)
                    )
                    .frame(
                        width: isRedesign
                            ? WorkbenchControlMetrics.redesignControlIconSize
                            : nil,
                        height: isRedesign
                            ? WorkbenchControlMetrics.redesignControlIconSize
                            : nil
                    )
            }
        }
        .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled) : (isEnabled ? WorkbenchControlColors.primaryText : WorkbenchControlColors.mutedText))
        .padding(.horizontal, isRedesign ? 16 : 12)
        .frame(height: isRedesign ? 40 : 40)
        .background(
            RoundedRectangle(cornerRadius: isRedesign ? 8 : 8, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            onHoverChange?(inside)
            if isRedesign && isEnabled && action != nil {
                isHovered = inside
                if inside {
                    if !hasPushedCursor {
                        NSCursor.pointingHand.push()
                        hasPushedCursor = true
                    }
                } else {
                    if hasPushedCursor {
                        NSCursor.pop()
                        hasPushedCursor = false
                    }
                }
            } else if isEnabled {
                isHovered = inside
            } else {
                isHovered = false
            }
        }
        .onChange(of: isEnabled) { newValue in
            if isRedesign && isHovered && action != nil {
                if hasPushedCursor {
                    NSCursor.pop()
                    hasPushedCursor = false
                }
                if newValue {
                    NSCursor.pointingHand.push()
                    hasPushedCursor = true
                }
            }
        }
        .onDisappear {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }

    private var rowBackground: Color {
        guard isEnabled else { return .clear }
        if isRedesign {
            if isHighlighted || isHovered {
                return WorkbenchRedesignColors.bgHover
            }
            return .clear
        } else {
            if isHighlighted || isHovered {
                return WorkbenchControlColors.hoverFill
            }
            return .clear
        }
    }
}

struct WorkbenchIconButton: View {
    let systemImage: String
    var isRedesign: Bool = false
    var action: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var hasPushedCursor = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
                .focused($isFocused)
                .disableFocusEffect()
                .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
            } else {
                label
            }
        }
        .onHover { inside in
            isHovered = inside
            if isRedesign {
                updateCursor(inside: inside)
            }
        }
        .onChange(of: isEnabled) { newValue in
            if isRedesign && isHovered {
                updateCursor(inside: true, isEnabledVal: newValue)
            }
        }
        .onDisappear {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }

    private func updateCursor(inside: Bool, isEnabledVal: Bool? = nil) {
        let currentEnabled = isEnabledVal ?? isEnabled
        if inside {
            if !hasPushedCursor {
                if currentEnabled {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.operationNotAllowed.push()
                }
                hasPushedCursor = true
            } else {
                NSCursor.pop()
                if currentEnabled {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.operationNotAllowed.push()
                }
            }
        } else {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }

    private var label: some View {
        Image(systemName: systemImage)
            .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : WorkbenchControlMetrics.iconSize, weight: isRedesign ? .semibold : .medium))
            .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconDisabled) : WorkbenchControlColors.primaryText)
            .frame(
                width: isRedesign ? WorkbenchControlMetrics.redesignIconButtonSize : WorkbenchControlMetrics.controlHeight,
                height: isRedesign ? WorkbenchControlMetrics.redesignIconButtonSize : WorkbenchControlMetrics.controlHeight
            )
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .fill(isEnabled && isHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                    } else {
                        Color.clear
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
            .contentShape(Rectangle())
    }
}

struct WorkbenchPopoverPanel<Content: View>: View {
    var isRedesign: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        let cornerRadius: CGFloat = isRedesign ? 16 : 10
        content()
            .padding(isRedesign ? 4 : 8)
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(WorkbenchRedesignColors.bgPopover)
                            .shadowToken(WorkbenchRedesignColors.shadowPopover)
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
                    .strokeBorder(isRedesign ? WorkbenchRedesignColors.borderControl : WorkbenchControlColors.border.opacity(0.75), lineWidth: isRedesign ? 1.0 : 0.5)
            )
            .subtitleTableTextSelectionNonInteractiveRegion(
                cornerRadius: cornerRadius
            )
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

extension View {
    @ViewBuilder
    func disableFocusEffect() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
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
