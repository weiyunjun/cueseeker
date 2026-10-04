import SwiftUI

/// A Skeleton placeholder with a smooth Shimmer sweep animation for cover art.
///
/// Follows `docs/human/requirements/20261004-UI-Cover Skeleton Screen With Shimmer.md`:
/// - Replaces static placeholder grey box and icon during loading/queuing.
/// - When `isShimmering` is true (after anti-flicker delay), smoothly animates an
///   angled highlight band sweeping across the surface.
/// - Adapts to Light and Dark modes via design tokens (`skeletonBase` and `skeletonHighlight`).
/// - Respects `accessibilityReduceMotion` by remaining a still base fill.
struct CoverSkeletonShimmerView: View {
    var isShimmering: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(WorkbenchRedesignColors.skeletonBase)

            if isShimmering && !reduceMotion {
                TimelineView(.animation) { context in
                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)
                        let height = max(proxy.size.height, 1)
                        let duration = WorkbenchControlMetrics.redesignShimmerMotionDuration
                        let turns = context.date.timeIntervalSinceReferenceDate / duration
                        let progress = CGFloat(turns - floor(turns))

                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: WorkbenchRedesignColors.skeletonHighlight, location: 0.5),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: width * 1.5, height: height * 1.5)
                        .offset(x: (progress * 2.5 - 1.5) * width)
                    }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
