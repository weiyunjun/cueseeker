import SwiftUI

/// Segmented Control: one value chosen from a few mutually exclusive options.
struct WorkbenchSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let accessibilityLabel: (Option) -> String

    var body: some View {
        WorkbenchSegmentedControlLayout(spacing: WorkbenchControlMetrics.redesignSegmentedControlGap) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(WorkbenchControlMetrics.redesignSegmentedControlPadding)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                .fill(WorkbenchRedesignColors.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                .strokeBorder(
                    WorkbenchRedesignColors.borderControl,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
        )
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = selection == option

        return Button {
            selection = option
        } label: {
            Text(title(option))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeSegmentedControl,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .lineLimit(1)
                .foregroundStyle(
                    isSelected
                        ? WorkbenchRedesignColors.segmentedControlSelectedContent
                        : WorkbenchRedesignColors.textPrimary
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
                .frame(maxWidth: .infinity)
                .frame(height: WorkbenchControlMetrics.redesignSegmentedControlSegmentHeight)
                .background(
                    RoundedRectangle(
                        cornerRadius: WorkbenchControlMetrics.redesignSegmentedControlSegmentRadius,
                        style: .continuous
                    )
                    .fill(isSelected ? WorkbenchRedesignColors.segmentedControlSelectedBg : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(StaticButtonStyle())
        .focusable(false)
        .accessibilityLabel(accessibilityLabel(option))
        .accessibilityValue(isSelected ? L("facet.selected") : L("facet.not_selected"))
    }
}

/// Lays the options side by side, each as wide as the widest one, so no
/// option's copy is cut off in any language.
private struct WorkbenchSegmentedControlLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let count = CGFloat(subviews.count)
        return CGSize(
            width: optionWidth(subviews) * count + spacing * max(count - 1, 0),
            height: subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let width = optionWidth(subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * (width + spacing), y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
        }
    }

    /// The widest option's own width, rounded up to whole points so every
    /// edge lands on a point.
    private func optionWidth(_ subviews: Subviews) -> CGFloat {
        (subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0).rounded(.up)
    }
}
