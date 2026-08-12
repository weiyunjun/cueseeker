import SwiftUI
import CueSeekerCore

struct CueFacetFilterPanel: View {
    let distribution: CueFacetDistribution?
    let availableLanguages: [SubtitleLanguageCode]
    let isCalculating: Bool
    let isDisabled: Bool
    @Binding var filter: CueFacetFilter

    var body: some View {
        CueFacetAdaptiveGridLayout {
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
        }
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
            isCalculating: isCalculating,
            isDisabled: isDisabled
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

struct CueFacetAdaptiveGridLayout: Layout {
    private let spacing = WorkbenchControlMetrics.redesignSpacing3
    private let minimumCardWidth = WorkbenchControlMetrics.redesignFilterDataCardMinWidth

    static func columnCount(availableWidth: CGFloat, cardCount: Int) -> Int {
        guard cardCount > 0 else { return 0 }
        guard availableWidth.isFinite else { return cardCount }
        let spacing = WorkbenchControlMetrics.redesignSpacing3
        let minimumWidth = WorkbenchControlMetrics.redesignFilterDataCardMinWidth
        let fittingCount = max(
            1,
            Int((max(0, availableWidth) + spacing) / (minimumWidth + spacing))
        )
        return min(cardCount, max(min(2, cardCount), fittingCount))
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let availableWidth = proposal.width ?? minimumFallbackWidth(cardCount: subviews.count)
        let columns = Self.columnCount(
            availableWidth: availableWidth,
            cardCount: subviews.count
        )
        let measurements = rowMeasurements(
            subviews: subviews,
            availableWidth: availableWidth,
            columns: columns
        )
        return CGSize(
            width: availableWidth,
            height: measurements.rowHeights.reduce(0, +)
                + CGFloat(max(0, measurements.rowHeights.count - 1)) * spacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let columns = Self.columnCount(
            availableWidth: bounds.width,
            cardCount: subviews.count
        )
        let measurements = rowMeasurements(
            subviews: subviews,
            availableWidth: bounds.width,
            columns: columns
        )
        var rowOriginY = bounds.minY
        for index in subviews.indices {
            let row = index / columns
            let column = index % columns
            if column == 0, row > 0 {
                rowOriginY += measurements.rowHeights[row - 1] + spacing
            }
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (measurements.cardWidth + spacing),
                    y: rowOriginY
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: measurements.cardWidth,
                    height: measurements.rowHeights[row]
                )
            )
        }
    }

    private func minimumFallbackWidth(cardCount: Int) -> CGFloat {
        let columns = min(2, cardCount)
        return CGFloat(columns) * minimumCardWidth + CGFloat(max(0, columns - 1)) * spacing
    }

    private func rowMeasurements(
        subviews: Subviews,
        availableWidth: CGFloat,
        columns: Int
    ) -> (cardWidth: CGFloat, rowHeights: [CGFloat]) {
        let cardWidth = (
            availableWidth - CGFloat(max(0, columns - 1)) * spacing
        ) / CGFloat(columns)
        var rowHeights = Array(
            repeating: CGFloat.zero,
            count: (subviews.count + columns - 1) / columns
        )
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(
                ProposedViewSize(width: cardWidth, height: nil)
            )
            rowHeights[index / columns] = max(rowHeights[index / columns], size.height)
        }
        return (cardWidth, rowHeights)
    }
}

struct CueFacetOption: Identifiable {
    let id: String
    let title: String
    let count: Int
    let isSelected: Bool
    let toggle: () -> Void
}

struct CueFacetCard: View {
    let title: String
    let systemImage: String
    let options: [CueFacetOption]
    let isCalculating: Bool
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Image(systemName: systemImage)
                    .font(.system(size: WorkbenchControlMetrics.redesignCheckboxSize))
                    .foregroundStyle(
                        isDisabled
                            ? WorkbenchRedesignColors.iconDisabled
                            : WorkbenchRedesignColors.textSecondary
                    )
                    .frame(
                        width: WorkbenchControlMetrics.redesignCheckboxSize,
                        height: WorkbenchControlMetrics.redesignCheckboxSize
                    )

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .semibold
                    ))
                    .foregroundStyle(
                        isDisabled
                            ? WorkbenchRedesignColors.textDisabled
                            : WorkbenchRedesignColors.textSecondary
                    )
            }
            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing1)

            ForEach(options) { option in
                Button {
                    guard !isCalculating, !isDisabled else { return }
                    option.toggle()
                } label: {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                        WorkbenchCheckboxGlyph(
                            state: option.isSelected ? .checked : .unchecked,
                            isEnabled: !isDisabled,
                            size: WorkbenchControlMetrics.redesignCheckboxSize
                        )

                        Text(option.title)
                            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                            .foregroundStyle(
                                isDisabled
                                    ? WorkbenchRedesignColors.textDisabled
                                    : WorkbenchRedesignColors.textMuted
                            )
                            .lineLimit(1)

                        Spacer(minLength: WorkbenchControlMetrics.redesignSpacing2)

                        Text(isCalculating ? "Calculating" : String(option.count))
                            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                            .foregroundStyle(
                                isDisabled
                                    ? WorkbenchRedesignColors.textDisabled
                                    : WorkbenchRedesignColors.textMuted
                            )
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .allowsHitTesting(!isCalculating)
                .disabled(isDisabled)
                .accessibilityLabel("\(title), \(option.title)")
                .accessibilityValue(
                    isCalculating
                        ? "Calculating"
                        : "\(option.count), \(option.isSelected ? "selected" : "not selected")"
                )
            }
        }
        .padding(WorkbenchControlMetrics.redesignSpacing3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
