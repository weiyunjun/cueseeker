import SwiftUI

/// The pieces every Settings page is built from. See
/// `docs/human/requirements/20260914-UI-Settings Categories Merge And Grouped
/// Card Layout.md`.

/// One category's page: its groups, scrolling when they run past the window.
/// The trailing Scrollbar channel is always kept, so the cards do not move when
/// the Scrollbar comes and goes.
struct SettingsPage<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                    content
                }
                .padding(.top, WorkbenchControlMetrics.redesignSpacing1)
                .padding(.leading, WorkbenchControlMetrics.redesignSpacing6)
                .padding(
                    .trailing,
                    WorkbenchControlMetrics.redesignSpacing6
                        + WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel
                )
                .padding(.bottom, WorkbenchControlMetrics.redesignSpacing6)
                .frame(
                    maxWidth: .infinity,
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

/// A group on a page: its optional title, then its rows on one card as wide as the page.
struct SettingsGroup<Content: View>: View {
    private let title: String?
    private let content: Content

    init(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if let title {
                WorkbenchSelectableText(
                    title,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .semibold,
                    color: WorkbenchRedesignColors.textPrimary,
                    lineLimit: nil,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                    style: .continuous
                )
                .fill(WorkbenchRedesignColors.tableBg)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                    style: .continuous
                )
                .strokeBorder(
                    WorkbenchRedesignColors.borderControl,
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
            )
        }
    }
}

/// A row on a card: the name side leading, the control trailing.
struct SettingsRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            leading
            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing4)
            trailing
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        .padding(.vertical, WorkbenchControlMetrics.redesignSettingsRowVerticalPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignSettingsRowMinHeight
        )
    }
}

extension SettingsRow where Leading == SettingsRowLabel {
    /// The usual row: a name leading and a control trailing.
    init(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            leading: { SettingsRowLabel(title: title) },
            trailing: trailing
        )
    }
}

struct SettingsRowLabel: View {
    let title: String

    var body: some View {
        WorkbenchSelectableText(
            title,
            fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
            color: WorkbenchRedesignColors.textPrimary,
            lineLimit: nil,
            alignment: .leading
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The line between two rows of a card, inset like the rows' content.
struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(WorkbenchRedesignColors.borderDivider)
            .frame(height: WorkbenchControlMetrics.redesignControlBorderWidth)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
    }
}
