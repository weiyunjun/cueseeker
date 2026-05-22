import SwiftUI

struct SettingsExperimentalCategory: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Experimental Features")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Try unstable features that may change or be removed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }
}
