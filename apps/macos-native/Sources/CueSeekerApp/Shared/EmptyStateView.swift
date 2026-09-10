import SwiftUI

struct EmptyStateView: View {
    let title: String
    let icon: AppIcon
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            AppIconImage(icon, size: WorkbenchControlMetrics.redesignEmptyStateIconSize)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

