import Combine
import SwiftUI
import CueSeekerCore

/// The open Filter dialog, if any. Search and the Excerpt detail each open it
/// over their own table, and the window's dialog layer presents it.
///
/// See `docs/human/requirements/20260915-UI-Filter Menu Becomes Filter
/// Dialog.md`.
final class CueFacetFilterDialogCenter: ObservableObject {
    @Published var session: CueFacetFilterDialogSession?
}

/// One opening of the Filter dialog. Checking an option changes only the
/// dialog's own selection; the table keeps the selection it had when the
/// dialog opened until Show hands it a different one.
@MainActor
final class CueFacetFilterDialogSession: ObservableObject, Identifiable {
    enum Source {
        case search
        case excerpt
    }

    let id = UUID()
    let source: Source
    /// The table's selection when the dialog opened.
    let appliedFilter: CueFacetFilter
    @Published var filter: CueFacetFilter
    private let apply: (CueFacetFilter) -> Void

    init(
        source: Source,
        filter: CueFacetFilter,
        apply: @escaping (CueFacetFilter) -> Void
    ) {
        self.source = source
        appliedFilter = filter
        self.filter = filter
        self.apply = apply
    }

    /// Show: the table takes the dialog's selection only when it differs from
    /// the one the table already has.
    func show() {
        guard filter != appliedFilter else { return }
        apply(filter)
    }
}

extension CueFacetFilterDialogSession.Source {
    func showTitle(totalCount: Int?) -> String {
        switch (self, totalCount) {
        case (.search, nil):
            L("filter_dialog.show_results")
        case (.search, 1?):
            L("filter_dialog.show_results.one")
        case (.search, let count?):
            L("filter_dialog.show_results.other", count)
        case (.excerpt, nil):
            L("filter_dialog.show_excerpts")
        case (.excerpt, 1?):
            L("filter_dialog.show_excerpts.one")
        case (.excerpt, let count?):
            L("filter_dialog.show_excerpts.other", count)
        }
    }
}

/// What the dialog knows for its selection: the counts, which of them are not
/// known yet, and the total, nil while it is not known.
struct CueFacetFilterCounts: Equatable {
    static let unknown = CueFacetFilterCounts(
        distribution: nil,
        isCalculating: true,
        pendingKinds: [],
        totalCount: nil
    )

    let distribution: CueFacetDistribution?
    /// No count is known yet.
    let isCalculating: Bool
    /// The unchecked options of these cards are not known yet.
    let pendingKinds: Set<CueFacetKind>
    let totalCount: Int?

    /// Search never runs for the dialog's selection (requirement 6.4). The
    /// selection the search runs with has the search's own counts; once every
    /// count is complete, any other selection is answered from the complete
    /// rows; before that it waits for them.
    static func search(
        selection: CueFacetFilter,
        searchFilter: CueFacetFilter,
        isQueryEmpty: Bool,
        searchCounts: CueFacetFilterCounts,
        completeDistribution: (CueFacetFilter) -> CueFacetDistribution?
    ) -> CueFacetFilterCounts {
        if isQueryEmpty {
            return CueFacetFilterCounts(
                distribution: .zero,
                isCalculating: false,
                pendingKinds: [],
                totalCount: 0
            )
        }
        if selection == searchFilter {
            return searchCounts
        }
        guard let distribution = completeDistribution(selection) else {
            return .unknown
        }
        return CueFacetFilterCounts(
            distribution: distribution,
            isCalculating: false,
            pendingKinds: [],
            totalCount: distribution.totalCount
        )
    }

    /// Every count is unknown while nothing is known; afterwards only the
    /// unchecked options of a card whose count is still running.
    func isUnknown(_ kind: CueFacetKind, isSelected: Bool) -> Bool {
        isCalculating || (pendingKinds.contains(kind) && !isSelected)
    }
}

struct CueFacetOption: Identifiable {
    let id: String
    let title: String
    /// Nil while the count is not known.
    let count: Int?
    let isSelected: Bool
    let toggle: () -> Void
}

struct CueFacetSection: Identifiable {
    let id: CueFacetKind
    let title: String
    let icon: AppIcon
    let options: [CueFacetOption]

    /// The four cards in dialog order. Each option carries its count for the
    /// dialog's selection, and toggles itself in that selection.
    static func sections(
        counts: CueFacetFilterCounts,
        availableLanguages: [SubtitleLanguageCode],
        selection: CueFacetFilter,
        update: @escaping ((inout CueFacetFilter) -> Void) -> Void
    ) -> [CueFacetSection] {
        func options<Value: Hashable>(
            _ kind: CueFacetKind,
            _ values: [Value],
            at keyPath: WritableKeyPath<CueFacetFilter, Set<Value>>,
            id: (Value) -> String,
            title: (Value) -> String,
            count: (CueFacetDistribution, Value) -> Int?
        ) -> [CueFacetOption] {
            values.map { value in
                let isSelected = selection[keyPath: keyPath].contains(value)
                return CueFacetOption(
                    id: id(value),
                    title: title(value),
                    count: counts.isUnknown(kind, isSelected: isSelected)
                        ? nil
                        : counts.distribution.flatMap { count($0, value) } ?? 0,
                    isSelected: isSelected,
                    toggle: {
                        update { filter in
                            if filter[keyPath: keyPath].contains(value) {
                                filter[keyPath: keyPath].remove(value)
                            } else {
                                filter[keyPath: keyPath].insert(value)
                            }
                        }
                    }
                )
            }
        }

        return [
            CueFacetSection(
                id: .duration,
                title: L("facet.duration"),
                icon: .clock,
                options: options(
                    .duration,
                    CueDurationFacet.allCases,
                    at: \.durations,
                    id: { $0.rawValue },
                    title: { $0.title },
                    count: { $0.durationCounts[$1] }
                )
            ),
            CueFacetSection(
                id: .characters,
                title: L("facet.character"),
                icon: .textAa,
                options: options(
                    .characters,
                    CueCharacterFacet.allCases,
                    at: \.characters,
                    id: { $0.rawValue },
                    title: { $0.title },
                    count: { $0.characterCounts[$1] }
                )
            ),
            CueFacetSection(
                id: .languages,
                title: L("facet.language"),
                icon: .globe,
                options: options(
                    .languages,
                    availableLanguages,
                    at: \.languages,
                    id: { $0.rawValue },
                    title: { $0.title },
                    count: { $0.languageCounts[$1] }
                )
            ),
            CueFacetSection(
                id: .watchState,
                title: L("facet.watch_status"),
                icon: .eye,
                options: options(
                    .watchState,
                    LibraryWatchState.facetCases,
                    at: \.watchStates,
                    id: { $0.rawValue },
                    title: { $0.title },
                    count: { $0.watchStateCounts[$1] }
                )
            ),
        ]
    }
}

/// The Filter dialog: the four cards as rows of capsule options, the
/// calculating status, and Show, which hands the dialog's selection to the
/// table.
struct CueFacetFilterDialog: View {
    @ObservedObject var session: CueFacetFilterDialogSession
    let counts: CueFacetFilterCounts
    let availableLanguages: [SubtitleLanguageCode]
    let onClose: () -> Void

    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    var body: some View {
        let _ = UIInvalidationProbe.count("UI.FilterDialog.body")
        let sections = CueFacetSection.sections(
            counts: counts,
            availableLanguages: availableLanguages,
            selection: session.filter,
            update: { change in change(&session.filter) }
        )
        WorkbenchDialogColumn(
            spacing: WorkbenchControlMetrics.redesignSpacing4,
            maxHeight: availableSize.height
                - WorkbenchControlMetrics.redesignDialogTopPadding
                - WorkbenchControlMetrics.redesignDialogInset
        ) {
            WorkbenchDialogHeader(title: L("table.filter"))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            // The scroll view reaches the dialog's sides, so its scrollbar runs
            // in the inset rather than over the options.
            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }

            footer(
                hasUnknownCount: sections.contains { section in
                    section.options.contains { $0.count == nil }
                }
            )
            .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .background(WorkbenchRedesignColors.bgSurface)
        .workbenchDialogCloseButton(onClose: onClose)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private func sectionView(_ section: CueFacetSection) -> some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                AppIconImage(section.icon, size: WorkbenchControlMetrics.redesignControlIconSize)
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)

                Text(section.title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .medium
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
            }

            WrappingFlowLayout(
                alignment: .leading,
                horizontalSpacing: WorkbenchControlMetrics.redesignSpacing2,
                verticalSpacing: WorkbenchControlMetrics.redesignSpacing2
            ) {
                ForEach(section.options) { option in
                    CueFacetFilterChip(option: option)
                }
            }
        }
    }

    private func footer(hasUnknownCount: Bool) -> some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if hasUnknownCount {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    WorkbenchSpinner()

                    Text(L("facet.calculating"))
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                        .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            Spacer(minLength: 0)

            // Reset keeps a wider gap to Cancel than Cancel keeps to Show.
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                // Reset clears the dialog's selection only; the table waits
                // for Show like any other change.
                WorkbenchButton(
                    title: L("common.reset"),
                    isRedesign: true,
                    action: { session.filter = CueFacetFilter() }
                )
                .disabled(session.filter.isEmpty)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    WorkbenchButton(
                        title: L("common.cancel"),
                        isRedesign: true,
                        action: onClose
                    )
                    .keyboardShortcut(.cancelAction)

                    // Show stays available while counts are unknown; only its
                    // title waits for the total.
                    WorkbenchPrimaryButton(
                        title: session.source.showTitle(totalCount: counts.totalCount),
                        action: {
                            session.show()
                            onClose()
                        }
                    )
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

/// A capsule option: its title and count, or a still placeholder in place of
/// a count that is not known yet.
private struct CueFacetFilterChip: View {
    let option: CueFacetOption

    @State private var isHovered = false

    var body: some View {
        Button(action: option.toggle) {
            label
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .onPointerHover { isHovered = $0 }
        .accessibilityLabel(option.title)
        .accessibilityValue(accessibilityValue)
    }

    private var label: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Text(option.title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            countView
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
        .frame(height: WorkbenchControlMetrics.redesignFilterChipHeight)
        .background(Capsule().fill(backgroundColor))
        .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var countView: some View {
        if let count = option.count {
            Text(String(count))
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                .foregroundStyle(countColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        } else {
            Capsule()
                .fill(WorkbenchRedesignColors.borderControl)
                .frame(
                    width: WorkbenchControlMetrics.redesignFilterChipCountPlaceholderWidth,
                    height: WorkbenchControlMetrics.redesignFilterChipCountPlaceholderHeight
                )
        }
    }

    private var accessibilityValue: String {
        guard let count = option.count else {
            return L("facet.calculating")
        }
        let state = option.isSelected ? L("facet.selected") : L("facet.not_selected")
        return "\(count), \(state)"
    }

    private var titleColor: Color {
        option.isSelected
            ? WorkbenchRedesignColors.filterChipSelectedContent
            : WorkbenchRedesignColors.textPrimary
    }

    private var countColor: Color {
        option.isSelected
            ? WorkbenchRedesignColors.filterChipSelectedContent
            : WorkbenchRedesignColors.textSecondary
    }

    private var backgroundColor: Color {
        if option.isSelected {
            return WorkbenchRedesignColors.filterChipSelectedBg
        }
        return isHovered ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface
    }

    private var borderColor: Color {
        if option.isSelected {
            return WorkbenchRedesignColors.filterChipSelectedContent
        }
        return isHovered
            ? WorkbenchRedesignColors.borderControlHover
            : WorkbenchRedesignColors.borderControl
    }
}

/// What the Filter dialog shows of Search. The search changes on every row it
/// adds; this changes only when a count, the total or the calculating state
/// does.
struct SearchFacetDialogSearchState: Equatable {
    let isQueryEmpty: Bool
    let searchFilter: CueFacetFilter
    let searchCounts: CueFacetFilterCounts
    /// Every match of the query with its facet values, once every count is
    /// complete.
    let completeSnapshot: CueFacetSnapshot?
    let availableLanguages: [SubtitleLanguageCode]

    @MainActor
    init(_ search: SearchStore) {
        isQueryEmpty = search.searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        searchFilter = search.searchFacetFilter
        searchCounts = CueFacetFilterCounts(
            distribution: search.displayedSearchFacetDistribution,
            isCalculating: search.isFacetSnapshotCalculating,
            pendingKinds: search.searchFacetCountsPendingKinds,
            totalCount: search.searchStatus == .completed
                && search.searchCountState == .exact
                ? search.searchResultTotalCount
                : nil
        )
        completeSnapshot = search.isSearchFacetSnapshotComplete
            ? search.searchFacetSnapshot
            : nil
        var available = Set(
            search.emptySearchFacetDistribution?.languageCounts.compactMap {
                $0.value > 0 ? $0.key : nil
            } ?? []
        )
        if let snapshot = search.searchFacetSnapshot {
            available.formUnion(snapshot.distribution.languageCounts.keys)
        }
        available.insert(.unknown)
        availableLanguages = SubtitleLanguageCode.allCases.filter(available.contains)
    }

    func counts(for selection: CueFacetFilter) -> CueFacetFilterCounts {
        CueFacetFilterCounts.search(
            selection: selection,
            searchFilter: searchFilter,
            isQueryEmpty: isQueryEmpty,
            searchCounts: searchCounts,
            completeDistribution: { selection in
                completeSnapshot.map { snapshot in
                    snapshot.filteredCueIDs(
                        using: selection,
                        limit: snapshot.cueIDs.count
                    ).distribution
                }
            }
        )
    }
}

/// The Filter dialog over Search. It follows only what it shows of the
/// search, so it redraws when a count, the total or the calculating state
/// changes, not on every row the search adds.
struct SearchFacetFilterDialog: View {
    @ObservedObject var session: CueFacetFilterDialogSession
    let search: SearchStore
    let onClose: () -> Void

    @State private var searchState: SearchFacetDialogSearchState

    init(
        session: CueFacetFilterDialogSession,
        search: SearchStore,
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.search = search
        self.onClose = onClose
        _searchState = State(initialValue: SearchFacetDialogSearchState(search))
    }

    var body: some View {
        CueFacetFilterDialog(
            session: session,
            counts: searchState.counts(for: session.filter),
            availableLanguages: searchState.availableLanguages,
            onClose: onClose
        )
        .onReceive(search.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            let next = SearchFacetDialogSearchState(search)
            if next != searchState {
                searchState = next
            }
        }
    }
}

/// The Filter dialog over an Excerpt list. The list is in memory, so every
/// selection is answered at once.
struct ExcerptFacetFilterDialog: View {
    @ObservedObject var session: CueFacetFilterDialogSession
    @ObservedObject var excerptStore: ExcerptStore
    let appState: AppCoordinator
    let onClose: () -> Void

    var body: some View {
        CueFacetFilterDialog(
            session: session,
            counts: counts,
            availableLanguages: availableLanguages,
            onClose: onClose
        )
    }

    private var counts: CueFacetFilterCounts {
        guard excerptStore.residentFacetSnapshot != nil else {
            return .unknown
        }
        let projection = appState.residentExcerptTableProjection(
            searchText: excerptStore.tableSearchDraft,
            facetFilter: session.filter
        )
        return CueFacetFilterCounts(
            distribution: projection.distribution,
            isCalculating: false,
            pendingKinds: [],
            totalCount: projection.relations.count
        )
    }

    private var availableLanguages: [SubtitleLanguageCode] {
        guard let snapshot = excerptStore.residentFacetSnapshot else {
            return []
        }
        return SubtitleLanguageCode.allCases.filter {
            snapshot.distribution.languageCounts.keys.contains($0)
        }
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
