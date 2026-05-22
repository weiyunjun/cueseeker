import SwiftUI

struct PlaybackFeedbackLayer: View {
    @ObservedObject var viewModel: PlaybackViewModel

    var body: some View {
        PlaybackFeedbackOverlay(feedback: viewModel.feedback)
    }
}
