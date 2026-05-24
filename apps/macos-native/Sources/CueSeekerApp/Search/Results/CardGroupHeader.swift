import SwiftUI

struct CardGroupHeader: View {
    let title: String
    let countText: String
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onExportToAnki: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tokens = LiquidGlassTokens(colorScheme: colorScheme)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button(action: onToggle) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tokens.text3)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .animation(.easeInOut(duration: 0.16), value: isCollapsed)

                    Text(displayTitleWithSoftWrapOpportunities(title))
                        .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(tokens.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(countText)
                        .font(.system(size: SearchTypography.groupHeaderSize, weight: .semibold))
                        .foregroundStyle(tokens.text3)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)

            if let onExportToAnki {
                Button(action: onExportToAnki) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tokens.text3)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Export group to Anki")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
