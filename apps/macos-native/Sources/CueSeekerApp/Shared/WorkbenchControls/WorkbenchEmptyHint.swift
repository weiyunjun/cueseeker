import SwiftUI

struct WorkbenchEmptyHint: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3 * 2)
    }
}
