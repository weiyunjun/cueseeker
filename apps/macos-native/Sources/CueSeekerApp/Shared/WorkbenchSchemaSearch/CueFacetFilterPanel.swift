import SwiftUI
import CueSeekerCore

struct CueFacetFilterPanel: View {
    let distribution: CueFacetDistribution?
    let availableLanguages: [SubtitleLanguageCode]
    let isCalculating: Bool
    @Binding var filter: CueFacetFilter

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = max(
                216,
                (geometry.size.width - 3 * WorkbenchControlMetrics.redesignSpacing3) / 4
            )
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    card(
                        title: "Duration",
                        systemImage: "clock",
                        options: CueDurationFacet.allCases.map { facet in
                            CueFacetOption(
                                id: facet.rawValue,
                                title: facet.title,
                                count: distribution?.durationCounts[facet] ?? 0,
                                isSelected: filter.durations.contains(facet),
                                toggle: { toggle(facet, at: \.durations) }
                            )
                        }
                    )
                    .frame(width: cardWidth)

                    card(
                        title: "Character",
                        systemImage: "textformat",
                        options: CueCharacterFacet.allCases.map { facet in
                            CueFacetOption(
                                id: facet.rawValue,
                                title: facet.title,
                                count: distribution?.characterCounts[facet] ?? 0,
                                isSelected: filter.characters.contains(facet),
                                toggle: { toggle(facet, at: \.characters) }
                            )
                        }
                    )
                    .frame(width: cardWidth)

                    card(
                        title: "Language",
                        systemImage: "globe",
                        options: availableLanguages.map { language in
                            CueFacetOption(
                                id: language.rawValue,
                                title: language.title,
                                count: distribution?.languageCounts[language] ?? 0,
                                isSelected: filter.languages.contains(language),
                                toggle: { toggle(language, at: \.languages) }
                            )
                        }
                    )
                    .frame(width: cardWidth)

                    card(
                        title: "Watch Status",
                        systemImage: "eye",
                        options: LibraryWatchState.facetCases.map { state in
                            CueFacetOption(
                                id: state.rawValue,
                                title: state.title,
                                count: distribution?.watchStateCounts[state] ?? 0,
                                isSelected: filter.watchStates.contains(state),
                                toggle: { toggle(state, at: \.watchStates) }
                            )
                        }
                    )
                    .frame(width: cardWidth)
                }
                .frame(minWidth: geometry.size.width, alignment: .leading)
            }
        }
        .frame(height: 224)
    }

    private func card(
        title: String,
        systemImage: String,
        options: [CueFacetOption]
    ) -> some View {
        CueFacetCard(
            title: title,
            systemImage: systemImage,
            options: options,
            isCalculating: isCalculating
        )
    }

    private func toggle<Value: Hashable>(
        _ value: Value,
        at keyPath: WritableKeyPath<CueFacetFilter, Set<Value>>
    ) {
        var nextFilter = filter
        var selection = nextFilter[keyPath: keyPath]
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
        nextFilter[keyPath: keyPath] = selection
        filter = nextFilter
    }
}

private struct CueFacetOption: Identifiable {
    let id: String
    let title: String
    let count: Int
    let isSelected: Bool
    let toggle: () -> Void
}

private struct CueFacetCard: View {
    let title: String
    let systemImage: String
    let options: [CueFacetOption]
    let isCalculating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .padding(.bottom, WorkbenchControlMetrics.redesignSpacing1)

            ForEach(options) { option in
                Button(action: option.toggle) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                        Image(systemName: option.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(
                                option.isSelected
                                    ? WorkbenchRedesignColors.textPrimary
                                    : WorkbenchRedesignColors.iconMuted
                            )
                            .frame(width: 16, height: 16)

                        Text(option.title)
                            .font(.system(size: 13))
                            .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                            .lineLimit(1)

                        Spacer(minLength: WorkbenchControlMetrics.redesignSpacing2)

                        Text(isCalculating ? "Calculating" : String(option.count))
                            .font(.system(size: 12))
                            .foregroundStyle(WorkbenchRedesignColors.textMuted)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCalculating)
                .accessibilityLabel("\(title), \(option.title)")
                .accessibilityValue(
                    isCalculating
                        ? "Calculating"
                        : "\(option.count), \(option.isSelected ? "selected" : "not selected")"
                )
            }

            Spacer(minLength: 0)
        }
        .padding(WorkbenchControlMetrics.redesignSpacing3)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
        .overlay {
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        ))
    }
}

private extension CueDurationFacet {
    var title: String {
        switch self {
        case .underOneSecond:
            return "<1s"
        case .oneToUnderThreeSeconds:
            return "1–2.999s"
        case .threeToUnderFiveSeconds:
            return "3–4.999s"
        case .fiveSecondsOrMore:
            return "≥5s"
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
            return "English"
        case .japanese:
            return "Japanese"
        case .chinese:
            return "Chinese"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .traditionalChinese:
            return "Traditional Chinese"
        case .unknown:
            return "Unknown"
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
            return "Finished"
        case .watching:
            return "Watching"
        case .unwatched:
            return "Unwatched"
        }
    }
}
