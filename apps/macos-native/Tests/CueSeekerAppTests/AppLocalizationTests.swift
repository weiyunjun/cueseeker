import AppKit
import Combine
import CueSeekerCore
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp

@Test
func eachLanguageResolvesItsOwnLocalizationBundle() {
    let expectedTitles: [AppLanguage: String] = [
        .english: "Language",
        .simplifiedChinese: "语言",
        .traditionalChinese: "語言"
    ]

    for (language, expectedTitle) in expectedTitles {
        let bundle = AppLocalization._bundleForTesting(language)
        #expect(
            bundle.localizedString(
                forKey: "settings.category.language",
                value: "",
                table: nil
            ) == expectedTitle
        )
    }
}

@Test
func followSystemResolvesToABundledLocalization() {
    let bundle = AppLocalization._bundleForTesting(.followSystem)
    let title = bundle.localizedString(
        forKey: "settings.category.language",
        value: "",
        table: nil
    )
    #expect(["Language", "语言", "語言"].contains(title))
}

@MainActor
@Test
func changingTheLanguagePublishesOnlyOnTheLocalizationStore() {
    withTemporaryLocalizationUserDefaults { userDefaults in
        let settings = SettingsStore(userDefaults: userDefaults)
        var settingsUpdates = 0
        var localizationUpdates = 0
        let settingsSubscription = settings.objectWillChange.sink { _ in
            settingsUpdates += 1
        }
        let localizationSubscription = settings.localization.objectWillChange.sink { _ in
            localizationUpdates += 1
        }

        settings.localization.set(.simplifiedChinese)

        // Only the localization store invalidates, so a language switch cannot
        // re-render every surface that observes SettingsStore.
        #expect(localizationUpdates == 1)
        #expect(settingsUpdates == 0)
        #expect(settings.localization.language == .simplifiedChinese)
        #expect(userDefaults.string(forKey: "appLanguage") == "zh-Hans")
        #expect(L("settings.category.language") == "语言")

        settings.localization.set(.followSystem)
        settingsSubscription.cancel()
        localizationSubscription.cancel()
    }
}

@MainActor
private func withTemporaryLocalizationUserDefaults(_ body: (UserDefaults) -> Void) {
    _ = NSApplication.shared
    let suiteName = "CueSeekerLocalizationTests-\(UUID().uuidString)"
    let userDefaults = UserDefaults.temporary(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
    }

    body(userDefaults)
}

@Test
func everyBundledLanguageDefinesTheSameKeys() {
    let english = localizableKeys(for: .english)

    #expect(!english.isEmpty)
    #expect(localizableKeys(for: .simplifiedChinese) == english)
    #expect(localizableKeys(for: .traditionalChinese) == english)
}

@Test
func singularCountKeysDoNotContainUnresolvedFormatPlaceholders() {
    for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
        let entries = localizableEntries(for: language)
        for (key, value) in entries where key.hasSuffix(".one") {
            #expect(!value.contains("%d"), "Key \(key) in \(language) should not contain %d: \(value)")
        }
    }
}

@Test
func simplifiedAndTraditionalChineseRefinedTranslationsMatchSpecification() {
    let zhHans = localizableEntries(for: .simplifiedChinese)
    #expect(zhHans["table.column.cues"] == "台词")
    #expect(zhHans["library.folder_count.one"] == "1 个文件夹")
    #expect(zhHans["excerpt.list_count.one"] == "1 个摘录集")
    #expect(zhHans["excerpt.list_count.other"] == "%d 个摘录集")
    #expect(zhHans["excerpt.cue_count.one"] == "1 条台词")
    #expect(zhHans["excerpt.cue_count.other"] == "%d 条台词")
    #expect(zhHans["excerpt.list.not_found"] == "该摘录集已不在媒体库中。")
    #expect(zhHans["library.recent_watching_empty"] == "还没有最近观看的视频。")
    #expect(zhHans["toast.table.cue_text_copied"] == "已复制台词文本")
    #expect(zhHans["playback.hud.cue_text_copied"] == "已复制台词文本")
    #expect(zhHans["toast.table.deep_links_copied"] == "已复制 Deep Links")
    #expect(zhHans["playback.more.audio_track"] == "音轨")
    #expect(zhHans["playback.more.no_audio_tracks"] == "无音轨")
    #expect(zhHans["playback.subtitle_menu.off"] == "关闭")
    #expect(zhHans["playback.hud.subtitle_switched"] == "字幕已切换")
    #expect(zhHans["playback.hud.loading"] == "加载中")
    #expect(zhHans["playback.hud.first_result"] == "已经是第一条结果")
    #expect(zhHans["playback.hud.last_result"] == "已经是最后一条结果")
    #expect(zhHans["playback.hud.seek_forward"] == "+ %d秒")
    #expect(zhHans["playback.hud.seek_backward"] == "- %d秒")
    #expect(zhHans["task.status.queued"] == "排队中")
    #expect(zhHans["task_detail.status.in_progress"] == "进行中")
    #expect(zhHans["task_detail.file_name"] == "文件名")
    #expect(zhHans["file_detail.associated_video"] == "关联视频")
    #expect(zhHans["file.add_folder.webdav"] == "WebDAV 文件夹")
    #expect(zhHans["webdav.dialog.title"] == "WebDAV 文件夹")
    #expect(zhHans["tooltip.playback.return_to_workbench"] == "返回工作台")
    #expect(zhHans["file.status.indexed"] == "已完成索引：%@")

    let zhHant = localizableEntries(for: .traditionalChinese)
    #expect(zhHant["table.column.cues"] == "台詞")
    #expect(zhHant["library.folder_count.one"] == "1 個資料夾")
    #expect(zhHant["excerpt.list_count.one"] == "1 個摘錄集")
    #expect(zhHant["excerpt.list_count.other"] == "%d 個摘錄集")
    #expect(zhHant["excerpt.cue_count.one"] == "1 條台詞")
    #expect(zhHant["excerpt.cue_count.other"] == "%d 條台詞")
    #expect(zhHant["excerpt.list.not_found"] == "該摘錄集已不在媒體庫中。")
    #expect(zhHant["library.recent_watching_empty"] == "尚無最近觀看的影片。")
    #expect(zhHant["toast.table.cue_text_copied"] == "已拷貝台詞文字")
    #expect(zhHant["playback.hud.cue_text_copied"] == "已拷貝台詞文字")
    #expect(zhHant["toast.table.deep_links_copied"] == "已拷貝 Deep Links")
    #expect(zhHant["toast.cue_not_in_library"] == "台詞不在媒體庫中")
    #expect(zhHant["toast.cues_not_in_library"] == "台詞不在媒體庫中")
    #expect(zhHant["toast.library.folder_not_in_library"] == "資料夾不在媒體庫中")
    #expect(zhHant["playback.hud.not_in_library"] == "台詞不在媒體庫中")
    #expect(zhHant["playback.more.audio_track"] == "音軌")
    #expect(zhHant["playback.more.no_audio_tracks"] == "沒有音軌")
    #expect(zhHant["playback.subtitle_menu.off"] == "關閉")
    #expect(zhHant["playback.hud.subtitle_switched"] == "字幕已切換")
    #expect(zhHant["playback.hud.loading"] == "加載中")
    #expect(zhHant["playback.hud.seek_forward"] == "+ %d秒")
    #expect(zhHant["playback.hud.seek_backward"] == "- %d秒")
    #expect(zhHant["playback.hud.exit_fullscreen"] == "退出全螢幕")
    #expect(zhHant["tooltip.player.fullscreen.exit"] == "退出全螢幕")
    #expect(zhHant["table.toolbar.exit"] == "退出")
    #expect(zhHant["playback.source.collage"] == "長截圖")
    #expect(zhHant["playback.collage.empty_hint"] == "選取台詞以預覽長截圖。")
    #expect(zhHant["tooltip.playback_overlay.return_to_playback"] == "返回播放")
    #expect(zhHant["facet.duration"] == "時長")
    #expect(zhHant["task.status.queued"] == "排隊中")
    #expect(zhHant["task_detail.status.in_progress"] == "進行中")
    #expect(zhHant["file_detail.associated_video"] == "關聯影片")
    #expect(zhHant["file.add_folder.webdav"] == "WebDAV 資料夾")
    #expect(zhHant["webdav.dialog.title"] == "WebDAV 資料夾")
    #expect(zhHant["tooltip.playback.return_to_workbench"] == "返回工作台")
    #expect(zhHant["tooltip.player.previous.video"] == "上一部影片")
    #expect(zhHant["tooltip.player.previous.video.disabled"] == "已經是第一部影片")
    #expect(zhHant["tooltip.player.next.video"] == "下一部影片")
    #expect(zhHant["tooltip.player.next.video.disabled"] == "已經是最後一部影片")
    #expect(zhHant["file.status.indexed"] == "已完成索引：%@")

    let en = localizableEntries(for: .english)
    #expect(en["playback.more.no_audio_tracks"] == "No Audio Tracks")
    #expect(en["playback.subtitle_menu.off"] == "Off")
    #expect(en["playback.hud.subtitle_switched"] == "Subtitle Switched")
    #expect(en["playback.hud.loading"] == "Loading")
    #expect(en["playback.hud.seek_forward"] == "+ %ds")
    #expect(en["playback.hud.seek_backward"] == "- %ds")
    #expect(en["file_detail.associated_video"] == "Video")
    #expect(en["file.add_folder.webdav"] == "WebDAV Folder")
    #expect(en["webdav.dialog.title"] == "WebDAV Folder")
}

@MainActor
@Test
func hdrScreenshotSettingLocalizationAndPersistence() {
    let en = localizableEntries(for: .english)
    let zhHans = localizableEntries(for: .simplifiedChinese)
    let zhHant = localizableEntries(for: .traditionalChinese)
    #expect(en["settings.appearance.hdr_screenshot"] == "HDR Screenshot")
    #expect(zhHans["settings.appearance.hdr_screenshot"] == "HDR 截图")
    #expect(zhHant["settings.appearance.hdr_screenshot"] == "HDR 截圖")

    withTemporaryLocalizationUserDefaults { userDefaults in
        let settings = SettingsStore(userDefaults: userDefaults)
        #expect(settings.hdrScreenshotEnabled == true)

        settings.hdrScreenshotEnabled = false
        #expect(userDefaults.bool(forKey: SettingsStore.hdrScreenshotEnabledKey) == false)

        let reloaded = SettingsStore(userDefaults: userDefaults)
        #expect(reloaded.hdrScreenshotEnabled == false)

        reloaded.hdrScreenshotEnabled = true
        #expect(userDefaults.bool(forKey: SettingsStore.hdrScreenshotEnabledKey) == true)
    }
}

@MainActor
@Test
func languageSwitchImmediatelyUpdatesMenusDialogSessionsAndPlaybackState() {
    withTemporaryLocalizationUserDefaults { userDefaults in
        let settings = SettingsStore(userDefaults: userDefaults)
        defer {
            settings.localization.set(.english)
        }

        settings.localization.set(.english)
        #expect(LibraryCoverContextMenuItem.title == "Change Cover")
        #expect(LibraryCoverEditingCopy.dialogTitle == "Edit Cover")
        #expect(LibraryCoverEditingCopy.chooseImageActionTitle == "Choose Image")
        #expect(LibraryCoverEditingCopy.cancelButtonTitle == "Cancel")
        #expect(LibraryCoverEditingCopy.saveButtonTitle == "Save")

        let excerptEditorSession = ExcerptListEditorSession(mode: .newList)
        excerptEditorSession.apply(
            validation: ExcerptListValidation(
                nameError: .emptyName,
                descriptionError: .descriptionTooLong(maximumCharacters: 200, currentCharacters: 201)
            )
        )
        #expect(excerptEditorSession.nameValidationMessage == L("excerpt.validation.name_required"))

        let renameSession = LibraryRenameSession(
            rootFolder: URL(fileURLWithPath: "/tmp/AveMujica", isDirectory: true)
        )
        renameSession.newName = ""
        _ = renameSession.validate()
        let renameHost = NSHostingView(
            rootView: LibraryRenameDialog(
                session: renameSession,
                onConfirm: {},
                onClose: {}
            )
        )
        renameHost.layoutSubtreeIfNeeded()
        #expect(renameSession.validationMessage == "Enter a name")

        let webdavSession = WebDAVFolderDialogSession()
        webdavSession.setValidationError(key: "webdav.error.invalid_address")
        let webdavHost = NSHostingView(
            rootView: WebDAVFolderDialog(
                session: webdavSession,
                onConfirm: {},
                onClose: {}
            )
        )
        webdavHost.layoutSubtreeIfNeeded()
        #expect(webdavSession.validationMessage == "Enter a valid WebDAV address")

        let ankiSession = AnkiExportSession(
            items: [],
            options: AnkiExportOptions(frontItems: [], backItems: []),
            folderURL: URL(fileURLWithPath: "/nonexistent-anki-export-folder", isDirectory: true),
            onOptionsChange: { _ in }
        )
        ankiSession.fileName = ""
        _ = ankiSession.validate()
        let ankiHost = NSHostingView(
            rootView: AnkiExportDialog(
                session: ankiSession,
                onChooseFolder: {},
                onExport: {},
                onClose: {}
            )
        )
        ankiHost.layoutSubtreeIfNeeded()
        #expect(ankiSession.validationMessage == "Enter a name")

        let confirmationSession = WorkbenchConfirmationSession(
            title: L("excerpt.delete_list"),
            message: L("excerpt.delete_list.message", "Favorites"),
            destructiveTitle: L("excerpt.delete"),
            cancelTitle: L("common.cancel"),
            onDestructive: {},
            onCancel: {}
        )
        #expect(confirmationSession.title == "Delete List")
        #expect(confirmationSession.actions.map(\.title) == ["Cancel", "Delete"])

        let playback = PlaybackStore(userDefaults: userDefaults)
        playback.showError(L("playback.error.not_in_library"), on: .notInLibrary)
        #expect(playback.chromeSnapshot.displayTitle == "No video selected")
        #expect(playback.errorMessages[.notInLibrary] == "This item is no longer in the library")

        let appearanceHost = NSHostingView(
            rootView: SettingsAppearanceCategory()
                .environmentObject(settings.localization)
                .environmentObject(settings)
        )
        appearanceHost.layoutSubtreeIfNeeded()
        let decodeControlHost = NSHostingView(
            rootView: SettingsDecodeCategory()
                .environmentObject(settings.localization)
                .environmentObject(settings)
        )
        decodeControlHost.layoutSubtreeIfNeeded()
        var renderedAppearanceTitles: [String] = []
        let segmentedHost = NSHostingView(
            rootView: WorkbenchSegmentedControl(
                options: AppAppearanceMode.allCases,
                selection: .constant(.auto),
                title: { mode in
                    let title = mode.displayName
                    if !renderedAppearanceTitles.contains(title) {
                        renderedAppearanceTitles.append(title)
                    }
                    return title
                },
                accessibilityLabel: { L("settings.appearance.accessibility", $0.displayName) }
            )
        )
        segmentedHost.frame = NSRect(x: 0, y: 0, width: 320, height: 80)
        segmentedHost.layoutSubtreeIfNeeded()
        #expect(renderedAppearanceTitles == ["Light", "Dark", "Auto"])

        settings.localization.set(.simplifiedChinese)
        excerptEditorSession.refreshLocalizedValidationMessages()
        renderedAppearanceTitles.removeAll()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        appearanceHost.layoutSubtreeIfNeeded()
        decodeControlHost.layoutSubtreeIfNeeded()
        segmentedHost.layoutSubtreeIfNeeded()

        #expect(renderedAppearanceTitles == ["浅色", "深色", "自动"])
        #expect(AppAppearanceMode.allCases.map(\.displayName) == ["浅色", "深色", "自动"])
        #expect(LibraryCoverContextMenuItem.title == "更换封面")
        #expect(LibraryCoverEditingCopy.dialogTitle == "编辑封面")
        #expect(LibraryCoverEditingCopy.chooseImageActionTitle == "选择图片")
        #expect(LibraryCoverEditingCopy.cancelButtonTitle == "取消")
        #expect(LibraryCoverEditingCopy.saveButtonTitle == "保存")
        #expect(excerptEditorSession.nameValidationMessage == L("excerpt.validation.name_required"))
        #expect(excerptEditorSession.descriptionValidationMessage == L("excerpt.validation.description_too_long"))
        #expect(renameSession.validationMessage == L("rename.validation.empty"))
        #expect(webdavSession.validationMessage == "请输入有效的 WebDAV 地址")
        #expect(ankiSession.validationMessage == L("rename.validation.empty"))
        #expect(ankiSession.locationValidationMessage == L("anki_export.validation.location_invalid"))
        #expect(ankiSession.frontValidationError == L("anki_export.validation.front_empty"))
        #expect(ankiSession.backValidationError == L("anki_export.validation.back_empty"))
        #expect(confirmationSession.title == "删除摘录集")
        #expect(confirmationSession.actions.map(\.title) == ["取消", "删除"])
        #expect(playback.chromeSnapshot.displayTitle == L("playback.no_video_selected"))
        #expect(playback.errorMessages[.notInLibrary] == L("playback.error.not_in_library"))
        playback.clearAllErrors()
    }
}

private struct AppearanceColorSchemeProbeView: View {
    let onColorSchemeRead: (ColorScheme) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = onColorSchemeRead(colorScheme)
        Color.clear.frame(width: 10, height: 10)
    }
}

@MainActor
@Test
func switchingAppAppearanceModeToAutoImmediatelySynchronizesWindowAndHostedViewsWithSystemAppearance() {
    withTemporaryLocalizationUserDefaults { userDefaults in
        let previousAppearance = NSApp.appearance
        defer {
            NSApp.appearance = previousAppearance
        }

        NSApp.appearance = nil
        let systemBestMatch = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let systemColorScheme: ColorScheme = systemBestMatch == .darkAqua ? .dark : .light

        let settings = SettingsStore(userDefaults: userDefaults)
        var observedColorScheme: ColorScheme?
        let titlebarView = DraggableNSView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        titlebarView.wantsLayer = true
        titlebarView.backgroundColor = WorkbenchRedesignColors.NS.bgSurface

        let hostingView = CueSeekerHostingView(
            rootView: VStack {
                SettingsAppearanceCategory()
                AppearanceColorSchemeProbeView { scheme in
                    observedColorScheme = scheme
                }
            }
            .environmentObject(settings.localization)
            .environmentObject(settings)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 480, height: 320)
        hostingView.addSubview(titlebarView)

        let window = CueSeekerWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        for sequence in [
            [AppAppearanceMode.light, .dark, .auto],
            [AppAppearanceMode.dark, .light, .auto],
        ] {
            for mode in sequence {
                settings.appAppearanceMode = mode
                hostingView.layoutSubtreeIfNeeded()

                let expectedMatch: NSAppearance.Name? = {
                    switch mode {
                    case .light:
                        return .aqua
                    case .dark:
                        return .darkAqua
                    case .auto:
                        return systemBestMatch
                    }
                }()
                let expectedScheme: ColorScheme = {
                    switch mode {
                    case .light:
                        return .light
                    case .dark:
                        return .dark
                    case .auto:
                        return systemColorScheme
                    }
                }()

                #expect(NSApp.appearance?.name == expectedMatch || (mode == .auto && NSApp.appearance == nil))
                #expect(NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expectedMatch)
                #expect(window.appearance == nil)
                #expect(hostingView.appearance == nil)
                #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expectedMatch)
                #expect(hostingView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expectedMatch)
                #expect(titlebarView.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expectedMatch)
                #expect(observedColorScheme == expectedScheme)
            }
        }
    }
}

/// Reads the keys a language actually ships, so a translation that is added to
/// one language but forgotten in another fails the build instead of silently
/// falling back to the key name at runtime.
private func localizableKeys(for language: AppLanguage) -> Set<String> {
    Set(localizableEntries(for: language).keys)
}

private func localizableEntries(for language: AppLanguage) -> [String: String] {
    let bundle = AppLocalization._bundleForTesting(language)
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings"),
          let entries = NSDictionary(contentsOfFile: path) as? [String: String]
    else {
        return [:]
    }
    return entries
}

/// The focus overlay renders localized copy, so hosting it outside the App
/// shell still needs a language store in the environment.
@MainActor
func makeTestAppLocalizationStore() -> AppLocalizationStore {
    AppLocalizationStore(
        language: .followSystem,
        userDefaults: ApplicationPersistence.sharedUserDefaults(),
        userDefaultsKey: "appLanguage"
    )
}
