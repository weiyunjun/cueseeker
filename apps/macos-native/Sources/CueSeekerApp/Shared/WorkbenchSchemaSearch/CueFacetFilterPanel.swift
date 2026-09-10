import SwiftUI
import CueSeekerCore

struct CueFacetOption: Identifiable {
    let id: String
    let title: String
    let count: Int
    let isSelected: Bool
    let toggle: () -> Void
}

/// What the filter menu shows, flattened into render order: the title, then
/// each facet group as a divider, a header and its option rows. The flat
/// positions are what the keyboard highlight indexes, and only option rows
/// appear among the selectable ones.
enum CueFacetFilterMenuElement {
    case title(String)
    case divider
    case sectionHeader(title: String, icon: AppIcon)
    case option(CueFacetOption)
}

struct CueFacetFilterMenuModel {
    let elements: [CueFacetFilterMenuElement]
    let selectablePositions: [Int]
    let isCalculating: Bool
    /// Changes whenever something that affects the menu's measured size
    /// changes — texts, counts, the calculating placeholder — so the menu is
    /// re-measured outside of view updates exactly when it needs to be.
    let contentHash: Int

    init(
        distribution: CueFacetDistribution?,
        availableLanguages: [SubtitleLanguageCode],
        isCalculating: Bool,
        filter: Binding<CueFacetFilter>
    ) {
        var elements: [CueFacetFilterMenuElement] = [.title(L("table.filter"))]
        Self.appendSection(
            to: &elements,
            title: L("facet.duration"),
            icon: .clock,
            options: CueDurationFacet.allCases.map { facet in
                CueFacetOption(
                    id: facet.rawValue,
                    title: facet.title,
                    count: distribution?.durationCounts[facet] ?? 0,
                    isSelected: filter.wrappedValue.durations.contains(facet),
                    toggle: { Self.toggle(facet, at: \.durations, in: filter) }
                )
            }
        )
        Self.appendSection(
            to: &elements,
            title: L("facet.character"),
            icon: .textAa,
            options: CueCharacterFacet.allCases.map { facet in
                CueFacetOption(
                    id: facet.rawValue,
                    title: facet.title,
                    count: distribution?.characterCounts[facet] ?? 0,
                    isSelected: filter.wrappedValue.characters.contains(facet),
                    toggle: { Self.toggle(facet, at: \.characters, in: filter) }
                )
            }
        )
        Self.appendSection(
            to: &elements,
            title: L("facet.language"),
            icon: .globe,
            options: availableLanguages.map { language in
                CueFacetOption(
                    id: language.rawValue,
                    title: language.title,
                    count: distribution?.languageCounts[language] ?? 0,
                    isSelected: filter.wrappedValue.languages.contains(language),
                    toggle: { Self.toggle(language, at: \.languages, in: filter) }
                )
            }
        )
        Self.appendSection(
            to: &elements,
            title: L("facet.watch_status"),
            icon: .eye,
            options: LibraryWatchState.facetCases.map { state in
                CueFacetOption(
                    id: state.rawValue,
                    title: state.title,
                    count: distribution?.watchStateCounts[state] ?? 0,
                    isSelected: filter.wrappedValue.watchStates.contains(state),
                    toggle: { Self.toggle(state, at: \.watchStates, in: filter) }
                )
            }
        )
        self.elements = elements
        self.selectablePositions = elements.indices.filter {
            if case .option = elements[$0] {
                return true
            }
            return false
        }
        self.isCalculating = isCalculating
        var hasher = Hasher()
        hasher.combine(isCalculating)
        for element in elements {
            switch element {
            case .title(let title):
                hasher.combine(title)
            case .divider:
                hasher.combine(0)
            case .sectionHeader(let title, let icon):
                hasher.combine(title)
                hasher.combine(icon)
            case .option(let option):
                hasher.combine(option.title)
                hasher.combine(option.count)
            }
        }
        self.contentHash = hasher.finalize()
    }

    func option(at position: Int) -> CueFacetOption? {
        guard elements.indices.contains(position),
              case .option(let option) = elements[position]
        else {
            return nil
        }
        return option
    }

    private static func appendSection(
        to elements: inout [CueFacetFilterMenuElement],
        title: String,
        icon: AppIcon,
        options: [CueFacetOption]
    ) {
        elements.append(.divider)
        elements.append(.sectionHeader(title: title, icon: icon))
        elements.append(contentsOf: options.map { .option($0) })
    }

    private static func toggle<Value: Hashable>(
        _ value: Value,
        at keyPath: WritableKeyPath<CueFacetFilter, Set<Value>>,
        in filter: Binding<CueFacetFilter>
    ) {
        var nextFilter = filter.wrappedValue
        var selection = nextFilter[keyPath: keyPath]
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
        nextFilter[keyPath: keyPath] = selection
        filter.wrappedValue = nextFilter
    }
}

/// The filter menu surface. Checking an option applies it right away and the
/// menu stays open; the counts and the calculating placeholder keep updating
/// in place. Taller content than the menu cap scrolls inside the panel.
struct CueFacetFilterMenu: View {
    let model: CueFacetFilterMenuModel
    @ObservedObject var highlight: MenuHighlightModel
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight

    var body: some View {
        WorkbenchPopoverPanel(
            isRedesign: true,
            maximumHeight: maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.elements.indices, id: \.self) { position in
                    elementView(model.elements[position], at: position)
                        .id(position)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func elementView(
        _ element: CueFacetFilterMenuElement,
        at position: Int
    ) -> some View {
        switch element {
        case .title(let title):
            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .fixedSize(horizontal: true, vertical: false)
                .padding(
                    .horizontal,
                    WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
                )
                .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)

        case .divider:
            WorkbenchMenuDivider()

        case .sectionHeader(let title, let icon):
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                AppIconImage(icon, size: WorkbenchControlMetrics.redesignCheckboxSize)
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                    .frame(
                        width: WorkbenchControlMetrics.redesignCheckboxSize,
                        height: WorkbenchControlMetrics.redesignCheckboxSize
                    )

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .medium
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
            )
            .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)

        case .option(let option):
            optionRow(option, at: position)
        }
    }

    private func optionRow(
        _ option: CueFacetOption,
        at position: Int
    ) -> some View {
        Button {
            guard !model.isCalculating else { return }
            option.toggle()
        } label: {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                WorkbenchCheckboxGlyph(
                    state: option.isSelected ? .checked : .unchecked,
                    isEnabled: true,
                    size: WorkbenchControlMetrics.redesignCheckboxSize
                )

                Text(option.title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: WorkbenchControlMetrics.redesignSpacing2)

                Text(
                    model.isCalculating
                        ? L("facet.calculating")
                        : String(option.count)
                )
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .lineLimit(1)
            }
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignMenuItemHorizontalPadding
            )
            .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                    style: .continuous
                )
                .fill(
                    highlight.highlightedPosition == position
                        ? WorkbenchRedesignColors.bgHover
                        : Color.clear
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .id(position)
        // Menu rows read the pointer directly: the layer freeze applies to
        // everything under the menu, not to the menu itself, and the highlight
        // model decides whether the hover may move the highlight.
        .onHover { isHovered in
            highlight.noteHover(isHovered, at: position)
        }
        .accessibilityLabel(option.title)
        .accessibilityValue(
            model.isCalculating
                ? L("facet.calculating")
                : "\(option.count), \(option.isSelected ? L("facet.selected") : L("facet.not_selected"))"
        )
    }
}

private extension CueDurationFacet {
    var title: String {
        switch self {
        case .underOneSecond:
            return L("facet.duration.under_1s")
        case .oneToUnderThreeSeconds:
            return L("facet.duration.1_to_3s")
        case .threeToUnderFiveSeconds:
            return L("facet.duration.3_to_5s")
        case .fiveSecondsOrMore:
            return L("facet.duration.5s_and_up")
        }
    }
}

private extension CueCharacterFacet {
    var title: String {
        switch self {
        case .oneToTen:
            return "1–10"
        case .elevenToTwenty:
            return "11–20"
        case .twentyOneToThirty:
            return "21–30"
        case .thirtyOneOrMore:
            return "31+"
        }
    }
}

private extension SubtitleLanguageCode {
    var title: String {
        switch self {
        case .english:
            return L("facet.language.english")
        case .japanese:
            return L("facet.language.japanese")
        case .chinese:
            return L("facet.language.chinese")
        case .simplifiedChinese:
            return L("facet.language.simplified_chinese")
        case .traditionalChinese:
            return L("facet.language.traditional_chinese")
        case .unknown:
            return L("facet.language.unknown")
        }
    }
}

private extension LibraryWatchState {
    static let facetCases: [LibraryWatchState] = [
        .finished,
        .watching,
        .unwatched,
    ]

    var title: String {
        switch self {
        case .finished:
            return L("facet.watch_status.finished")
        case .watching:
            return L("facet.watch_status.watching")
        case .unwatched:
            return L("facet.watch_status.unwatched")
        }
    }
}
