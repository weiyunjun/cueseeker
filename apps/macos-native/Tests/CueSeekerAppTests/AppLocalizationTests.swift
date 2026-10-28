import AppKit
import Combine
import Foundation
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
    #expect(zhHans["playback.more.default_audio_track"] == "默认音轨")
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
    #expect(zhHant["playback.more.default_audio_track"] == "預設音軌")
    #expect(zhHant["playback.hud.seek_forward"] == "+ %d秒")
    #expect(zhHant["playback.hud.seek_backward"] == "- %d秒")
    #expect(zhHant["playback.hud.exit_fullscreen"] == "退出全螢幕")
    #expect(zhHant["tooltip.player.fullscreen.exit"] == "退出全螢幕")
    #expect(zhHant["table.toolbar.exit"] == "退出")
    #expect(zhHant["playback.collage.exit"] == "退出")
    #expect(zhHant["tooltip.playback_overlay.collage.exit"] == "退出長截圖")
    #expect(zhHant["playback.collage.editing"] == "正在編輯長截圖⋯")
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
    #expect(en["playback.hud.seek_forward"] == "+ %ds")
    #expect(en["playback.hud.seek_backward"] == "- %ds")
    #expect(en["file_detail.associated_video"] == "Video")
    #expect(en["file.add_folder.webdav"] == "WebDAV Folder")
    #expect(en["webdav.dialog.title"] == "WebDAV Folder")
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
