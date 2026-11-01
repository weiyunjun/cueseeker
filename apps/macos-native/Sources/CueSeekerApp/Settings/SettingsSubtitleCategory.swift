import AppKit
import CueSeekerPlayback
import SwiftUI

/// Settings / Subtitle: how SRT subtitles look and where they sit. See
/// `docs/human/requirements/20260913-Feature-SRT Subtitle Style And Position
/// Settings.md`, `docs/human/requirements/20260914-UI-Settings Categories
/// Merge And Grouped Card Layout.md`,
/// `docs/human/requirements/20261016-UI-Subtitle Settings Simplification And
/// Controls Refinement.md`, and
/// `docs/human/requirements/20261024-UI-Subtitle Font Menu Redesign And
/// Performance Optimization.md`.
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
    @Environment(\.interfaceLayers) private var environmentInterfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    @StateObject private var fallbackInterfaceLayers = InterfaceLayerRegistry()

    @State private var activeFontMenu: SettingsSubtitleFontMenuState?
    @StateObject private var fontHighlight = MenuHighlightModel()
    @State private var fontScrollController = WorkbenchScrollViewController()
    @State private var fontTriggerAnchor = MenuAnchorHandle()
    @State private var viewportGeometry = SettingsSubtitleViewportGeometry()
    @State private var activeColorPopover: ColorFieldID?
    @State private var anchorFrames: [String: CGRect] = [:]
    @State private var colorPopoverFrame: CGRect = .zero
    @State private var availableFonts: [SettingsSubtitleFontOption] = []

    private var activeInterfaceLayers: InterfaceLayerRegistry {
        environmentInterfaceLayers ?? fallbackInterfaceLayers
    }

    private var isFontMenuOpen: Bool {
        activeFontMenu != nil
    }

    var body: some View {
        let style = settingsStore.srtSubtitleStyle
        let systemFontTitle = L("settings.subtitle.system_font")

        WorkbenchAccessibilityReader { accessibility in
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                SettingsGroup(title: L("settings.subtitle.section.text")) {
                    row(L("settings.subtitle.font"), isFirst: true) {
                        SettingsSubtitleFontTrigger(
                            title: fontTitle(style.fontName),
                            isOpen: isFontMenuOpen,
                            isFocused: accessibility?.isSettingsFocused(.subtitleFontDropdown) == true
                        ) {
                            toggleFontMenu()
                        }
                        .background(MenuAnchorProbe(handle: fontTriggerAnchor))
                        .workbenchDropdownAnchor(
                            id: Self.fontTriggerAnchorID,
                            in: Self.coordinateSpaceName
                        )
                    }
                    row(L("settings.subtitle.size")) {
                        numberField(
                            \.size,
                            minimum: SRTSubtitleStyle.minimumSize,
                            maximum: SettingsSubtitleBounds.sizeMaximum,
                            fieldID: .subtitleSize
                        )
                    }
                    row(L("settings.subtitle.style")) {
                        HStack(spacing: WorkbenchControlMetrics.redesignSpacing6) {
                            checkbox(
                                L("settings.subtitle.bold"),
                                \.isBold,
                                isFocused: accessibility?.isSettingsFocused(.subtitleBold) == true
                            )
                            checkbox(
                                L("settings.subtitle.italic"),
                                \.isItalic,
                                isFocused: accessibility?.isSettingsFocused(.subtitleItalic) == true
                            )
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
                            maximum: SettingsSubtitleBounds.spacingMaximum,
                            fieldID: .subtitleLetterSpacing
                        )
                    }
                    row(L("settings.subtitle.line_spacing")) {
                        numberField(
                            \.lineSpacing,
                            minimum: SettingsSubtitleBounds.spacingMinimum,
                            maximum: SettingsSubtitleBounds.spacingMaximum,
                            fieldID: .subtitleLineSpacing
                        )
                    }
                }

                SettingsGroup(title: L("settings.subtitle.section.position")) {
                    row(L("settings.subtitle.horizontal"), isFirst: true) {
                        segmentedControl(
                            \.horizontalAlignment,
                            focusedOption: SRTSubtitleStyle.HorizontalAlignment.allCases.first { option in
                                accessibility?.isSettingsFocused(.subtitleHorizontalAlignment(option)) == true
                            }
                        )
                    }
                    row(L("settings.subtitle.margin_x")) {
                        numberField(
                            \.marginX,
                            minimum: SettingsSubtitleBounds.marginMinimum,
                            maximum: SettingsSubtitleBounds.marginMaximum,
                            fieldID: .subtitleMarginX
                        )
                    }
                    row(L("settings.subtitle.vertical")) {
                        segmentedControl(
                            \.verticalAlignment,
                            focusedOption: SRTSubtitleStyle.VerticalAlignment.allCases.first { option in
                                accessibility?.isSettingsFocused(.subtitleVerticalAlignment(option)) == true
                            }
                        )
                    }
                    row(L("settings.subtitle.margin_y")) {
                        numberField(
                            \.marginY,
                            minimum: SettingsSubtitleBounds.marginMinimum,
                            maximum: SettingsSubtitleBounds.marginMaximum,
                            fieldID: .subtitleMarginY
                        )
                    }
                }

                SettingsGroup(title: L("settings.subtitle.section.border")) {
                    row(L("settings.subtitle.border_type"), isFirst: true) {
                        segmentedControl(
                            \.borderType,
                            focusedOption: SRTSubtitleStyle.BorderType.allCases.first { option in
                                accessibility?.isSettingsFocused(.subtitleBorderType(option)) == true
                            }
                        )
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
                                maximum: SettingsSubtitleBounds.effectMaximum,
                                fieldID: .subtitleOutlineWidth
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
                            opacityField(\.backgroundColor, fieldID: .subtitleBackgroundOpacity)
                        }
                    }
                    row(L("settings.subtitle.blur")) {
                        numberField(
                            \.blur,
                            minimum: SettingsSubtitleBounds.effectMinimum,
                            maximum: SettingsSubtitleBounds.effectMaximum,
                            fieldID: .subtitleBlur
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
                        opacityField(\.shadowColor, fieldID: .subtitleShadowOpacity)
                    }
                    row(L("settings.subtitle.shadow_offset")) {
                        numberField(
                            \.shadowOffset,
                            minimum: SettingsSubtitleBounds.effectMinimum,
                            maximum: SettingsSubtitleBounds.effectMaximum,
                            fieldID: .subtitleShadowOffset
                        )
                    }
                }

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    WorkbenchButton(
                        title: L("settings.subtitle.restore_defaults"),
                        icon: .arrowCounterClockwise,
                        isFocused: accessibility?.isSettingsFocused(.subtitleRestoreDefaults) == true
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
            .onChange(of: accessibility?.activeSubtitleColorPopover) { newPopover in
                if newPopover != nil {
                    closeFontMenu()
                }
                if activeColorPopover != newPopover {
                    activeColorPopover = newPopover
                }
            }
        }
        .coordinateSpace(name: Self.coordinateSpaceName)
        .background(SettingsSubtitleViewportProbe(geometry: viewportGeometry))
        .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { anchors in
            for (key, rect) in anchors where rect != .zero {
                anchorFrames[key] = rect
            }
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                if activeColorPopover != nil {
                    SettingsSubtitleOutsideClickMonitor(
                        activeRects: activePopoverInteractiveRects,
                        onOutsideClick: {
                            closeAllPopovers()
                        }
                    )
                    .frame(width: 0, height: 0)
                }

                if let activeFontMenu {
                    let menuFrame = activeFontMenu.menuFrame

                    MenuGateClientView(
                        gate: activeInterfaceLayers.menuGate,
                        owner: layerContext.layer,
                        kind: .excerptDestinationMenu,
                        menuFrame: menuFrame,
                        anchorFrame: activeFontMenu.anchorFrame,
                        notePointer: { point in
                            handleFontMenuPointerMove(
                                at: point,
                                menuState: activeFontMenu
                            )
                        },
                        handleKey: { keyCode, isRepeat in
                            handleFontMenuKey(
                                keyCode,
                                isRepeat: isRepeat,
                                systemFontTitle: systemFontTitle
                            )
                        },
                        dismiss: { _ in
                            closeFontMenu()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    SettingsSubtitleFontMenuSurfaceHost(
                        menu: SettingsSubtitleFontMenu(
                            systemFontTitle: systemFontTitle,
                            availableFonts: availableFonts,
                            selectedFontName: style.fontName,
                            maximumHeight: activeFontMenu.maximumHeight,
                            itemStackWidth: activeFontMenu.itemStackWidth,
                            dividerHeight: activeFontMenu.dividerHeight,
                            highlight: fontHighlight,
                            scrollController: fontScrollController,
                            onSelect: { option in
                                selectFontOption(option)
                            }
                        )
                    )
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                    .zIndex(1000)
                }

                if let activeID = activeColorPopover,
                   let fieldFrame = anchorFrames[activeID.rawValue] {
                    SettingsSubtitleColorPresetsPopover(
                        selectedColor: colorBinding(for: activeID).wrappedValue,
                        fieldID: activeID,
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
            workbenchAccessibility?.onToggleSettingsSubtitleFontMenu = {
                toggleFontMenu()
            }
            if let coordPopover = workbenchAccessibility?.activeSubtitleColorPopover {
                activeColorPopover = coordPopover
            }
        }
        .onChange(of: activeColorPopover) { newValue in
            if workbenchAccessibility?.activeSubtitleColorPopover != newValue {
                workbenchAccessibility?.activeSubtitleColorPopover = newValue
            }
        }
        .onChange(of: style.borderType) { _ in
            if activeColorPopover == .outlineColor || activeColorPopover == .backgroundColor {
                activeColorPopover = nil
                workbenchAccessibility?.activeSubtitleColorPopover = nil
            }
        }
        .onDisappear {
            workbenchAccessibility?.onToggleSettingsSubtitleFontMenu = nil
            closeAllPopovers()
        }
    }

    private var activePopoverInteractiveRects: [CGRect] {
        var rects: [CGRect] = []
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
            openFontMenu()
        }
    }

    private func openFontMenu() {
        let startedAt = ProcessInfo.processInfo.systemUptime
        _ = workbenchAccessibility?.clearSettings(
            keepTextInputFocus: false,
            keepColorPopoverOpen: false
        )
        activeColorPopover = nil
        let measureStartedAt = ProcessInfo.processInfo.systemUptime
        if availableFonts.isEmpty {
            availableFonts = Self.loadSystemFonts()
        }
        let systemFontTitle = L("settings.subtitle.system_font")
        let metrics = SettingsSubtitleFontMenu.measureMetrics(
            systemFontTitle: systemFontTitle,
            availableFonts: availableFonts
        )
        let measureMs = max(0, (ProcessInfo.processInfo.systemUptime - measureStartedAt) * 1_000)
        DebugInteractionLatencyProbe.markMenuTriggerContext(
            menuID: "settings_subtitle_font_menu",
            trigger: "dropdown_button",
            startedAt: startedAt,
            measureMs: measureMs
        )
        let anchorFrame = viewportGeometry.anchorFrame(for: fontTriggerAnchor)
            ?? anchorFrames[Self.fontTriggerAnchorID]
            ?? CGRect(
                x: 0,
                y: 0,
                width: WorkbenchControlMetrics.redesignSettingsPopupWidth,
                height: WorkbenchControlMetrics.redesignFieldHeight
            )
        let container = viewportGeometry.visibleContainerRect(
            fallbackSize: CGSize(
                width: WorkbenchControlMetrics.redesignSettingsWindowWidth
                    - WorkbenchControlMetrics.redesignSettingsSidebarWidth,
                height: WorkbenchControlMetrics.redesignSettingsWindowHeight
                    - WorkbenchControlMetrics.redesignSettingsTitlebarHeight
            )
        )
        let naturalSize = SettingsSubtitleFontMenu.panelSize(
            availableFontCount: availableFonts.count,
            itemStackWidth: metrics.itemStackWidth,
            dividerHeight: metrics.dividerHeight,
            maximumHeight: MenuMetrics.maximumHeight
        )
        let place = { (menuSize: CGSize) -> CGRect in
            let anchorForPlacement = CGRect(
                x: anchorFrame.maxX - menuSize.width,
                y: anchorFrame.minY,
                width: menuSize.width,
                height: anchorFrame.height
            )
            return MenuPlacement.openingFrame(
                anchor: anchorForPlacement,
                menuSize: menuSize,
                in: container,
                gap: WorkbenchControlMetrics.redesignSpacing1,
                shrinksToFit: true
            )
        }
        var maximumHeight = MenuMetrics.maximumHeight
        var menuSize = naturalSize
        var openingFrame = place(naturalSize)
        if openingFrame.height < naturalSize.height {
            maximumHeight = openingFrame.height
            menuSize = SettingsSubtitleFontMenu.panelSize(
                availableFontCount: availableFonts.count,
                itemStackWidth: metrics.itemStackWidth,
                dividerHeight: metrics.dividerHeight,
                maximumHeight: maximumHeight
            )
            openingFrame = place(menuSize)
        }
        fontHighlight.open(
            selectablePositions: Array(0...availableFonts.count)
        )
        activeFontMenu = SettingsSubtitleFontMenuState(
            anchorFrame: anchorFrame,
            menuFrame: openingFrame,
            maximumHeight: maximumHeight,
            itemStackWidth: metrics.itemStackWidth,
            dividerHeight: metrics.dividerHeight
        )
    }

    private func closeFontMenu() {
        guard activeFontMenu != nil else { return }
        activeFontMenu = nil
        fontHighlight.close()
    }

    private func selectFontOption(_ option: SettingsSubtitleFontOption) {
        DebugInteractionLatencyProbe.measureMenuItemAction(
            menuID: "settings_subtitle_font_menu",
            item: option.title
        ) {
            settingsStore.srtSubtitleStyle.fontName = Self.resolvedFontName(for: option)
            closeFontMenu()
        }
    }

    private func handleFontMenuPointerMove(
        at point: CGPoint,
        menuState: SettingsSubtitleFontMenuState
    ) {
        guard menuState.menuFrame.contains(point) else {
            fontHighlight.updatePointerHover(position: nil)
            return
        }
        let localPoint = CGPoint(
            x: point.x - menuState.menuFrame.minX,
            y: point.y - menuState.menuFrame.minY
        )
        let position = SettingsSubtitleFontMenu.position(
            atLocalPoint: localPoint,
            menuSize: menuState.menuFrame.size,
            scrollOffsetY: fontScrollController.currentOffsetY,
            availableFontCount: availableFonts.count,
            itemStackWidth: menuState.itemStackWidth,
            dividerHeight: menuState.dividerHeight
        )
        fontHighlight.updatePointerHover(position: position)
    }

    private func handleFontMenuKey(
        _ keyCode: UInt16,
        isRepeat: Bool,
        systemFontTitle: String
    ) -> Bool {
        fontHighlight.handleStandardMenuKey(
            keyCode: keyCode,
            onActivate: {
                guard !isRepeat,
                      let position = fontHighlight.activeTriggerPosition,
                      let option = Self.option(
                          at: position,
                          availableFonts: availableFonts,
                          systemFontTitle: systemFontTitle
                      )
                else {
                    return
                }
                selectFontOption(option)
            },
            onDismiss: {
                if !isRepeat {
                    closeFontMenu()
                }
            }
        )
    }

    private func closeAllPopovers() {
        closeFontMenu()
        if activeColorPopover != nil {
            activeColorPopover = nil
            workbenchAccessibility?.activeSubtitleColorPopover = nil
            CueSeekerWindow.activeKeyWindow?.makeFirstResponder(nil)
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
        unit: String? = nil,
        fieldID: SettingsNumberFieldID
    ) -> some View {
        SettingsSubtitleNumberField(
            value: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
            ),
            minimum: minimum,
            maximum: maximum,
            unit: unit,
            settingsInputKind: .numberField(fieldID)
        )
    }

    private func opacityField(
        _ colorKeyPath: WritableKeyPath<SRTSubtitleStyle, SRTSubtitleStyle.Color>,
        fieldID: SettingsNumberFieldID
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
            unit: "%",
            settingsInputKind: .numberField(fieldID)
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
                        let startedAt = ProcessInfo.processInfo.systemUptime
                        closeFontMenu()
                        activeColorPopover = id
                        if workbenchAccessibility?.activeSubtitleColorPopover != id {
                            workbenchAccessibility?.activeSubtitleColorPopover = id
                        }
                        DebugInteractionLatencyProbe.recordPopoverOpen(
                            menuID: "settings_subtitle_color_popover_\(id.rawValue)",
                            owner: "settingsWindow",
                            trigger: "color_swatch",
                            startedAt: startedAt
                        )
                    } else if activeColorPopover == id {
                        activeColorPopover = nil
                        if workbenchAccessibility?.activeSubtitleColorPopover == id {
                            workbenchAccessibility?.activeSubtitleColorPopover = nil
                        }
                    }
                }
            ),
            fieldID: id
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
        DebugInteractionLatencyProbe.measureMenuItemAction(
            menuID: "settings_subtitle_color_popover_\(id.rawValue)",
            item: presetHex
        ) {
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
    }

    private func checkbox(
        _ title: String,
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, Bool>,
        isFocused: Bool = false
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
                .workbenchAccessibilityFocusRing(
                    isFocused: isFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignCheckboxSize / 2,
                    isCircular: true
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
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, Option>,
        focusedOption: Option? = nil
    ) -> some View {
        WorkbenchSegmentedControl(
            options: Array(Option.allCases),
            selection: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
            ),
            title: \.title,
            accessibilityLabel: \.title,
            focusedOption: focusedOption
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
        return Self.resolvedFamilyName(for: fontName) ?? fontName
    }

    @MainActor
    private static var cachedSystemFonts: [SettingsSubtitleFontOption]?

    @MainActor
    static func loadSystemFonts() -> [SettingsSubtitleFontOption] {
        if let cached = cachedSystemFonts {
            return cached
        }
        let families = NSFontManager.shared.availableFontFamilies
            .filter { !$0.hasPrefix(".") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let options = families.map { family in
            SettingsSubtitleFontOption(
                id: family,
                title: family,
                fontName: family
            )
        }
        cachedSystemFonts = options
        return options
    }

    static func resolvedFamilyName(for selectedFontName: String?) -> String? {
        guard let selectedFontName, !selectedFontName.isEmpty else {
            return nil
        }
        if let nsFont = NSFont(name: selectedFontName, size: 12) {
            return nsFont.familyName ?? nsFont.displayName ?? selectedFontName
        }
        return selectedFontName
    }

    static func resolvedFontName(for option: SettingsSubtitleFontOption) -> String? {
        guard let rawName = option.fontName, !rawName.isEmpty else {
            return nil
        }
        return NSFontManager.shared
            .font(withFamily: option.title, traits: [], weight: 5, size: 12)?
            .fontName
            ?? NSFont(name: rawName, size: 12)?.fontName
            ?? rawName
    }

    static func menuOptions(
        availableFonts: [SettingsSubtitleFontOption],
        systemFontTitle: String
    ) -> [SettingsSubtitleFontOption] {
        [SettingsSubtitleFontOption.systemFont(title: systemFontTitle)] + availableFonts
    }

    static func option(
        at position: Int,
        availableFonts: [SettingsSubtitleFontOption],
        systemFontTitle: String
    ) -> SettingsSubtitleFontOption? {
        if position == 0 {
            return .systemFont(title: systemFontTitle)
        }
        let fontIndex = position - 1
        guard availableFonts.indices.contains(fontIndex) else {
            return nil
        }
        return availableFonts[fontIndex]
    }
}

private struct SettingsSubtitleFontMenuState: Identifiable {
    let id = UUID()
    let anchorFrame: CGRect
    let menuFrame: CGRect
    let maximumHeight: CGFloat
    let itemStackWidth: CGFloat
    let dividerHeight: CGFloat
}

@MainActor
final class SettingsSubtitleViewportGeometry {
    weak var probe: SettingsSubtitleViewportProbe.ProbeView?

    func anchorFrame(for handle: MenuAnchorHandle) -> CGRect? {
        guard let probe, let windowFrame = handle.windowFrame, probe.window != nil else {
            return nil
        }
        return probe.convert(windowFrame, from: nil)
    }

    func visibleContainerRect(fallbackSize: CGSize) -> CGRect {
        guard let probe else {
            return CGRect(origin: .zero, size: fallbackSize)
        }
        if let scrollView = probe.enclosingScrollView {
            let clipView = scrollView.contentView
            let converted = probe.convert(clipView.bounds, from: clipView)
            if !converted.isEmpty {
                return converted
            }
        }
        if let contentView = probe.window?.contentView {
            let converted = probe.convert(contentView.bounds, from: contentView)
            if !converted.isEmpty {
                return converted
            }
        }
        let visible = probe.visibleRect
        if !visible.isEmpty {
            return visible
        }
        if !probe.bounds.isEmpty {
            return probe.bounds
        }
        return CGRect(origin: .zero, size: fallbackSize)
    }
}

struct SettingsSubtitleViewportProbe: NSViewRepresentable {
    let geometry: SettingsSubtitleViewportGeometry

    func makeNSView(context _: Context) -> ProbeView {
        let view = ProbeView()
        geometry.probe = view
        return view
    }

    func updateNSView(_ nsView: ProbeView, context _: Context) {
        geometry.probe = nsView
    }

    final class ProbeView: NSView {
        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private struct SettingsSubtitleFontMenuSurfaceHost: NSViewRepresentable {
    let menu: SettingsSubtitleFontMenu

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
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
    static let systemFontID = "__system_font__"

    let id: String
    let title: String
    let fontName: String?

    static func systemFont(title: String) -> SettingsSubtitleFontOption {
        SettingsSubtitleFontOption(
            id: systemFontID,
            title: title,
            fontName: nil
        )
    }

    func matches(
        selectedFontName: String?,
        resolvedFamilyName: String? = nil
    ) -> Bool {
        guard let selectedFontName, !selectedFontName.isEmpty else {
            return fontName == nil
        }
        if fontName == selectedFontName || title == selectedFontName {
            return true
        }
        if let resolvedFamilyName {
            return title == resolvedFamilyName || fontName == resolvedFamilyName
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
    var isFocused: Bool = false
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
                    (isPressed || isOpen || isHovered)
                        ? WorkbenchRedesignColors.borderControlHover
                        : WorkbenchRedesignColors.borderControl,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .focusable(false)
        .workbenchAccessibilityFocusRing(
            isFocused: isFocused,
            cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
        )
        .onPointerHover { isHovered = $0 }
    }
}

struct SettingsSubtitleFontMenu: View {
    struct Metrics: Equatable {
        let itemStackWidth: CGFloat
        let dividerHeight: CGFloat
    }

    private static let rowHeight = WorkbenchControlMetrics.redesignMenuItemHeight
    private static let defaultDividerHeight = 1 + WorkbenchControlMetrics.redesignMenuDividerGap * 2
    private static let overscanRows = 8
    private static let quantizeStep = 4

    let systemFontTitle: String
    let availableFonts: [SettingsSubtitleFontOption]
    let selectedFontName: String?
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    var itemStackWidth: CGFloat? = nil
    var dividerHeight: CGFloat = Self.defaultDividerHeight
    @ObservedObject var highlight: MenuHighlightModel
    var scrollController: WorkbenchScrollViewController? = nil
    let onSelect: (SettingsSubtitleFontOption) -> Void

    @State private var fallbackScrollController = WorkbenchScrollViewController()
    @State private var quantizedWindowStart: Int = 0
    @State private var viewportHeight: CGFloat = MenuMetrics.maximumHeight

    private var activeScrollController: WorkbenchScrollViewController {
        scrollController ?? fallbackScrollController
    }

    private var resolvedDividerHeight: CGFloat {
        availableFonts.isEmpty ? 0 : dividerHeight
    }

    private var fontsStartY: CGFloat {
        MenuMetrics.padding + Self.rowHeight + resolvedDividerHeight
    }

    private var totalContentHeight: CGFloat {
        Self.rowHeight
            + resolvedDividerHeight
            + CGFloat(availableFonts.count) * Self.rowHeight
            + MenuMetrics.padding * 2
    }

    var body: some View {
        let resolvedWidth = itemStackWidth
            ?? Self.measureMetrics(
                systemFontTitle: systemFontTitle,
                availableFonts: availableFonts
            ).itemStackWidth
        let resolvedFamilyName = SettingsSubtitleCategory.resolvedFamilyName(
            for: selectedFontName
        )
        let systemOption = SettingsSubtitleFontOption.systemFont(
            title: systemFontTitle
        )
        let sliceRange = visibleFontSliceRange()
        let topSpacerHeight = CGFloat(sliceRange.lowerBound) * Self.rowHeight
        let bottomSpacerHeight = CGFloat(
            max(0, availableFonts.count - sliceRange.upperBound)
        ) * Self.rowHeight
        let cornerRadius = WorkbenchControlMetrics.redesignMenuRadius

        MenuHeightCap(height: maximumHeight) {
            WorkbenchScrollView(
                scrollbarInset: MenuMetrics.scrollbarOuterGap,
                controller: activeScrollController
            ) {
                MenuItemStack(
                    padding: MenuMetrics.padding,
                    strip: MenuMetrics.scrollbarStrip,
                    cap: maximumHeight
                ) {
                    VStack(alignment: .leading, spacing: 0) {
                        WorkbenchPopoverRow(
                            title: systemOption.title,
                            isSelected: systemOption.matches(
                                selectedFontName: selectedFontName,
                                resolvedFamilyName: resolvedFamilyName
                            ),
                            isHighlighted: highlight.isSelected(0),
                            isRowHovered: highlight.isHovered(0),
                            isAccessibilityFocused: highlight.isAccessibilityFocused(0),
                            showsCheckmarkSlot: true,
                            action: {
                                onSelect(systemOption)
                            },
                            onHoverChange: { isHovered in
                                highlight.noteHover(isHovered, at: 0)
                            }
                        )
                        .id(0)

                        if !availableFonts.isEmpty {
                            WorkbenchMenuDivider()

                            if topSpacerHeight > 0 {
                                Color.clear
                                    .frame(height: topSpacerHeight)
                                    .allowsHitTesting(false)
                            }

                            ForEach(sliceRange, id: \.self) { fontIndex in
                                let option = availableFonts[fontIndex]
                                let position = fontIndex + 1
                                WorkbenchPopoverRow(
                                    title: option.title,
                                    isSelected: option.matches(
                                        selectedFontName: selectedFontName,
                                        resolvedFamilyName: resolvedFamilyName
                                    ),
                                    isHighlighted: highlight.isSelected(position),
                                    isRowHovered: highlight.isHovered(position),
                                    isAccessibilityFocused: highlight.isAccessibilityFocused(position),
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

                            if bottomSpacerHeight > 0 {
                                Color.clear
                                    .frame(height: bottomSpacerHeight)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .frame(width: resolvedWidth, alignment: .leading)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgPopover)
            .shadowToken(
                WorkbenchRedesignColors.shadowPopover,
                cornerRadius: cornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderControl,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
        .subtitleTableTextSelectionNonInteractiveRegion(
            cornerRadius: cornerRadius
        )
        .onAppear {
            bindScrollController()
            revealHighlightedPosition()
        }
        .onChange(of: highlight.keyboardMoveCount) { _ in
            revealHighlightedPosition()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .cueSeekerScrollDebounceSettled)
        ) { _ in
            syncHoverAfterScrollSettled(itemStackWidth: resolvedWidth)
        }
    }

    var mountedFontRangeForTesting: Range<Int> {
        visibleFontSliceRange()
    }

    private func visibleFontSliceRange() -> Range<Int> {
        guard !availableFonts.isEmpty else {
            return 0..<0
        }
        let effectiveViewport = max(viewportHeight, maximumHeight)
        let visibleCount = max(1, Int(ceil(effectiveViewport / Self.rowHeight)))
        let start = min(max(0, quantizedWindowStart), availableFonts.count)
        let span = visibleCount + Self.overscanRows * 2 + Self.quantizeStep
        let end = min(availableFonts.count, start + span)
        return start..<end
    }

    private func bindScrollController() {
        let controller = activeScrollController
        let startY = fontsStartY
        let maxCap = maximumHeight
        controller.onVerticalScrollChange = { offsetY, currentViewportHeight in
            let effectiveViewport = currentViewportHeight > 0 ? currentViewportHeight : maxCap
            let rawFirstVisible = max(0, Int(floor((offsetY - startY) / Self.rowHeight)))
            let nextQuantized = max(
                0,
                (rawFirstVisible / Self.quantizeStep) * Self.quantizeStep - Self.overscanRows
            )
            if nextQuantized != quantizedWindowStart {
                quantizedWindowStart = nextQuantized
            }
            if abs(effectiveViewport - viewportHeight) > 0.5 {
                viewportHeight = effectiveViewport
            }
        }
    }

    private func revealHighlightedPosition() {
        guard totalContentHeight > floor(maximumHeight),
              let position = highlight.revealPosition
        else {
            return
        }
        let minY: CGFloat
        let maxY: CGFloat
        if position <= 0 {
            minY = 0
            maxY = MenuMetrics.padding + Self.rowHeight
            if quantizedWindowStart != 0 {
                quantizedWindowStart = 0
            }
        } else {
            let fontIndex = min(max(0, position - 1), max(0, availableFonts.count - 1))
            let rowMinY = fontsStartY + CGFloat(fontIndex) * Self.rowHeight
            let rowMaxY = rowMinY + Self.rowHeight
            minY = rowMinY
            maxY = position == availableFonts.count ? totalContentHeight : rowMaxY
            let currentRange = visibleFontSliceRange()
            if !currentRange.contains(fontIndex) {
                quantizedWindowStart = max(
                    0,
                    (fontIndex / Self.quantizeStep) * Self.quantizeStep - Self.overscanRows
                )
            }
        }
        activeScrollController.revealVerticalRange(minY: minY, maxY: maxY)
    }

    private func syncHoverAfterScrollSettled(itemStackWidth: CGFloat) {
        switch activeScrollController.queryPointerInDocument() {
        case .windowNotFocused:
            break
        case .outsideViewport:
            highlight.syncHoverAfterScrollSettled(positionUnderPointer: nil)
        case .inside(let docPoint):
            let pos = Self.positionInDocument(
                at: docPoint,
                availableFontCount: availableFonts.count,
                itemStackWidth: itemStackWidth,
                dividerHeight: dividerHeight
            )
            highlight.syncHoverAfterScrollSettled(positionUnderPointer: pos)
        }
    }

    static func position(
        atLocalPoint localPoint: CGPoint,
        menuSize: CGSize,
        scrollOffsetY: CGFloat,
        availableFontCount: Int,
        itemStackWidth: CGFloat,
        dividerHeight: CGFloat = defaultDividerHeight
    ) -> Int? {
        guard localPoint.x >= 0,
              localPoint.x <= menuSize.width,
              localPoint.y >= 0,
              localPoint.y <= menuSize.height
        else {
            return nil
        }
        let docPoint = CGPoint(
            x: localPoint.x,
            y: localPoint.y + scrollOffsetY
        )
        return positionInDocument(
            at: docPoint,
            availableFontCount: availableFontCount,
            itemStackWidth: itemStackWidth,
            dividerHeight: dividerHeight
        )
    }

    static func positionInDocument(
        at docPoint: CGPoint,
        availableFontCount: Int,
        itemStackWidth: CGFloat,
        dividerHeight: CGFloat = defaultDividerHeight
    ) -> Int? {
        let minX = MenuMetrics.padding
        let maxX = MenuMetrics.padding + itemStackWidth
        guard docPoint.x >= minX, docPoint.x <= maxX else {
            return nil
        }
        let systemMinY = MenuMetrics.padding
        let systemMaxY = systemMinY + rowHeight
        if docPoint.y >= systemMinY && docPoint.y < systemMaxY {
            return 0
        }
        guard availableFontCount > 0 else {
            return nil
        }
        let fontsStartY = systemMaxY + dividerHeight
        guard docPoint.y >= fontsStartY else {
            return nil
        }
        let fontIndex = Int(floor((docPoint.y - fontsStartY) / rowHeight))
        guard fontIndex >= 0 && fontIndex < availableFontCount else {
            return nil
        }
        return fontIndex + 1
    }

    @MainActor
    private static var cachedMetricsKey: String?
    @MainActor
    private static var cachedMetrics: Metrics?

    @MainActor
    static func measureMetrics(
        systemFontTitle: String,
        availableFonts: [SettingsSubtitleFontOption]
    ) -> Metrics {
        let key = "\(systemFontTitle)|\(availableFonts.count)|\(availableFonts.first?.id ?? "")|\(availableFonts.last?.id ?? "")"
        if cachedMetricsKey == key, let cached = cachedMetrics {
            return cached
        }
        let font = NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeTable,
            weight: .regular
        )
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var candidateTitles: [String] = [systemFontTitle]
        let topFontTitles = availableFonts
            .map { option in
                (
                    title: option.title,
                    width: (option.title as NSString).size(withAttributes: attributes).width
                )
            }
            .sorted { $0.width > $1.width }
            .prefix(3)
            .map(\.title)
        candidateTitles.append(contentsOf: topFontTitles)

        let rowHost = NSHostingView(
            rootView: VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(candidateTitles.enumerated()), id: \.offset) { _, title in
                    WorkbenchPopoverRow(
                        title: title,
                        showsCheckmarkSlot: true
                    )
                }
            }
            .fixedSize()
        )
        rowHost.layoutSubtreeIfNeeded()
        let itemStackWidth = ceil(rowHost.fittingSize.width)

        let dividerHost = NSHostingView(
            rootView: WorkbenchMenuDivider()
                .frame(width: max(1, itemStackWidth))
                .fixedSize(horizontal: false, vertical: true)
        )
        dividerHost.layoutSubtreeIfNeeded()
        let dividerHeight = max(1, ceil(dividerHost.fittingSize.height))

        let metrics = Metrics(
            itemStackWidth: itemStackWidth,
            dividerHeight: dividerHeight
        )
        cachedMetricsKey = key
        cachedMetrics = metrics
        return metrics
    }

    static func panelSize(
        availableFontCount: Int,
        itemStackWidth: CGFloat,
        dividerHeight: CGFloat = defaultDividerHeight,
        maximumHeight: CGFloat = MenuMetrics.maximumHeight
    ) -> CGSize {
        let resolvedDivider = availableFontCount > 0 ? dividerHeight : 0
        let contentHeight = ceil(
            rowHeight
                + resolvedDivider
                + CGFloat(availableFontCount) * rowHeight
        )
        let unclippedHeight = contentHeight + MenuMetrics.padding * 2
        let reservesStrip = unclippedHeight > floor(maximumHeight)
        let width = ceil(itemStackWidth)
            + MenuMetrics.padding * 2
            + (reservesStrip ? MenuMetrics.scrollbarStrip : 0)
        let height = max(0, min(unclippedHeight, floor(maximumHeight)))
        return CGSize(width: width, height: height)
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
    var fieldID: SettingsSubtitleCategory.ColorFieldID = .textColor

    @State private var draft = ""
    @State private var lastCommittedHex = "FFFFFF"
    @FocusState private var isFocused: Bool
    @State private var isNativeFocused = false
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            let isAccessibilityFocused = accessibility?.isSettingsFocused(.subtitleColorField(fieldID)) == true
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
                            workbenchAccessibility?.setSettingsTextInputActive(
                                .subtitleColorField(fieldID),
                                isActive: focused
                            )
                            if focused {
                                isPopoverOpen = true
                            } else if workbenchAccessibility?.focusedSettingsTarget?.colorWellID != fieldID {
                                isPopoverOpen = false
                            }
                        },
                        onBindTextField: { field in
                            let inputKind = SettingsTextInputKind.subtitleColorField(fieldID)
                            workbenchAccessibility?.registerSettingsTextInput(
                                inputKind,
                                ownerToken: ObjectIdentifier(field),
                                setFocused: { [weak field] focused in
                                    if focused {
                                        field?.focusFromAccessibility()
                                    } else {
                                        field?.unfocusFromAccessibility()
                                    }
                                    if field?.window == nil {
                                        isNativeFocused = focused
                                        isFocused = focused
                                        if focused {
                                            isPopoverOpen = true
                                        } else if workbenchAccessibility?.focusedSettingsTarget?.colorWellID != fieldID {
                                            isPopoverOpen = false
                                        }
                                    }
                                },
                                isCurrentlyFocused: { [weak field] in
                                    field?.isCurrentlyFocused == true
                                }
                            )
                        },
                        onEditingEnded: commitDraft,
                        onSubmit: nil,
                        onCancel: {
                            if let workbenchAccessibility, workbenchAccessibility.isSettingsActive {
                                _ = workbenchAccessibility.clearSettings(
                                    keepTextInputFocus: true,
                                    keepColorPopoverOpen: true
                                )
                                return true
                            }
                            isPopoverOpen = false
                            workbenchAccessibility?.activeSubtitleColorPopover = nil
                            isFocused = false
                            CueSeekerWindow.activeKeyWindow?.makeFirstResponder(nil)
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
                    (isNativeFocused || isPopoverOpen)
                        ? WorkbenchRedesignColors.borderFocus
                        : WorkbenchRedesignColors.borderControl,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
            .workbenchAccessibilityFocusRing(
                isFocused: isAccessibilityFocused,
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
            )
            .overlay(
                WorkbenchSingleLineContainerOverlay(
                    isEnabled: true,
                    onPressRelease: {
                        isPopoverOpen = true
                    }
                )
            )
        }
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
    var fieldID: SettingsSubtitleCategory.ColorFieldID = .textColor
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

        WorkbenchAccessibilityReader { accessibility in
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
                                .workbenchAccessibilityFocusRing(
                                    isFocused: accessibility?.isSettingsFocused(.subtitleColorPreset(fieldID, index)) == true,
                                    cornerRadius: WorkbenchControlMetrics.redesignSettingsColorSwatchRadius
                                )
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
            .background(FocusedTextInputCompanionSurface())
        }
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
    var settingsInputKind: SettingsTextInputKind? = nil

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
            onSubmit: nil,
            settingsInputKind: settingsInputKind
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
        WorkbenchNumberField.filterIntegerDraft(draft)
    }

    static func normalizeDraft(_ draft: String, maximum: Double) -> String {
        WorkbenchNumberField.normalizeIntegerDraft(
            draft,
            maximum: Int(maximum.rounded())
        )
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
