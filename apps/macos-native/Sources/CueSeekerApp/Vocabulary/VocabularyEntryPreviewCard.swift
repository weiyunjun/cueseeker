import CueSeekerCore
import SwiftUI

struct VocabularyEntryPreviewCard: View {
    let entry: VocabularyEntry
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)

        LiquidGlassSelectableCard(
            isSelected: isSelected,
            cornerRadius: SearchCardLayout.cardCornerRadius,
            action: onSelect
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.term)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tokens.text)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.explanation)
                    .font(.system(size: SearchTypography.bodySize))
                    .foregroundStyle(tokens.text2)
                    .lineLimit(nil)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(
                maxWidth: .infinity,
                minHeight: SearchCardLayout.cardMinHeight,
                alignment: .topLeading
            )
        }
        .accessibilityLabel("Vocabulary \(entry.term)")
    }
}
