import SwiftUI

struct CustomProgressBar: View {
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var isHovering = false
    @State private var dragTime: Double? = nil

    private let hitAreaHeight: CGFloat = 20
    private let thumbDiameter: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let safeDuration = duration > 0 ? duration : 1.0
            
            let displayTime = dragTime ?? currentTime
            let progress = max(0, min(1, displayTime / safeDuration))
            let thumbX = totalWidth * progress
            let barHeight: CGFloat = isHovering || dragTime != nil ? 6 : 3

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: barHeight)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: thumbX, height: barHeight)

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .opacity(isHovering || dragTime != nil ? 1 : 0)
                    .offset(x: thumbX - thumbDiameter / 2)
            }
            .frame(height: hitAreaHeight, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hover in
                isHovering = hover
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = max(0, min(1, value.location.x / totalWidth))
                        dragTime = percent * duration
                    }
                    .onEnded { value in
                        let percent = max(0, min(1, value.location.x / totalWidth))
                        let finalTime = percent * duration
                        dragTime = nil
                        onSeek(finalTime)
                    }
            )
        }
        .frame(height: hitAreaHeight)
    }
}
