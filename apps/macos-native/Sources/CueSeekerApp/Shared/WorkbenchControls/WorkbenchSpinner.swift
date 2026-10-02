import SwiftUI

/// The Spinner: a still ring with a quarter arc turning at a constant speed.
/// It stands beside text that says what is running, so it reads nothing
/// itself.
///
/// See `docs/human/requirements/20260915-UI-Filter Menu Becomes Filter
/// Dialog.md`, section 9.
struct WorkbenchSpinner: View {
    var size: CGFloat = WorkbenchControlMetrics.redesignSpinnerSize

    init(size: CGFloat = WorkbenchControlMetrics.redesignSpinnerSize) {
        self.size = size
    }

    var body: some View {
        let strokeWidth = WorkbenchControlMetrics.redesignSpinnerStrokeWidth
        TimelineView(.animation) { context in
            let turns = context.date.timeIntervalSinceReferenceDate
                / WorkbenchControlMetrics.redesignSpinnerMotionDuration
            ZStack {
                Circle()
                    .inset(by: strokeWidth / 2)
                    .stroke(WorkbenchRedesignColors.spinnerTrack, lineWidth: strokeWidth)

                Circle()
                    .inset(by: strokeWidth / 2)
                    .trim(from: 0, to: 0.25)
                    .stroke(WorkbenchRedesignColors.spinnerIndicator, lineWidth: strokeWidth)
                    .rotationEffect(.degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
            }
        }
        .frame(
            width: size,
            height: size
        )
        .accessibilityHidden(true)
    }
}
