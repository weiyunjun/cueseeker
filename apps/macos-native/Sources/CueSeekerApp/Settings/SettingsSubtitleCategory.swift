import AppKit
import CueSeekerPlayback
import SwiftUI

/// Settings / Subtitle: how SRT subtitles look and where they sit. See
/// `docs/human/requirements/20260913-Feature-SRT Subtitle Style And Position
/// Settings.md`, `docs/human/requirements/20260914-UI-Settings Categories
/// Merge And Grouped Card Layout.md`, and
/// `docs/human/requirements/20261016-UI-Subtitle Settings Simplification And
/// Controls Refinement.md`.
struct SettingsSubtitleCategory: View {
    private static let coordinateSpaceName = "SettingsSubtitleCategorySpace"
    private static let fontTriggerAnchorID = "fontTrigger"

    enum ColorFieldID: String, Hashable {
        case textColor
        case outlineColor
        case backgroundColor
        case shadowColor
    }

    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var isFontMenuOpen = false
    @State private var fontSearchQuery = ""
    @StateObject private var fontHighlight = MenuHighlightModel()
    @State private var activeColorPopover: ColorFieldID?
    @State private var anchorFrames: [String: CGRect] = [:]
    @State private var fontMenuFrame: CGRect = .zero
    @State private var colorPopoverFrame: CGRect = .zero
    @State private var availableFonts: [SettingsSubtitleFontOption] = []

    var body: some View {
        let style = settingsStore.srtSubtitleStyle
        let filteredFonts = Self.filterFonts(
            availableFonts: availableFonts,
            systemFontTitle: L("settings.subtitle.system_font"),
            query: fontSearchQuery
        )

        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
            SettingsGroup(title: L("settings.subtitle.section.text")) {
                row(L("settings.subtitle.font"), isFirst: true) {
                    SettingsSubtitleFontTrigger(
                        title: fontTitle(style.fontName),
                        isOpen: isFontMenuOpen
                    ) {
                        toggleFontMenu()
                    }
                    .workbenchDropdownAnchor(
                        id: Self.fontTriggerAnchorID,
                        in: Self.coordinateSpaceName
                    )
                }
                row(L("settings.subtitle.size")) {
                    numberField(
                        \.size,
                        minimum: SRTSubtitleStyle.minimumSize,
                        maximum: SettingsSubtitleBounds.sizeMaximum
                    )
                }
                row(L("settings.subtitle.style")) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing6) {
                        checkbox(L("settings.subtitle.bold"), \.isBold)
                        checkbox(L("settings.subtitle.italic"), \.isItalic)
                    }
                }
                row(L("settings.subtitle.color")) {
                    colorField(
                        id: .textColor,
                        label: L("settings.subtitle.color"),
                        keyPath: \.textColor
                    )
                }
                row(L("settings.subtitle.letter_spacing")) {
                    numberField(
                        \.letterSpacing,
                        minimum: SettingsSubtitleBounds.spacingMinimum,
                        maximum: SettingsSubtitleBounds.spacingMaximum
                    )
                }
                row(L("settings.subtitle.line_spacing")) {
                    numberField(
                        \.lineSpacing,
                        minimum: SettingsSubtitleBounds.spacingMinimum,
                        maximum: SettingsSubtitleBounds.spacingMaximum
                    )
                }
            }

            SettingsGroup(title: L("settings.subtitle.section.position")) {
                row(L("settings.subtitle.horizontal"), isFirst: true) {
                    segmentedControl(\.horizontalAlignment)
                }
                row(L("settings.subtitle.margin_x")) {
                    numberField(
                        \.marginX,
                        minimum: SettingsSubtitleBounds.marginMinimum,
                        maximum: SettingsSubtitleBounds.marginMaximum
                    )
                }
                row(L("settings.subtitle.vertical")) {
                    segmentedControl(\.verticalAlignment)
                }
                row(L("settings.subtitle.margin_y")) {
                    numberField(
                        \.marginY,
                        minimum: SettingsSubtitleBounds.marginMinimum,
                        maximum: SettingsSubtitleBounds.marginMaximum
                    )
                }
            }

            SettingsGroup(title: L("settings.subtitle.section.border")) {
                row(L("settings.subtitle.border_type"), isFirst: true) {
                    segmentedControl(\.borderType)
                }
                if style.borderType == .outline {
                    row(L("settings.subtitle.outline_color")) {
                        colorField(
                            id: .outlineColor,
                            label: L("settings.subtitle.outline_color"),
                            keyPath: \.outlineColor
                        )
                    }
                    row(L("settings.subtitle.outline_width")) {
                        numberField(
                            \.outlineWidth,
                            minimum: SettingsSubtitleBounds.effectMinimum,
                            maximum: SettingsSubtitleBounds.effectMaximum
                        )
                    }
                } else {
                    row(L("settings.subtitle.background_color")) {
                        colorField(
                            id: .backgroundColor,
                            label: L("settings.subtitle.background_color"),
                            keyPath: \.backgroundColor
                        )
                    }
                    row(L("settings.subtitle.background_opacity")) {
                        opacityField(\.backgroundColor)
                    }
                }
                row(L("settings.subtitle.blur")) {
                    numberField(
                        \.blur,
                        minimum: SettingsSubtitleBounds.effectMinimum,
                        maximum: SettingsSubtitleBounds.effectMaximum
                    )
                }
            }

            SettingsGroup(title: L("settings.subtitle.section.shadow")) {
                row(L("settings.subtitle.shadow_color"), isFirst: true) {
                    colorField(
                        id: .shadowColor,
                        label: L("settings.subtitle.shadow_color"),
                        keyPath: \.shadowColor
                    )
                }
                row(L("settings.subtitle.shadow_opacity")) {
                    opacityField(\.shadowColor)
                }
                row(L("settings.subtitle.shadow_offset")) {
                    numberField(
                        \.shadowOffset,
                        minimum: SettingsSubtitleBounds.effectMinimum,
                        maximum: SettingsSubtitleBounds.effectMaximum
                    )
                }
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                WorkbenchButton(
                    title: L("settings.subtitle.restore_defaults"),
                    icon: .arrowCounterClockwise,
                    isRedesign: true
                ) {
                    closeAllPopovers()
                    settingsStore.srtSubtitleStyle = SRTSubtitleStyle()
                }
                .disabled(style == SRTSubtitleStyle())
                .workbenchTooltip(
                    scenarioID: "disabled.settings.subtitle.restore_defaults",
                    surface: .settings,
                    isActive: style == SRTSubtitleStyle(),
                    label: L("tooltip.disabled.settings.subtitle.restore_defaults")
                )
            }
        }
        .coordinateSpace(name: Self.coordinateSpaceName)
        .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { anchors in
            for (key, rect) in anchors where rect != .zero {
                anchorFrames[key] = rect
            }
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                if isFontMenuOpen || activeColorPopover != nil {
                    SettingsSubtitleOutsideClickMonitor(
                        activeRects: activePopoverInteractiveRects,
                        onOutsideClick: {
                            closeAllPopovers()
                        }
                    )
                    .frame(width: 0, height: 0)
                }

                if isFontMenuOpen,
                   let triggerFrame = anchorFrames[Self.fontTriggerAnchorID] {
                    let menuWidth = WorkbenchControlMetrics.redesignSettingsFontMenuWidth
                    let originX = max(0, triggerFrame.maxX - menuWidth)
                    let originY = triggerFrame.maxY + WorkbenchControlMetrics.redesignSpacing1

                    SettingsSubtitleFontMenu(
                        query: $fontSearchQuery,
                        options: filteredFonts,
                        selectedFontName: style.fontName,
                        highlight: fontHighlight,
                        onSelect: { option in
                            settingsStore.srtSubtitleStyle.fontName = option.fontName
                            closeFontMenu()
                        },
                        onClose: {
                            closeFontMenu()
                        }
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    fontMenuFrame = CGRect(
                                        origin: CGPoint(x: originX, y: originY),
                                        size: geo.size
                                    )
                                }
                                .onChange(of: geo.size) { newSize in
                                    fontMenuFrame = CGRect(
                                        origin: CGPoint(x: originX, y: originY),
                                        size: newSize
                                    )
                                }
                        }
                    )
                    .offset(x: originX, y: originY)
                    .zIndex(1000)
                }

                if let activeID = activeColorPopover,
                   let fieldFrame = anchorFrames[activeID.rawValue] {
                    SettingsSubtitleColorPresetsPopover(
                        selectedColor: colorBinding(for: activeID).wrappedValue,
                        onSelectPreset: { presetHex in
                            applyPresetColor(presetHex, for: activeID)
                        }
                    )
                    .background(
                        GeometryReader { geo in
                            let originX = max(0, fieldFrame.maxX - geo.size.width)
                            let originY = fieldFrame.maxY + WorkbenchControlMetrics.redesignSpacing1
                            Color.clear
                                .onAppear {
                                    colorPopoverFrame = CGRect(
                                        origin: CGPoint(x: originX, y: originY),
                                        size: geo.size
                                    )
                                }
                                .onChange(of: geo.size) { newSize in
                                    let updatedX = max(0, fieldFrame.maxX - newSize.width)
                                    colorPopoverFrame = CGRect(
                                        origin: CGPoint(x: updatedX, y: originY),
                                        size: newSize
                                    )
                                }
                        }
                    )
                    .offset(
                        x: max(
                            0,
                            fieldFrame.maxX - (
                                colorPopoverFrame.width > 0
                                    ? colorPopoverFrame.width
                                    : SettingsSubtitleColorPresetsPopover.intrinsicWidth
                            )
                        ),
                        y: fieldFrame.maxY + WorkbenchControlMetrics.redesignSpacing1
                    )
                    .zIndex(1000)
                }
            }
        }
        .onAppear {
            if availableFonts.isEmpty {
                availableFonts = Self.loadSystemFonts()
            }
        }
        .onChange(of: fontSearchQuery) { newQuery in
            let matches = Self.filterFonts(
                availableFonts: availableFonts,
                systemFontTitle: L("settings.subtitle.system_font"),
                query: newQuery
            )
            fontHighlight.open(
                selectablePositions: Array(matches.indices),
                defaultPosition: 0
            )
        }
        .onChange(of: style.borderType) { _ in
            if activeColorPopover == .outlineColor || activeColorPopover == .backgroundColor {
                activeColorPopover = nil
            }
        }
        .onDisappear {
            closeAllPopovers()
        }
    }

    private var activePopoverInteractiveRects: [CGRect] {
        var rects: [CGRect] = []
        if isFontMenuOpen {
            if let trigger = anchorFrames[Self.fontTriggerAnchorID] {
                rects.append(trigger)
            }
            if fontMenuFrame != .zero {
                rects.append(fontMenuFrame)
            }
        }
        if let activeID = activeColorPopover {
            if let field = anchorFrames[activeID.rawValue] {
                rects.append(field)
            }
            if colorPopoverFrame != .zero {
                rects.append(colorPopoverFrame)
            }
        }
        return rects
    }

    private func toggleFontMenu() {
        if isFontMenuOpen {
            closeFontMenu()
        } else {
            activeColorPopover = nil
            if availableFonts.isEmpty {
                availableFonts = Self.loadSystemFonts()
            }
            fontSearchQuery = ""
            let options = Self.filterFonts(
                availableFonts: availableFonts,
                systemFontTitle: L("settings.subtitle.system_font"),
                query: ""
            )
            fontHighlight.open(
                selectablePositions: Array(options.indices),
                defaultPosition: 0
            )
            isFontMenuOpen = true
        }
    }

    private func closeFontMenu() {
        guard isFontMenuOpen else { return }
        isFontMenuOpen = false
        fontHighlight.close()
    }

    private func closeAllPopovers() {
        closeFontMenu()
        if activeColorPopover != nil {
            activeColorPopover = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    /// A row, with the line above it unless it opens its card.
    @ViewBuilder
    private func row<Content: View>(
        _ title: String,
        isFirst: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if !isFirst {
            SettingsRowDivider()
        }

        SettingsRow(title) {
            content()
        }
    }

    private func numberField(
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, Double>,
        minimum: Double,
        maximum: Double,
        unit: String? = nil
    ) -> some View {
        SettingsSubtitleNumberField(
            value: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
            ),
            minimum: minimum,
            maximum: maximum,
            unit: unit
        )
    }

    private func opacityField(
        _ colorKeyPath: WritableKeyPath<SRTSubtitleStyle, SRTSubtitleStyle.Color>
    ) -> some View {
        SettingsSubtitleNumberField(
            value: Binding(
                get: {
                    (settingsStore.srtSubtitleStyle[keyPath: colorKeyPath].alpha * 100).rounded()
                },
                set: { percentage in
                    let clamped = min(
                        max(percentage, SettingsSubtitleBounds.opacityMinimum),
                        SettingsSubtitleBounds.opacityMaximum
                    )
                    settingsStore.srtSubtitleStyle[keyPath: colorKeyPath].alpha = clamped / 100.0
                }
            ),
            minimum: SettingsSubtitleBounds.opacityMinimum,
            maximum: SettingsSubtitleBounds.opacityMaximum,
            unit: "%"
        )
    }

    private func colorField(
        id: ColorFieldID,
        label: String,
        keyPath: WritableKeyPath<SRTSubtitleStyle, SRTSubtitleStyle.Color>
    ) -> some View {
        SettingsSubtitleColorField(
            color: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
            ),
            accessibilityLabel: label,
            isPopoverOpen: Binding(
                get: { activeColorPopover == id },
                set: { isOpen in
                    if isOpen {
                        closeFontMenu()
                        activeColorPopover = id
                    } else if activeColorPopover == id {
                        activeColorPopover = nil
                    }
                }
            )
        )
        .workbenchDropdownAnchor(id: id.rawValue, in: Self.coordinateSpaceName)
    }

    private func colorBinding(for id: ColorFieldID) -> Binding<SRTSubtitleStyle.Color> {
        let keyPath: WritableKeyPath<SRTSubtitleStyle, SRTSubtitleStyle.Color>
        switch id {
        case .textColor:
            keyPath = \.textColor
        case .outlineColor:
            keyPath = \.outlineColor
        case .backgroundColor:
            keyPath = \.backgroundColor
        case .shadowColor:
            keyPath = \.shadowColor
        }
        return Binding(
            get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
            set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
        )
    }

    private func applyPresetColor(_ presetHex: String, for id: ColorFieldID) {
        guard let rgb = SettingsSubtitleColorField.parseRGB(fromHex: presetHex) else {
            return
        }
        let binding = colorBinding(for: id)
        var updated = binding.wrappedValue
        updated.red = rgb.red
        updated.green = rgb.green
        updated.blue = rgb.blue
        binding.wrappedValue = updated
    }

    private func checkbox(
        _ title: String,
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, Bool>
    ) -> some View {
        let isChecked = settingsStore.srtSubtitleStyle[keyPath: keyPath]

        return Button {
            settingsStore.srtSubtitleStyle[keyPath: keyPath].toggle()
        } label: {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                WorkbenchCheckboxGlyph(
                    state: isChecked ? .checked : .unchecked,
                    isEnabled: true,
                    size: WorkbenchControlMetrics.redesignCheckboxSize
                )

                Text(title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
    }

    private func segmentedControl<Option: SettingsSubtitleOption>(
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, Option>
    ) -> some View {
        WorkbenchSegmentedControl(
            options: Array(Option.allCases),
            selection: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
            ),
            title: \.title,
            accessibilityLabel: \.title
        )
    }

    private func fontTitle(_ fontName: String?) -> String {
        guard let fontName, !fontName.isEmpty else {
            return L("settings.subtitle.system_font")
        }
        if let match = availableFonts.first(where: {
            $0.fontName == fontName || $0.title == fontName
        }) {
            return match.title
        }
        if let nsFont = NSFont(name: fontName, size: NSFont.systemFontSize) {
            return nsFont.familyName ?? nsFont.displayName ?? fontName
        }
        return fontName
    }

    static func loadSystemFonts() -> [SettingsSubtitleFontOption] {
        let fontManager = NSFontManager.shared
        let families = fontManager.availableFontFamilies.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        var result: [SettingsSubtitleFontOption] = []
        result.reserveCapacity(families.count)
        for family in families {
            guard !family.hasPrefix(".") else { continue }
            let postScriptName = fontManager
                .font(withFamily: family, traits: [], weight: 5, size: 12)?
                .fontName
                ?? NSFont(name: family, size: 12)?.fontName
                ?? family
            result.append(
                SettingsSubtitleFontOption(
                    id: postScriptName,
                    title: family,
                    fontName: postScriptName
                )
            )
        }
        return result
    }

    static func filterFonts(
        availableFonts: [SettingsSubtitleFontOption],
        systemFontTitle: String,
        query: String
    ) -> [SettingsSubtitleFontOption] {
        let systemOption = SettingsSubtitleFontOption(
            id: "__system_font__",
            title: systemFontTitle,
            fontName: nil
        )
        let allOptions = [systemOption] + availableFonts
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return allOptions
        }
        return allOptions.filter { option in
            if option.title.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            if let fontName = option.fontName,
               fontName.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            return false
        }
    }
}

enum SettingsSubtitleBounds {
    static let sizeMaximum: Double = 200
    static let spacingMinimum: Double = 0
    static let spacingMaximum: Double = 100
    static let marginMinimum: Double = 0
    static let marginMaximum: Double = 500
    static let effectMinimum: Double = 0
    static let effectMaximum: Double = 50
    static let opacityMinimum: Double = 0
    static let opacityMaximum: Double = 100
}

struct SettingsSubtitleFontOption: Identifiable, Equatable {
    let id: String
    let title: String
    let fontName: String?

    func matches(selectedFontName: String?) -> Bool {
        guard let selectedFontName, !selectedFontName.isEmpty else {
            return fontName == nil
        }
        if fontName == selectedFontName || title == selectedFontName {
            return true
        }
        if let nsFont = NSFont(name: selectedFontName, size: 12),
           nsFont.familyName == title {
            return true
        }
        return false
    }
}

struct SettingsSubtitleFontTrigger: View {
    let title: String
    let isOpen: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                AppIconImage(
                    .caretDown,
                    size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS
                )
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
            .frame(
                width: WorkbenchControlMetrics.redesignSettingsPopupWidth,
                height: WorkbenchControlMetrics.redesignFieldHeight
            )
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                    style: .continuous
                )
                .fill(
                    isPressed
                        ? WorkbenchRedesignColors.bgPressed
                        : (isOpen || isHovered
                            ? WorkbenchRedesignColors.bgHover
                            : WorkbenchRedesignColors.bgControl)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isOpen
                        ? WorkbenchRedesignColors.borderFocus
                        : ((isPressed || isHovered)
                            ? WorkbenchRedesignColors.borderControlHover
                            : WorkbenchRedesignColors.borderControl),
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }
}

struct SettingsSubtitleFontMenu: View {
    @Binding var query: String
    let options: [SettingsSubtitleFontOption]
    let selectedFontName: String?
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (SettingsSubtitleFontOption) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            WorkbenchSearchField(
                placeholder: L("settings.subtitle.font_search_placeholder"),
                text: $query,
                isRedesign: true,
                autofocus: true,
                placesInsertionPointAtEndOnAutofocus: true,
                onSubmit: {
                    if let highlighted = highlight.highlightedPosition,
                       options.indices.contains(highlighted) {
                        onSelect(options[highlighted])
                    }
                },
                onMoveUp: {
                    highlight.moveHighlight(by: -1)
                },
                onMoveDown: {
                    highlight.moveHighlight(by: 1)
                },
                onCancel: {
                    onClose()
                    return true
                }
            )
            .padding(MenuMetrics.padding)

            WorkbenchMenuDivider()

            if options.isEmpty {
                Text(L("settings.subtitle.no_results"))
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: WorkbenchControlMetrics.redesignMenuItemHeight * 2
                    )
                    .padding(.horizontal, MenuMetrics.padding)
                    .padding(.bottom, MenuMetrics.padding)
            } else {
                ScrollViewReader { proxy in
                    MenuHeightCap(
                        height: WorkbenchControlMetrics.redesignSettingsFontMenuListMaxHeight
                    ) {
                        WorkbenchScrollView(
                            scrollbarInset: MenuMetrics.scrollbarOuterGap
                        ) {
                            MenuItemStack(
                                padding: MenuMetrics.padding,
                                strip: MenuMetrics.scrollbarStrip,
                                cap: WorkbenchControlMetrics.redesignSettingsFontMenuListMaxHeight
                            ) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(
                                        Array(options.enumerated()),
                                        id: \.element.id
                                    ) { position, option in
                                        WorkbenchPopoverRow(
                                            title: option.title,
                                            isSelected: option.matches(
                                                selectedFontName: selectedFontName
                                            ),
                                            isHighlighted: highlight.highlightedPosition == position,
                                            isRedesign: true,
                                            showsCheckmarkSlot: true,
                                            action: {
                                                onSelect(option)
                                            },
                                            onHoverChange: { isHovered in
                                                highlight.noteHover(isHovered, at: position)
                                            }
                                        )
                                        .id(position)
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        if let position = highlight.highlightedPosition {
                            proxy.scrollTo(position)
                        }
                    }
                    .onChange(of: highlight.keyboardMoveCount) { _ in
                        if let position = highlight.highlightedPosition {
                            proxy.scrollTo(position)
                        }
                    }
                }
            }
        }
        .frame(width: WorkbenchControlMetrics.redesignSettingsFontMenuWidth)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgPopover)
            .shadowToken(
                WorkbenchRedesignColors.shadowPopover,
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderControl,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
    }
}

/// An inline hex color field: a borderless solid color swatch on the left and a
/// fixed `#` prefix with a 3- or 6-digit hex input on the right.
struct SettingsSubtitleColorField: View {
    static let presetHexColors: [String] = [
        "FFFFFF", "FFFF00", "00FFFF", "00FF00", "FF9900", "FF3B30",
        "000000", "8E8E93", "007AFF", "AF52DE", "FF2D55", "5856D6",
    ]

    @Binding var color: SRTSubtitleStyle.Color
    let accessibilityLabel: String
    @Binding var isPopoverOpen: Bool

    @State private var draft = ""
    @State private var lastCommittedHex = "FFFFFF"
    @FocusState private var isFocused: Bool
    @State private var isNativeFocused = false

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignSettingsColorSwatchRadius,
                style: .continuous
            )
            .fill(color.opaqueSwiftUIColor)
            .frame(
                width: WorkbenchControlMetrics.redesignSettingsColorSwatchSize,
                height: WorkbenchControlMetrics.redesignSettingsColorSwatchSize
            )

            HStack(spacing: 2) {
                Text("#")
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .fixedSize()

                WorkbenchSingleLineTextInput(
                    placeholder: "",
                    text: Binding(
                        get: { draft },
                        set: { newValue in
                            draft = newValue
                            applyDraft(newValue)
                        }
                    ),
                    placeholderColor: WorkbenchRedesignColors.textPlaceholder,
                    textColor: WorkbenchRedesignColors.textPrimary,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                    alignment: .left,
                    usesMonospacedDigits: true,
                    focus: $isFocused,
                    accessibilityLabel: accessibilityLabel,
                    normalizeDraft: Self.normalizeDraft,
                    onFocusChange: { focused in
                        isNativeFocused = focused
                        if focused {
                            isPopoverOpen = true
                        } else {
                            isPopoverOpen = false
                        }
                    },
                    onEditingEnded: commitDraft,
                    onSubmit: nil,
                    onCancel: {
                        isPopoverOpen = false
                        isFocused = false
                        NSApp.keyWindow?.makeFirstResponder(nil)
                        return true
                    }
                )
            }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
        .frame(
            width: WorkbenchControlMetrics.redesignSettingsNumberFieldWidth,
            height: WorkbenchControlMetrics.redesignFieldHeight
        )
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgControl)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .strokeBorder(
                (isNativeFocused || isFocused || isPopoverOpen)
                    ? WorkbenchRedesignColors.borderFocus
                    : WorkbenchRedesignColors.borderControl,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .overlay(
            WorkbenchSingleLineContainerOverlay(
                isEnabled: true,
                onPressRelease: {
                    isPopoverOpen = true
                }
            )
        )
        .onAppear {
            let initial = Self.hexString(for: color)
            draft = initial
            lastCommittedHex = initial
        }
        .onDisappear {
            commitDraft()
        }
        .onChange(of: draft) { newDraft in
            applyDraft(newDraft)
        }
        .onChange(of: isFocused) { focused in
            if !focused {
                commitDraft()
            }
        }
        .onChange(of: color) { newColor in
            // If updated externally (e.g. preset swatch click or Restore Defaults)
            // and current committed hex does not match newColor's RGB, sync draft.
            if !Self.hexMatchesColor(lastCommittedHex, color: newColor) {
                let updatedHex = Self.hexString(for: newColor)
                lastCommittedHex = updatedHex
                draft = updatedHex
            } else if !isFocused && !isNativeFocused && draft != lastCommittedHex {
                draft = lastCommittedHex
            }
        }
    }

    static func normalizeDraft(_ draft: String) -> String {
        let prefix = draft.prefix { $0 != "." && !$0.isNewline }
        let hexChars = prefix.compactMap { character -> Character? in
            guard character.isASCII, character.isHexDigit else {
                return nil
            }
            return Character(character.uppercased())
        }
        return String(hexChars.prefix(6))
    }

    static func parseRGB(fromHex hex: String) -> (red: Double, green: Double, blue: Double)? {
        let normalized = normalizeDraft(hex)
        var value: UInt64 = 0
        guard Scanner(string: normalized).scanHexInt64(&value) else {
            return nil
        }
        switch normalized.count {
        case 3:
            let r = Double((value >> 8) & 0xF) * 17.0 / 255.0
            let g = Double((value >> 4) & 0xF) * 17.0 / 255.0
            let b = Double(value & 0xF) * 17.0 / 255.0
            return (r, g, b)
        case 6:
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            return (r, g, b)
        default:
            return nil
        }
    }

    static func hexString(for color: SRTSubtitleStyle.Color) -> String {
        let r = Int((min(max(color.red, 0), 1) * 255).rounded())
        let g = Int((min(max(color.green, 0), 1) * 255).rounded())
        let b = Int((min(max(color.blue, 0), 1) * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }

    static func hexMatchesColor(_ hex: String, color: SRTSubtitleStyle.Color) -> Bool {
        guard let parsed = parseRGB(fromHex: hex) else {
            return false
        }
        let parsedColor = SRTSubtitleStyle.Color(
            red: parsed.red,
            green: parsed.green,
            blue: parsed.blue,
            alpha: 1
        )
        return hexString(for: parsedColor) == hexString(for: color)
    }

    private func applyDraft(_ rawDraft: String) {
        let normalized = Self.normalizeDraft(rawDraft)
        guard normalized == rawDraft else {
            draft = normalized
            return
        }
        guard normalized.count == 6,
              let rgb = Self.parseRGB(fromHex: normalized)
        else {
            return
        }
        lastCommittedHex = normalized
        updateColorRGB(rgb)
    }

    private func commitDraft() {
        let normalized = Self.normalizeDraft(draft)
        switch normalized.count {
        case 6:
            if let rgb = Self.parseRGB(fromHex: normalized) {
                lastCommittedHex = normalized
                draft = normalized
                updateColorRGB(rgb)
            }
        case 4, 5:
            let truncated3 = String(normalized.prefix(3))
            if let rgb = Self.parseRGB(fromHex: truncated3) {
                lastCommittedHex = truncated3
                draft = truncated3
                updateColorRGB(rgb)
            }
        case 3:
            if let rgb = Self.parseRGB(fromHex: normalized) {
                lastCommittedHex = normalized
                draft = normalized
                updateColorRGB(rgb)
            }
        default:
            draft = lastCommittedHex
        }
    }

    private func updateColorRGB(_ rgb: (red: Double, green: Double, blue: Double)) {
        guard abs(color.red - rgb.red) > 0.0001
            || abs(color.green - rgb.green) > 0.0001
            || abs(color.blue - rgb.blue) > 0.0001
        else {
            return
        }
        color = SRTSubtitleStyle.Color(
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            alpha: color.alpha
        )
    }
}

struct SettingsSubtitleColorPresetsPopover: View {
    let selectedColor: SRTSubtitleStyle.Color
    let onSelectPreset: (String) -> Void

    static var intrinsicWidth: CGFloat {
        let columns = CGFloat(WorkbenchControlMetrics.redesignSettingsColorPresetColumns)
        let swatch = WorkbenchControlMetrics.redesignSettingsColorPresetSwatchSize
        let gap = WorkbenchControlMetrics.redesignSpacing2
        let padding = WorkbenchControlMetrics.redesignSpacing3
        return columns * swatch + (columns - 1) * gap + padding * 2
    }

    var body: some View {
        let columns = WorkbenchControlMetrics.redesignSettingsColorPresetColumns
        let presets = SettingsSubtitleColorField.presetHexColors
        let rowCount = (presets.count + columns - 1) / columns

        VStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    ForEach(0..<columns, id: \.self) { columnIndex in
                        let index = rowIndex * columns + columnIndex
                        if index < presets.count {
                            let hex = presets[index]
                            Button {
                                onSelectPreset(hex)
                            } label: {
                                RoundedRectangle(
                                    cornerRadius: WorkbenchControlMetrics.redesignSettingsColorSwatchRadius,
                                    style: .continuous
                                )
                                .fill(Color(nsColor: .hex(hex)))
                                .frame(
                                    width: WorkbenchControlMetrics.redesignSettingsColorPresetSwatchSize,
                                    height: WorkbenchControlMetrics.redesignSettingsColorPresetSwatchSize
                                )
                            }
                            .buttonStyle(StaticButtonStyle())
                            .focusable(false)
                        }
                    }
                }
            }
        }
        .padding(WorkbenchControlMetrics.redesignSpacing3)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgPopover)
            .shadowToken(
                WorkbenchRedesignColors.shadowPopover,
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignMenuRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderControl,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
    }
}

/// A number typed as integer text. A value in range applies as it is typed,
/// values above `maximum` clamp immediately, and leaving the field brings a
/// value below `minimum` to `minimum` or restores an empty draft. Pressing
/// Return performs no action.
struct SettingsSubtitleNumberField: View {
    @Binding var value: Double
    let minimum: Double
    var maximum: Double = SettingsSubtitleBounds.marginMaximum
    var unit: String? = nil

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        WorkbenchNumberField(
            placeholder: "",
            text: Binding(
                get: { draft },
                set: { newValue in
                    draft = newValue
                    applyDraft(newValue)
                }
            ),
            unit: unit,
            focus: $isFocused,
            normalizeDraft: { raw in
                Self.normalizeDraft(raw, maximum: maximum)
            },
            onEditingEnded: commitDraft,
            onSubmit: nil
        )
        .frame(width: WorkbenchControlMetrics.redesignSettingsNumberFieldWidth)
        .onAppear {
            draft = Self.text(for: value)
        }
        .onDisappear {
            commitDraft()
        }
        .onChange(of: draft) { draft in
            applyDraft(draft)
        }
        .onChange(of: isFocused) { isFocused in
            if !isFocused {
                commitDraft()
            }
        }
        .onChange(of: value) { value in
            if !isFocused,
               Self.parseDouble(draft) != value {
                draft = Self.text(for: value)
            }
        }
    }

    static func filterDraft(_ draft: String) -> String {
        let prefix = draft.prefix { $0 != "." && !$0.isNewline }
        return String(prefix.filter { $0.isASCII && $0.isNumber })
    }

    static func normalizeDraft(_ draft: String, maximum: Double) -> String {
        let digits = filterDraft(draft)
        guard !digits.isEmpty else {
            return ""
        }
        let maxInt = Int(maximum.rounded())
        guard let parsed = Int(digits) else {
            return String(maxInt)
        }
        if parsed > maxInt {
            return String(maxInt)
        }
        return digits
    }

    private static func parseDouble(_ draft: String) -> Double? {
        guard !draft.isEmpty else { return nil }
        return Int(draft).map(Double.init) ?? Double(draft)
    }

    private func applyDraft(_ rawDraft: String) {
        let normalized = Self.normalizeDraft(rawDraft, maximum: maximum)
        guard normalized == rawDraft else {
            self.draft = normalized
            return
        }
        guard let parsed = Self.parseDouble(normalized),
              parsed >= minimum,
              parsed <= maximum
        else {
            return
        }
        value = parsed
    }

    private func commitDraft() {
        let normalized = Self.normalizeDraft(draft, maximum: maximum)
        guard let parsed = Self.parseDouble(normalized) else {
            draft = Self.text(for: value)
            return
        }
        if parsed < minimum {
            value = minimum
            draft = Self.text(for: minimum)
        } else if parsed > maximum {
            value = maximum
            draft = Self.text(for: maximum)
        } else {
            value = parsed
            let stripped = String(normalized.drop(while: { $0 == "0" }))
            draft = stripped.isEmpty ? "0" : stripped
        }
    }

    private static func text(for value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        if value == value.rounded(),
           let decimal = Decimal(string: String(format: "%.0f", value)) {
            return NSDecimalNumber(decimal: decimal).stringValue
        }
        return String(value)
    }
}

private struct SettingsSubtitleOutsideClickMonitor: NSViewRepresentable {
    let activeRects: [CGRect]
    let onOutsideClick: () -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.activeRects = activeRects
        view.onOutsideClick = onOutsideClick
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.activeRects = activeRects
        nsView.onOutsideClick = onOutsideClick
    }

    static func dismantleNSView(_ nsView: MonitorView, coordinator: ()) {
        nsView.stopMonitoring()
    }

    @MainActor
    final class MonitorView: NSView {
        var activeRects: [CGRect] = []
        var onOutsideClick: (() -> Void)?
        nonisolated(unsafe) private var monitor: Any?

        override var isFlipped: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleMouseDown(event)
                }
                return event
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handleMouseDown(_ event: NSEvent) {
            guard let window, event.window === window else {
                onOutsideClick?()
                return
            }
            let localPoint = convert(event.locationInWindow, from: nil)
            let isInside = activeRects.contains { $0.contains(localPoint) }
            if !isInside {
                onOutsideClick?()
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

private protocol SettingsSubtitleOption: Hashable, CaseIterable {
    var title: String { get }
}

extension SRTSubtitleStyle.BorderType: SettingsSubtitleOption {
    fileprivate var title: String {
        switch self {
        case .outline:
            L("settings.subtitle.border_type.outline")
        case .backgroundBox:
            L("settings.subtitle.border_type.background_box")
        }
    }
}

extension SRTSubtitleStyle.HorizontalAlignment: SettingsSubtitleOption {
    fileprivate var title: String {
        switch self {
        case .left:
            L("settings.subtitle.left")
        case .center:
            L("settings.subtitle.center")
        case .right:
            L("settings.subtitle.right")
        }
    }
}

extension SRTSubtitleStyle.VerticalAlignment: SettingsSubtitleOption {
    fileprivate var title: String {
        switch self {
        case .top:
            L("settings.subtitle.top")
        case .center:
            L("settings.subtitle.center")
        case .bottom:
            L("settings.subtitle.bottom")
        }
    }
}

private extension SRTSubtitleStyle.Color {
    var opaqueSwiftUIColor: SwiftUI.Color {
        SwiftUI.Color(nsColor: NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: 1
        ))
    }
}
