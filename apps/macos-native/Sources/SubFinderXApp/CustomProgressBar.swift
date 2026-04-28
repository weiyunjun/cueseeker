import SwiftUI

struct CustomProgressBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var isHovering = false
    @State private var dragTime: Double? = nil

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let safeDuration = duration > 0 ? duration : 1.0
            
            let displayTime = dragTime ?? currentTime
            let progress = max(0, min(1, displayTime / safeDuration))
            let thumbX = totalWidth * progress
            let barHeight: CGFloat = isHovering || dragTime != nil ? 6 : 3

            ZStack(alignment: .leading) {
                // Background Track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: barHeight)
                
                // Filled Track
                Rectangle()
                    .fill(Color.red)
                    .frame(width: thumbX, height: barHeight)
                
                // Thumb
                if isHovering || dragTime != nil {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                        .offset(x: thumbX - 7)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom) // Align the actual drawing at the bottom
            .contentShape(Rectangle()) // Make the whole frame interactable
            .onHover { hover in
                isHovering = hover // User requested simple non-animated hover
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
        .frame(height: 20) // Tappable area
    }
}
