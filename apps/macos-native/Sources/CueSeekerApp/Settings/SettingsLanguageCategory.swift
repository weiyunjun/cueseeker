import AppKit
import SwiftUI

/// Settings / General's Language group.
struct SettingsLanguageCategory: View {
    private static let coordinateSpaceName = "SettingsLanguageCategorySpace"
    private static let languageTriggerAnchorID = "languageTrigger"

    @EnvironmentObject private var localization: AppLocalizationStore
    @Environment(\.interfaceLayers) private var environmentInterfaceLayers
    @Environment(\.interfaceLayerContext) private var layerContext
    @StateObject private var fallbackInterfaceLayers = InterfaceLayerRegistry()

    @State private var activeLanguageMenu: SettingsLanguageMenuState?
    @StateObject private var languageHighlight = MenuHighlightModel()
    @State private var languageTriggerAnchor = MenuAnchorHandle()
    @State private var viewportGeometry = SettingsSubtitleViewportGeometry()
    @State private var anchorFrames: [String: CGRect] = [:]

    private var activeInterfaceLayers: InterfaceLayerRegistry {
        environmentInterfaceLayers ?? fallbackInterfaceLayers
    }

    private var isLanguageMenuOpen: Bool {
        activeLanguageMenu != nil
    }

    var body: some View {
        SettingsGroup(
            title: L("settings.category.language"),
            description: L("settings.language.description")
        ) {
            SettingsRow(L("settings.language.field")) {
                SettingsSubtitleFontTrigger(
                    title: localization.language.displayName,
                    isOpen: isLanguageMenuOpen
                ) {
                    toggleLanguageMenu()
                }
                .background(MenuAnchorProbe(handle: languageTriggerAnchor))
                .workbenchDropdownAnchor(
                    id: Self.languageTriggerAnchorID,
                    in: Self.coordinateSpaceName
                )
            }
        }
        .coordinateSpace(name: Self.coordinateSpaceName)
        .background(SettingsSubtitleViewportProbe(geometry: viewportGeometry))
        .onPreferenceChange(WorkbenchDropdownAnchorPreferenceKey.self) { anchors in
            for (key, rect) in anchors where rect != .zero {
                anchorFrames[key] = rect
            }
        }
        .overlay(alignment: .topLeading) {
            if let activeLanguageMenu {
                let menuFrame = activeLanguageMenu.menuFrame

                ZStack(alignment: .topLeading) {
                    MenuGateClientView(
                        gate: activeInterfaceLayers.menuGate,
                        owner: layerContext.layer,
                        kind: .cardMenu,
                        menuFrame: menuFrame,
                        anchorFrame: activeLanguageMenu.anchorFrame,
                        notePointer: { point in
                            handleLanguageMenuPointerMove(
                                at: point,
                                menuState: activeLanguageMenu
                            )
                        },
                        handleKey: { keyCode, isRepeat in
                            handleLanguageMenuKey(keyCode, isRepeat: isRepeat)
                        },
                        dismiss: { _ in
                            closeLanguageMenu()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    SettingsLanguageMenuSurfaceHost(
                        menu: SettingsLanguageMenu(
                            selectedLanguage: localization.language,
                            highlight: languageHighlight,
                            onSelect: { language in
                                selectLanguage(language)
                            }
                        )
                    )
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                    .zIndex(1000)
                }
            }
        }
        .onDisappear {
            closeLanguageMenu()
        }
    }

    private func toggleLanguageMenu() {
        if isLanguageMenuOpen {
            closeLanguageMenu()
        } else {
            openLanguageMenu()
        }
    }

    private func openLanguageMenu() {
        let anchorFrame = viewportGeometry.anchorFrame(for: languageTriggerAnchor)
            ?? anchorFrames[Self.languageTriggerAnchorID]
            ?? CGRect(
                x: 0,
                y: 0,
                width: WorkbenchControlMetrics.redesignSettingsPopupWidth,
                height: WorkbenchControlMetrics.redesignFieldHeight
            )
        let container = viewportGeometry.visibleContainerRect(
            fallbackSize: CGSize(
                width: WorkbenchControlMetrics.redesignSettingsWindowWidth
                    - WorkbenchControlMetrics.redesignSettingsSidebarWidth,
                height: WorkbenchControlMetrics.redesignSettingsWindowHeight
                    - WorkbenchControlMetrics.redesignSettingsTitlebarHeight
            )
        )
        let openingFrame = MenuPlacement.openingFrame(
            anchor: anchorFrame,
            menuSize: SettingsLanguageMenu.panelSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: false
        )
        languageHighlight.open(
            selectablePositions: Array(AppLanguage.allCases.indices)
        )
        activeLanguageMenu = SettingsLanguageMenuState(
            anchorFrame: anchorFrame,
            menuFrame: openingFrame
        )
    }

    private func closeLanguageMenu() {
        guard activeLanguageMenu != nil else { return }
        activeLanguageMenu = nil
        languageHighlight.close()
    }

    private func selectLanguage(_ language: AppLanguage) {
        localization.set(language)
        closeLanguageMenu()
    }

    private func handleLanguageMenuPointerMove(
        at point: CGPoint,
        menuState: SettingsLanguageMenuState
    ) {
        guard menuState.menuFrame.contains(point) else {
            languageHighlight.updatePointerHover(position: nil)
            return
        }
        let localPoint = CGPoint(
            x: point.x - menuState.menuFrame.minX,
            y: point.y - menuState.menuFrame.minY
        )
        let position = SettingsLanguageMenu.position(atLocalPoint: localPoint)
        languageHighlight.updatePointerHover(position: position)
    }

    private func handleLanguageMenuKey(_ keyCode: UInt16, isRepeat: Bool) -> Bool {
        switch keyCode {
        case 53:
            if !isRepeat {
                closeLanguageMenu()
            }
            return true
        case 126:
            _ = languageHighlight.moveHighlight(by: -1)
            return true
        case 125:
            _ = languageHighlight.moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76:
            if !isRepeat,
               let position = languageHighlight.highlightedPosition,
               AppLanguage.allCases.indices.contains(position) {
                selectLanguage(AppLanguage.allCases[position])
            }
            return true
        default:
            return false
        }
    }
}

private struct SettingsLanguageMenuState: Identifiable {
    let id = UUID()
    let anchorFrame: CGRect
    let menuFrame: CGRect
}

private struct SettingsLanguageMenuSurfaceHost: NSViewRepresentable {
    let menu: SettingsLanguageMenu

    func makeNSView(context _: Context) -> MenuHostingView {
        MenuHostingView(rootView: AnyView(menu))
    }

    func updateNSView(_ nsView: MenuHostingView, context _: Context) {
        nsView.rootView = AnyView(menu)
    }
}

struct SettingsLanguageMenu: View {
    static let itemStackWidth =
        WorkbenchControlMetrics.redesignSettingsPopupWidth - MenuMetrics.padding * 2
    static let panelSize = CGSize(
        width: WorkbenchControlMetrics.redesignSettingsPopupWidth,
        height: CGFloat(AppLanguage.allCases.count) * WorkbenchControlMetrics.redesignMenuItemHeight
            + MenuMetrics.padding * 2
    )

    let selectedLanguage: AppLanguage
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            maximumHeight: MenuMetrics.maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { position, language in
                    WorkbenchPopoverRow(
                        title: language.displayName,
                        isSelected: selectedLanguage == language,
                        isHighlighted: highlight.isSelected(position),
                        isRowHovered: highlight.isHovered(position),
                        showsCheckmarkSlot: true,
                        action: {
                            onSelect(language)
                        },
                        onHoverChange: { isHovered in
                            highlight.noteHover(isHovered, at: position)
                        }
                    )
                    .id(position)
                }
            }
            .frame(width: Self.itemStackWidth, alignment: .leading)
        }
    }

    static func position(atLocalPoint point: CGPoint) -> Int? {
        let itemRect = CGRect(
            x: MenuMetrics.padding,
            y: MenuMetrics.padding,
            width: itemStackWidth,
            height: CGFloat(AppLanguage.allCases.count)
                * WorkbenchControlMetrics.redesignMenuItemHeight
        )
        guard itemRect.contains(point) else {
            return nil
        }
        let index = Int(
            floor(
                (point.y - MenuMetrics.padding)
                    / WorkbenchControlMetrics.redesignMenuItemHeight
            )
        )
        guard AppLanguage.allCases.indices.contains(index) else {
            return nil
        }
        return index
    }
}
