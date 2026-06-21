import SwiftUI

/// Table-style UI sandbox pages, reachable only through the top-bar test icons
/// so production views stay untouched.
struct WorkbenchTestPageView: View {
    let page: WorkbenchTestPage

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()

            switch page {
            case .library:
                WorkbenchTestLibraryView()
            case .search:
                WorkbenchTestSearchView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
