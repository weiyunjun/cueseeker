import AppKit
import SwiftUI
import SubFinderXPlayback

struct PlaybackView: View {
    let player: MPVPlayer?

    var body: some View {
        if let player = player {
            PlaybackVideoView(player: player)
        } else {
            Color.black
        }
    }
}

struct PlaybackVideoView: View {
    let player: MPVPlayer
    @StateObject private var viewModel: PlaybackViewModel
    @State private var isControlsVisible = false

    init(player: MPVPlayer) {
        self.player = player
        _viewModel = StateObject(wrappedValue: PlaybackViewModel(player: player))
    }

    var body: some View {
        ZStack {
            MPVRenderViewWrapper(player: player)
            
            if isControlsVisible {
                PlaybackControlsView(viewModel: viewModel)
            }
        }
        .onHover { hover in
            isControlsVisible = hover
        }
    }
}

struct MPVRenderViewWrapper: NSViewRepresentable {
    let player: MPVPlayer

    func makeNSView(context: Context) -> NSView {
        MPVRenderView(player: player)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
