import AppKit
import CueSeekerCore
import SwiftUI
import Testing
@testable import CueSeekerApp

@Suite
@MainActor
struct FileCardMenuTests {
    @Test
    func fileCardMenuItemPropertiesAndActions() {
        var actionExecuted = false
        let renameItem = FileCardMenuItem(
            title: "Rename Folder",
            icon: .pencilSimple,
            isEnabled: true,
            isDestructive: false,
            action: {
                actionExecuted = true
            }
        )

        #expect(renameItem.title == "Rename Folder")
        #expect(renameItem.icon == .pencilSimple)
        #expect(renameItem.isEnabled == true)
        #expect(renameItem.isDestructive == false)
        #expect(renameItem.id == "Rename Folder")

        renameItem.action()
        #expect(actionExecuted == true)

        let removeItem = FileCardMenuItem(
            title: "Remove",
            icon: .minusCircle,
            isEnabled: false,
            isDestructive: true,
            action: {}
        )
        #expect(removeItem.title == "Remove")
        #expect(removeItem.icon == .minusCircle)
        #expect(removeItem.isEnabled == false)
        #expect(removeItem.isDestructive == true)
    }

    @Test
    func fileCardMenuPlacementBelowAndAbove() {
        let container = CGRect(x: 0, y: 0, width: 800, height: 600)
        let menuSize = CGSize(width: 160, height: 76)
        let gap: CGFloat = WorkbenchControlMetrics.redesignSpacing1

        // 1. Anchor button at top of container (plenty of room below)
        let topAnchor = CGRect(x: 700, y: 50, width: 32, height: 32)
        let topAnchorForPlacement = CGRect(
            x: topAnchor.maxX - menuSize.width,
            y: topAnchor.minY,
            width: menuSize.width,
            height: topAnchor.height
        )
        let frameBelow = MenuPlacement.openingFrame(
            anchor: topAnchorForPlacement,
            menuSize: menuSize,
            in: container,
            gap: gap,
            shrinksToFit: false
        )
        #expect(frameBelow.minY == topAnchor.maxY + gap)
        #expect(frameBelow.maxX <= container.maxX)
        #expect(frameBelow.minX >= container.minX)
        #expect(frameBelow.width == menuSize.width)
        #expect(frameBelow.height == menuSize.height)

        // 2. Anchor button near bottom of container (insufficient room below)
        let bottomAnchor = CGRect(x: 700, y: 560, width: 32, height: 32)
        let bottomAnchorForPlacement = CGRect(
            x: bottomAnchor.maxX - menuSize.width,
            y: bottomAnchor.minY,
            width: menuSize.width,
            height: bottomAnchor.height
        )
        let frameAbove = MenuPlacement.openingFrame(
            anchor: bottomAnchorForPlacement,
            menuSize: menuSize,
            in: container,
            gap: gap,
            shrinksToFit: false
        )
        #expect(frameAbove.maxY == bottomAnchor.minY - gap)
        #expect(frameAbove.minY >= container.minY)
        #expect(frameAbove.width == menuSize.width)
        #expect(frameAbove.height == menuSize.height)
    }

    @Test
    func fileCardColorTokensAndDotsThreeIcon() {
        // FileGroupHeaderBg (Episode Group Unified Card Header Bar)
        #expect(hexString(WorkbenchRedesignColors.NS.fileGroupHeaderBg, appearance: .aqua) == "#F8F9FB")
        #expect(alphaValue(WorkbenchRedesignColors.NS.fileGroupHeaderBg, appearance: .aqua) == 1.0)
        #expect(hexString(WorkbenchRedesignColors.NS.fileGroupHeaderBg, appearance: .darkAqua) == "#FFFFFF")
        #expect(abs(alphaValue(WorkbenchRedesignColors.NS.fileGroupHeaderBg, appearance: .darkAqua) - 0.04) < 0.001)

        // TableBg (Card Normal & Settings / File Info Group Card)
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .aqua) == "#FFFFFF")
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .darkAqua) == "#2E2E34")

        // RowHover (Card Hover)
        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .aqua) == "#F9FAFB")
        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .darkAqua) == "#383840")

        // FileFolderCardBgPressed (Folder Card Pressed)
        #expect(hexString(WorkbenchRedesignColors.NS.fileFolderCardBgPressed, appearance: .aqua) == "#F3F4F6")
        #expect(hexString(WorkbenchRedesignColors.NS.fileFolderCardBgPressed, appearance: .darkAqua) == "#3E3E47")

        // RowSelected (Button Hover / Open)
        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .aqua) == "#ECEEF2")
        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .darkAqua) == "#43434C")

        // RowActionBgPressed (Button Pressed)
        #expect(hexString(WorkbenchRedesignColors.NS.rowActionBgPressed, appearance: .aqua) == "#DEE2E8")
        #expect(hexString(WorkbenchRedesignColors.NS.rowActionBgPressed, appearance: .darkAqua) == "#4E4E58")

        // Card chevron metric & icon assets resolve
        #expect(WorkbenchControlMetrics.redesignCardChevronSize == 16)
        let iconImage = AppIconStore.image(.dotsThree, size: WorkbenchControlMetrics.redesignControlIconSize)
        #expect(iconImage != nil)
        let chevronImage = AppIconStore.image(.caretRight, size: WorkbenchControlMetrics.redesignCardChevronSize)
        #expect(chevronImage != nil)
    }

    @Test
    func fileCardPopoverMenuRendersFittingSizeWithoutOverflow() {
        let highlight = MenuHighlightModel()
        let items = [
            FileCardMenuItem(
                title: L("file.menu.rename_this_folder"),
                icon: .pencilSimple,
                isEnabled: true,
                isDestructive: false,
                action: {}
            ),
            FileCardMenuItem(
                title: L("file.menu.index_this_folder"),
                icon: .arrowClockwise,
                isEnabled: true,
                isDestructive: false,
                action: {}
            ),
            FileCardMenuItem(
                title: L("file.menu.remove_this_folder"),
                icon: .minusCircle,
                isEnabled: true,
                isDestructive: true,
                action: {}
            )
        ]

        #expect(L("settings.library.index_now") == "Index All")
        #expect(items.map(\.title) == [
            "Rename This Folder",
            "Index This Folder",
            "Remove This Folder"
        ])

        let popover = FileCardMenuPopover(
            items: items,
            highlight: highlight,
            onDismiss: {}
        )

        let host = NSHostingView(rootView: popover)
        host.layoutSubtreeIfNeeded()
        let fittingSize = host.fittingSize

        #expect(fittingSize.width >= 160)
        #expect(fittingSize.height > 90)
        #expect(fittingSize.height < 160)
    }

    @Test
    func fileCardTrailingIconButtonCenteringAndTopPinnedMetrics() {
        let baselineCardHeight = WorkbenchControlMetrics.redesignCardBaselineHeight
        let cardPadding = WorkbenchControlMetrics.redesignSpacing4
        let buttonSize = WorkbenchControlMetrics.redesignIconButtonSize
        let buttonTopOffset = WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset

        // Top margin in baseline state
        let baselineTopMargin = cardPadding + buttonTopOffset
        // Bottom margin in baseline state
        let baselineBottomMargin = baselineCardHeight - (baselineTopMargin + buttonSize)

        // Baseline card must vertically center the 32px button (18px top, 18px bottom)
        #expect(baselineCardHeight == 68)
        #expect(buttonSize == 32)
        #expect(baselineTopMargin == 18)
        #expect(baselineBottomMargin == 18)
        #expect(baselineTopMargin == baselineBottomMargin)

        // Multi-line expanded card (e.g. text expands card height to 100px)
        let multiLineTopMargin = cardPadding + buttonTopOffset
        #expect(multiLineTopMargin == baselineTopMargin)
        #expect(multiLineTopMargin == 18)
    }

    @Test
    func renameSessionCurrentNameUsesFolderNameWithoutFullPath() {
        let rootSession = LibraryRenameSession(
            rootFolder: URL(fileURLWithPath: "/Volumes/Seagate/影视/Ave Mujica")
        )
        #expect(rootSession.currentName == "Ave Mujica")
        #expect(rootSession.newName == "Ave Mujica")

        let subfolderSession = LibraryRenameSession(
            folder: IndexedContentFolder(
                id: 1,
                relativePath: "Season 1/Ave Mujica",
                folderPath: "/Volumes/Seagate/影视/Season 1/Ave Mujica"
            )
        )
        #expect(subfolderSession.currentName == "Ave Mujica")
        #expect(subfolderSession.newName == "Ave Mujica")

        let filesSession = LibraryRenameSession(
            object: IndexedContentObject(
                id: 10,
                displayTitle: "Ave Mujica - EP01",
                videoPath: "/Volumes/Seagate/影视/Ave Mujica/EP01.mkv",
                videoName: "EP01.mkv",
                subtitles: [
                    IndexedContentSubtitle(
                        id: 20,
                        path: "/Volumes/Seagate/影视/Ave Mujica/EP01.sc.ass",
                        name: "EP01.sc.ass"
                    )
                ]
            )
        )
        #expect(filesSession?.currentName == "EP01")
        #expect(filesSession?.newName == "EP01")

        // WebDAV root folder with custom Name, subfolder, and file group
        let webdavRootURL = URL.fromMediaPath("http://192.168.1.173:5244/115/云下载/Ave Mujica")
        WebDAVConfigurationStore.shared.save(
            WebDAVRootConfig(
                rootPath: webdavRootURL.mediaPath,
                davRootPath: webdavRootURL.mediaPath,
                name: "母鸡卡",
                address: webdavRootURL.mediaPath,
                username: "",
                password: ""
            )
        )
        defer { WebDAVConfigurationStore.shared.remove(url: webdavRootURL) }

        let webdavRootSession = LibraryRenameSession(rootFolder: webdavRootURL)
        #expect(webdavRootSession.currentName == "母鸡卡")
        #expect(webdavRootSession.newName == "母鸡卡")
        webdavRootSession.newName = "BanG Dream! Ave Mujica"
        #expect(webdavRootSession.oldPaths == ["http://192.168.1.173:5244/115/云下载/Ave Mujica"])
        #expect(webdavRootSession.newPaths == ["http://192.168.1.173:5244/115/云下载/BanG Dream! Ave Mujica"])

        let webdavSubfolderSession = LibraryRenameSession(
            folder: IndexedContentFolder(
                id: 2,
                relativePath: "Season 1",
                folderPath: "http://192.168.1.173:5244/115/云下载/Ave Mujica/Season 1"
            )
        )
        #expect(webdavSubfolderSession.currentName == "Season 1")
        webdavSubfolderSession.newName = "Season 01"
        #expect(webdavSubfolderSession.newPaths == ["http://192.168.1.173:5244/115/云下载/Ave Mujica/Season 01"])

        let webdavFilesSession = LibraryRenameSession(
            object: IndexedContentObject(
                id: 11,
                displayTitle: "Ave Mujica - 01",
                videoPath: "http://192.168.1.173:5244/115/云下载/Ave Mujica/EP01.mkv",
                videoName: "EP01.mkv",
                subtitles: [
                    IndexedContentSubtitle(
                        id: 21,
                        path: "http://192.168.1.173:5244/115/云下载/Ave Mujica/EP01.sc.ass",
                        name: "EP01.sc.ass"
                    )
                ]
            )
        )
        #expect(webdavFilesSession?.currentName == "EP01")
        webdavFilesSession?.newName = "Episode 01"
        #expect(webdavFilesSession?.newPaths == [
            "http://192.168.1.173:5244/115/云下载/Ave Mujica/Episode 01.mkv",
            "http://192.168.1.173:5244/115/云下载/Ave Mujica/Episode 01.sc.ass"
        ])
    }
}

private func hexString(_ color: NSColor, appearance: NSAppearance.Name = .aqua) -> String {
    var resolved: NSColor?
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    guard let srgb = resolved else {
        return ""
    }
    let red = Int((srgb.redComponent * 255).rounded())
    let green = Int((srgb.greenComponent * 255).rounded())
    let blue = Int((srgb.blueComponent * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
}

private func alphaValue(_ color: NSColor, appearance: NSAppearance.Name = .aqua) -> CGFloat {
    var resolved: NSColor?
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    return resolved?.alphaComponent ?? 0
}
