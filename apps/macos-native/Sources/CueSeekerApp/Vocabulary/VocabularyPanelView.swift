import CueSeekerCore
import SwiftUI

struct VocabularyPanelView: View {
    @EnvironmentObject private var vocabulary: VocabularyStore
    @EnvironmentObject private var shiori: ShioriStore
    @Environment(\.colorScheme) private var colorScheme

    let onSelectEntry: (Int64) -> Void
    let onOpenExample: (VocabularyExample, [VocabularyExample]) -> Void

    private var selectedEntry: VocabularyEntry? {
        vocabulary.selectedEntry ?? vocabulary.entries.first
    }

    var body: some View {
        GeometryReader { geometry in
            let displayTitlesByPath = shioriDisplayTitlesByPath
            let allExamples = VocabularyExampleDeriver.allExamples(
                for: vocabulary.entries,
                shioris: shiori.shioris,
                displayTitlesBySubtitlePath: displayTitlesByPath
            )
            let listWidth = min(
                VocabularyPanelLayout.maxListWidth,
                max(
                    VocabularyPanelLayout.minListWidth,
                    geometry.size.width * VocabularyPanelLayout.listWidthRatio
                )
            )

            HStack(spacing: 0) {
                vocabularyEntryList
                    .frame(width: listWidth)

                Rectangle()
                    .fill(LiquidGlassTokens(colorScheme: colorScheme).hairlineSoft)
                    .frame(width: 1)

                if let selectedEntry {
                    VocabularyEntryDetailView(
                        entry: selectedEntry,
                        examples: VocabularyExampleDeriver.examples(
                            for: selectedEntry,
                            shioris: shiori.shioris,
                            displayTitlesBySubtitlePath: displayTitlesByPath
                        ),
                        onOpenExample: { example in
                            onOpenExample(example, allExamples)
                        }
                    )
                } else {
                    InfoPageStateView(state: .vocabularyEmpty)
                        .font(.system(size: SearchTypography.bodySize))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }

    private var shioriDisplayTitlesByPath: [String: String] {
        Dictionary(uniqueKeysWithValues: shiori.shioriFileGroups.map {
            ($0.subtitlePath, $0.subtitleDisplayTitle)
        })
    }

    private var vocabularyEntryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SearchCardLayout.cardVerticalSpacing) {
                ForEach(vocabulary.entries) { entry in
                    VocabularyEntryPreviewCard(
                        entry: entry,
                        isSelected: selectedEntry?.id == entry.id,
                        onSelect: {
                            onSelectEntry(entry.id)
                        }
                    )
                    .focusable(false)
                }
            }
            .padding(.horizontal, SearchCardLayout.contentHorizontalPadding)
            .padding(.top, SearchCardLayout.contentTopPadding)
            .padding(.bottom, SearchCardLayout.contentBottomPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private enum VocabularyPanelLayout {
    static let minListWidth: CGFloat = 300
    static let maxListWidth: CGFloat = 420
    static let listWidthRatio: CGFloat = 0.34
}
