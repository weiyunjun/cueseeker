import CueSeekerCore
import Foundation
import SwiftUI

struct VocabularyEntryDetailView: View {
    let entry: VocabularyEntry

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.term)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(tokens.text)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Vocabulary")
                        .font(.system(size: SearchTypography.detailSize, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(tokens.text3)
                }

                VocabularyDetailSection(title: "Explanation", systemImage: "text.alignleft") {
                    Text(entry.explanation)
                        .font(.system(size: SearchTypography.bodySize))
                        .foregroundStyle(tokens.text2)
                        .lineLimit(nil)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VocabularyDetailSection(title: "Collected", systemImage: "clock") {
                    Text(VocabularyEntryCreatedAtFormatter.displayText(createdAt: entry.createdAt))
                        .font(.system(size: SearchTypography.bodySize, design: .monospaced))
                        .foregroundStyle(tokens.text2)
                        .monospacedDigit()
                }

                VocabularyDetailSection(title: "Examples", systemImage: "quote.bubble") {
                    VocabularyExamplesEmptyStateView()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, SearchCardLayout.contentBottomPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum VocabularyEntryCreatedAtFormatter {
    static func displayText(createdAt: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: createdAt) else {
            return "Failed to load"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct VocabularyDetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(tokens.text3)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VocabularyExamplesEmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)

        HStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tokens.text3)

            Text("No Examples")
                .font(.system(size: SearchTypography.bodySize))
                .foregroundStyle(tokens.text3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tokens.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tokens.cardHairline, lineWidth: 0.5)
        )
    }
}
