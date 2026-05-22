import SwiftUI

struct PlaybackProgressScrubber: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @State private var isHovered = false
    @State private var dragTime: Double?

    var body: some View {
        GeometryReader { geometry in
            let duration = max(0, viewModel.duration)
            let displayTime = dragTime ?? viewModel.displayedCurrentTime
            let progress = duration > 0
                ? min(max(displayTime / duration, 0), 1)
                : 0
            let width = max(0, geometry.size.width)
            let filledWidth = width * progress
            let trackHeight: CGFloat = (isHovered || dragTime != nil) ? 6 : 3

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.white.opacity(0.68))
                    .frame(width: filledWidth, height: trackHeight)

                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 12, height: 12)
                    .offset(x: filledWidth - 6)
                    .opacity(isHovered || dragTime != nil ? 1 : 0)
            }
            .frame(height: 18, alignment: .center)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0, width > 0 else {
                            return
                        }
                        dragTime = seekTime(for: value.location.x, width: width, duration: duration)
                    }
                    .onEnded { value in
                        guard duration > 0, width > 0 else {
                            dragTime = nil
                            return
                        }
                        let finalTime = seekTime(for: value.location.x, width: width, duration: duration)
                        dragTime = nil
                        viewModel.seek(to: finalTime)
                    }
            )
        }
        .frame(height: 18)
    }

    private func seekTime(for xPosition: CGFloat, width: CGFloat, duration: Double) -> Double {
        let progress = Double(min(max(xPosition / max(width, 1), 0), 1))
        return progress * duration
    }
}
