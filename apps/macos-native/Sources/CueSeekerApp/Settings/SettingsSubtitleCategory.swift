import AppKit
import CueSeekerPlayback
import SwiftUI

/// Settings / Subtitle: how SRT subtitles look and where they sit. See
/// `docs/human/requirements/20260913-Feature-SRT Subtitle Style And Position
/// Settings.md` and `docs/human/requirements/20260914-UI-Settings Categories
/// Merge And Grouped Card Layout.md`.
struct SettingsSubtitleCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var fontPanel = SettingsSubtitleFontPanel()

    var body: some View {
        let style = settingsStore.srtSubtitleStyle

        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
            SettingsGroup(title: L("settings.subtitle.section.text")) {
                row(L("settings.subtitle.font"), isFirst: true) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                        Text(fontTitle(style.fontName))
                            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                            .lineLimit(1)

                        WorkbenchButton(
                            title: L("settings.subtitle.choose_font"),
                            isRedesign: true
                        ) {
                            fontPanel.open(fontName: style.fontName) { fontName in
                                settingsStore.srtSubtitleStyle.fontName = fontName
                            }
                        }
                    }
                }
                row(L("settings.subtitle.size")) {
                    numberField(\.size, minimum: SRTSubtitleStyle.minimumSize)
                }
                row(L("settings.subtitle.style")) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing6) {
                        checkbox(L("settings.subtitle.bold"), \.isBold)
                        checkbox(L("settings.subtitle.italic"), \.isItalic)
                    }
                }
                row(L("settings.subtitle.color")) {
                    colorWell(\.textColor)
                }
                row(L("settings.subtitle.letter_spacing")) {
                    numberField(\.letterSpacing, minimum: 0)
                }
                row(L("settings.subtitle.line_spacing")) {
                    numberField(\.lineSpacing, minimum: 0)
                }
            }

            SettingsGroup(title: L("settings.subtitle.section.border")) {
                row(L("settings.subtitle.border_type"), isFirst: true) {
                    segmentedControl(\.borderType)
                }
                row(
                    L("settings.subtitle.outline_color"),
                    isEnabled: style.borderType != .opaqueBox
                ) {
                    colorWell(\.outlineColor)
                }
                row(
                    L("settings.subtitle.outline_width"),
                    isEnabled: style.borderType != .opaqueBox
                ) {
                    numberField(\.outlineWidth, minimum: 0)
                }
                row(
                    L("settings.subtitle.background_color"),
                    isEnabled: style.borderType != .outline
                ) {
                    colorWell(\.backgroundColor)
                }
                row(L("settings.subtitle.blur")) {
                    numberField(\.blur, minimum: 0)
                }
            }

            SettingsGroup(title: L("settings.subtitle.section.shadow")) {
                row(
                    L("settings.subtitle.shadow_color"),
                    isFirst: true,
                    isEnabled: style.borderType != .backgroundBox
                ) {
                    colorWell(\.shadowColor)
                }
                row(
                    L("settings.subtitle.shadow_offset"),
                    isEnabled: style.borderType != .backgroundBox
                ) {
                    numberField(\.shadowOffset, minimum: 0)
                }
            }

            SettingsGroup(title: L("settings.subtitle.section.position")) {
                row(L("settings.subtitle.horizontal"), isFirst: true) {
                    segmentedControl(\.horizontalAlignment)
                }
                row(L("settings.subtitle.margin_x")) {
                    numberField(\.marginX, minimum: 0)
                }
                row(L("settings.subtitle.vertical")) {
                    segmentedControl(\.verticalAlignment)
                }
                row(L("settings.subtitle.margin_y")) {
                    numberField(\.marginY, minimum: 0)
                }
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                WorkbenchButton(
                    title: L("settings.subtitle.restore_defaults"),
                    icon: .arrowCounterClockwise,
                    isRedesign: true
                ) {
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
        .onDisappear {
            fontPanel.close()
        }
    }

    /// A row, with the line above it unless it opens its card.
    @ViewBuilder
    private func row<Content: View>(
        _ title: String,
        isFirst: Bool = false,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if !isFirst {
            SettingsRowDivider()
        }

        SettingsRow(title) {
            content()
                .disabled(!isEnabled)
        }
    }

    private func numberField(
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, Double>,
        minimum: Double
    ) -> some View {
        SettingsSubtitleNumberField(
            value: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath] },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = $0 }
            ),
            minimum: minimum
        )
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

    private func colorWell(
        _ keyPath: WritableKeyPath<SRTSubtitleStyle, SRTSubtitleStyle.Color>
    ) -> some View {
        ColorPicker(
            "",
            selection: Binding(
                get: { settingsStore.srtSubtitleStyle[keyPath: keyPath].swiftUIColor },
                set: { settingsStore.srtSubtitleStyle[keyPath: keyPath] = SRTSubtitleStyle.Color($0) }
            ),
            supportsOpacity: true
        )
        .labelsHidden()
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
        guard let fontName else {
            return L("settings.subtitle.system_font")
        }
        return NSFont(name: fontName, size: NSFont.systemFontSize)?.displayName ?? fontName
    }
}

/// A number typed as text. A value in range applies as it is typed; leaving
/// the field or pressing Return brings one out of range to its bound.
struct SettingsSubtitleNumberField: View {
    @Binding var value: Double
    let minimum: Double

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
            unit: nil,
            focus: $isFocused,
            normalizeDraft: Self.filterDraft,
            onEditingEnded: commitDraft,
            onSubmit: commitDraft
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
        .onSubmit {
            commitDraft()
        }
        .onChange(of: value) { value in
            if !isFocused,
               Self.parseDouble(draft) != value {
                draft = Self.text(for: value)
            }
        }
    }

    static func filterDraft(_ draft: String) -> String {
        draft.filter { $0.isASCII && $0.isNumber }
    }

    private static func parseDouble(_ draft: String) -> Double? {
        guard !draft.isEmpty else { return nil }
        return Int(draft).map(Double.init) ?? Double(draft)
    }

    private func applyDraft(_ draft: String) {
        let allowed = Self.filterDraft(draft)
        guard allowed == draft else {
            self.draft = allowed
            return
        }
        guard let parsed = Self.parseDouble(allowed),
              parsed >= minimum
        else {
            return
        }
        value = parsed
    }

    private func commitDraft() {
        let allowed = Self.filterDraft(draft)
        guard let parsed = Self.parseDouble(allowed) else {
            draft = Self.text(for: value)
            return
        }
        if parsed < minimum {
            value = minimum
            draft = Self.text(for: minimum)
        } else {
            value = parsed
            let stripped = String(allowed.drop(while: { $0 == "0" }))
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

/// Opens the system font panel and reports each face chosen in it.
@MainActor
private final class SettingsSubtitleFontPanel: NSObject, ObservableObject {
    private var selectedFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    private var onChange: ((String) -> Void)?

    func open(fontName: String?, onChange: @escaping (String) -> Void) {
        self.onChange = onChange
        selectedFont = fontName.flatMap { NSFont(name: $0, size: NSFont.systemFontSize) }
            ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.setSelectedFont(selectedFont, isMultiple: false)
        fontManager.orderFrontFontPanel(nil)
    }

    func close() {
        if NSFontManager.shared.target === self {
            NSFontManager.shared.target = nil
        }
        onChange = nil
    }

    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else {
            return
        }
        let font = fontManager.convert(selectedFont)
        // The panel also sends a change for the size, which this page keeps in
        // its own field.
        guard font.fontName != selectedFont.fontName else {
            return
        }
        selectedFont = font
        onChange?(font.fontName)
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
        case .opaqueBox:
            L("settings.subtitle.border_type.opaque_box")
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
    init(_ color: SwiftUI.Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }

    var swiftUIColor: SwiftUI.Color {
        SwiftUI.Color(nsColor: NSColor(
            srgbRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        ))
    }
}
