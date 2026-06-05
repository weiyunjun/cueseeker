import SwiftUI

/// Phase A skeleton for the table-style UI sandbox. Each test page is reachable
/// only through the top-bar test icons so production views stay untouched.
/// Library stays blank; Search/Shiori will host the AppKit table in later phases.
struct WorkbenchTestPageView: View {
    let page: WorkbenchTestPage

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            Text(placeholder)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: String {
        switch page {
        case .library:
            return "Test Library (blank)"
        case .search:
            return "Test Search"
        case .shiori:
            return "Test Shiori"
        }
    }
}
