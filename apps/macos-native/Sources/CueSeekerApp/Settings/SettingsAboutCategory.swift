import AppKit
import SwiftUI

/// Settings / About page: project overview, manual release update check, and repository link.
struct SettingsAboutCategory: View {
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var isRepositoryHovered = false

    var body: some View {
        // Read localization language to force body evaluation when switching languages.
        _ = localization.language
        return WorkbenchAccessibilityReader { accessibility in
            projectInfoSection

            SettingsGroup {
                SettingsRow(L("settings.about.update.title")) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                        updateStatusIndicator
                        updateActionButton(
                            isFocused: accessibility?.isSettingsFocused(.aboutUpdateAction) == true
                        )
                    }
                }

                SettingsRowDivider()

                SettingsRow(L("settings.about.repository.title")) {
                    repositoryLinkHotspot(
                        isFocused: accessibility?.isSettingsFocused(.aboutRepositoryLink) == true
                    )
                }
            }
        }
    }

    private var projectInfoSection: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            VStack(alignment: .center, spacing: 0) {
                Image(nsImage: settingsStore.aboutAppIconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: WorkbenchControlMetrics.redesignAboutAppIconSize,
                        height: WorkbenchControlMetrics.redesignAboutAppIconSize
                    )
                    .accessibilityHidden(true)

                Color.clear
                    .frame(height: WorkbenchControlMetrics.redesignSpacing3)

                WorkbenchSelectableText(
                    L("app.name"),
                    fontSize: WorkbenchControlMetrics.redesignFontSizePageTitle,
                    weight: WorkbenchControlMetrics.redesignFontWeightPageTitle,
                    color: WorkbenchRedesignColors.textPrimary,
                    lineLimit: 1,
                    alignment: .center
                )
                .fixedSize(horizontal: true, vertical: true)

                Color.clear
                    .frame(height: WorkbenchControlMetrics.redesignSpacing1)

                WorkbenchSelectableText(
                    L("settings.about.version", settingsStore.appShortVersion),
                    fontSize: WorkbenchControlMetrics.redesignFontSizeCaption,
                    weight: .regular,
                    color: WorkbenchRedesignColors.textMuted,
                    lineLimit: 1,
                    alignment: .center
                )
                .fixedSize(horizontal: true, vertical: true)
            }
            .frame(maxWidth: .infinity)

            WorkbenchSelectableText(
                L("settings.about.description"),
                fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: .regular,
                color: WorkbenchRedesignColors.textSecondary,
                lineLimit: nil,
                lineHeight: WorkbenchControlMetrics.redesignLineHeightCoverSummaryDescription,
                alignment: .leading
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        }
        .padding(.top, WorkbenchControlMetrics.redesignSpacing4)
    }

    @ViewBuilder
    private var updateStatusIndicator: some View {
        switch settingsStore.releaseUpdateState {
        case .idle, .checking:
            EmptyView()
        case .upToDate:
            WorkbenchStatusIndicator(
                L("settings.about.update.up_to_date"),
                icon: .checkCircle,
                textColor: WorkbenchRedesignColors.textSecondary,
                iconColor: WorkbenchRedesignColors.textSecondary
            )
        case .available(let version, _):
            WorkbenchStatusIndicator(
                L("settings.about.update.available", version),
                icon: nil,
                textColor: WorkbenchRedesignColors.textActive
            )
        case .failed:
            WorkbenchStatusIndicator(
                L("settings.about.update.failed"),
                icon: .warning,
                textColor: WorkbenchRedesignColors.dangerText,
                iconColor: WorkbenchRedesignColors.dangerText
            )
        }
    }

    @ViewBuilder
    private func updateActionButton(isFocused: Bool) -> some View {
        switch settingsStore.releaseUpdateState {
        case .idle, .upToDate, .failed:
            WorkbenchButton(
                title: L("settings.about.update.check"),
                icon: .arrowClockwise,
                isFocused: isFocused
            ) {
                settingsStore.checkForUpdates()
            }
        case .checking:
            WorkbenchButton(
                title: L("settings.about.update.checking"),
                showsSpinner: true,
                isFocused: isFocused
            ) {
            }
            .disabled(true)
        case .available(let version, let releaseURL):
            WorkbenchPrimaryButton(
                title: L("settings.about.update.download", version),
                icon: .linkSimple,
                isFocused: isFocused
            ) {
                NSWorkspace.shared.open(releaseURL)
            }
        }
    }

    private func repositoryLinkHotspot(isFocused: Bool) -> some View {
        HStack(spacing: 0) {
            WorkbenchSelectableText(
                L("settings.about.repository.link"),
                fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                weight: WorkbenchControlMetrics.redesignFontWeightControl,
                color: WorkbenchRedesignColors.textSecondary,
                lineLimit: 1,
                preferredPointerShape: isRepositoryHovered ? .grab : .arrow,
                showsUnderline: isRepositoryHovered,
                onTap: {
                    settingsStore.openGitHubRepository()
                }
            )
            .fixedSize(horizontal: true, vertical: true)

            HStack(spacing: 0) {
                Color.clear
                    .frame(
                        width: WorkbenchControlMetrics.redesignSpacing2,
                        height: WorkbenchControlMetrics.redesignButtonIconSize
                    )

                AppIconImage(
                    .linkSimple,
                    size: WorkbenchControlMetrics.redesignButtonIconSize
                )
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .overlay(
                SettingsPointerCursorArea(
                    pointerShape: isRepositoryHovered ? .grab : .arrow,
                    onTap: {
                        settingsStore.openGitHubRepository()
                    }
                )
            )
        }
        .contentShape(Rectangle())
        .onPointerHover(showsHand: true) { isHovered in
            isRepositoryHovered = isHovered
        }
        .onDisappear {
            isRepositoryHovered = false
        }
        .accessibilityLabel(L("settings.about.repository.link"))
        .accessibilityAddTraits(.isLink)
        .workbenchAccessibilityFocusRing(
            isFocused: isFocused,
            cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
        )
    }
}

/// Cursor-rect and non-drag click surface for the non-text segment of the link hotspot inside the Settings window.
private struct SettingsPointerCursorArea: NSViewRepresentable {
    let pointerShape: PointerShape
    let onTap: () -> Void

    func makeNSView(context: Context) -> SettingsPointerCursorAreaNSView {
        let view = SettingsPointerCursorAreaNSView()
        view.pointerShape = pointerShape
        view.onTap = onTap
        return view
    }

    func updateNSView(_ nsView: SettingsPointerCursorAreaNSView, context: Context) {
        let shapeChanged = nsView.pointerShape != pointerShape
        nsView.pointerShape = pointerShape
        nsView.onTap = onTap
        if shapeChanged {
            nsView.window?.invalidateCursorRects(for: nsView)
        }
    }
}

@MainActor
private final class SettingsPointerCursorAreaNSView: NSView, PointerShapeProviding {
    var pointerShape: PointerShape = .arrow
    var onTap: (() -> Void)?
    private var mouseDownWindowPoint: CGPoint?

    override var isFlipped: Bool { true }

    func pointerShape(atWindowPoint point: CGPoint) -> PointerShape {
        pointerShape
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: pointerShape.cursor)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownWindowPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownWindowPoint else {
            return
        }
        let deltaX = event.locationInWindow.x - start.x
        let deltaY = event.locationInWindow.y - start.y
        if hypot(deltaX, deltaY) >= 2.0 {
            mouseDownWindowPoint = nil
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = mouseDownWindowPoint else {
            return
        }
        mouseDownWindowPoint = nil
        let end = event.locationInWindow
        guard hypot(end.x - start.x, end.y - start.y) < 2.0 else {
            return
        }
        let localPoint = convert(end, from: nil)
        if bounds.contains(localPoint) {
            onTap?()
        }
    }
}
