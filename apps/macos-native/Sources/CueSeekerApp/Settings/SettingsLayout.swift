import SwiftUI

/// The pieces every Settings page is built from. See
/// `docs/human/requirements/20260914-UI-Settings Categories Merge And Grouped
/// Card Layout.md`.

/// One category's page: its title, then its groups, scrolling when they run
/// past the window. The trailing Scrollbar channel is always kept, so the cards
/// do not move when the Scrollbar comes and goes.
struct SettingsPage<Content: View>: View {
    private let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        WorkbenchScrollView {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizePageTitle,
                        weight: WorkbenchControlMetrics.redesignFontWeightPageTitle
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                    content
                }
            }
            .padding(.leading, WorkbenchControlMetrics.redesignSpacing6)
            .padding(
                .trailing,
                WorkbenchControlMetrics.redesignSpacing6
                    + WorkbenchControlMetrics.redesignWorkbenchPageScrollbarChannel
            )
            .padding(.bottom, WorkbenchControlMetrics.redesignSpacing6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

/// A group on a page: its title and optional description, then its rows on
/// one card as wide as the page.
struct SettingsGroup<Content: View>: View {
    private let title: String
    private let description: String?
    private let content: Content

    init(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .semibold
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                if let description {
                    Text(description)
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                    style: .continuous
                )
                .fill(WorkbenchRedesignColors.settingsGroupBg)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignSettingsGroupRadius,
                    style: .continuous
                )
                .strokeBorder(
                    WorkbenchRedesignColors.borderDivider,
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
    /// The usual row: a name with an optional note below it.
    init(
        _ title: String,
        note: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            leading: { SettingsRowLabel(title: title, note: note) },
            trailing: trailing
        )
    }
}

struct SettingsRowLabel: View {
    let title: String
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let note {
                Text(note)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
