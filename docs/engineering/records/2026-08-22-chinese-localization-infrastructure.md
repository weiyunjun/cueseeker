# Chinese Localization Infrastructure And Settings Language Category

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Problem

App 此前完全没有本地化基础：没有任何本地化查找、没有语言资源文件，全部界面文字都是
硬编码英文。需求要求支持 English、简体中文、繁體中文，默认跟随系统，并且切换语言即时
生效、不需要重启。本次是需求的第一步，只建立文案通道和「语言」设置分类，不翻译其它
界面文字。

## Change

### 语言资源与查找

三份 `Localizable.strings` 放在 `Sources/CueSeekerApp/Resources/` 下的
`en.lproj`、`zh-Hans.lproj`、`zh-Hant.lproj`。`Package.swift` 增加
`defaultLocalization: "en"`，`CueSeekerApp` target 增加 `.process("Resources")`。

文案统一走 `Bundle.module`（不是 `Bundle.main`），因此开发期直接跑可执行文件和打包后的
`.app` 行为一致，也不依赖 macOS 的「按 App 设置语言」。SwiftPM 生成资源 bundle 时会把
`.lproj` 目录名小写化（`zh-Hans.lproj` → `zh-hans.lproj`），所以查找按大小写不敏感匹配
`Bundle.module.localizations`，而不是直接用规范的 BCP-47 名字取路径。

关键文件：
- `Sources/CueSeekerApp/App/AppLocalization.swift`

### 语言选择与即时切换

`AppLanguage` 有四个取值：`followSystem`、`en`、`zh-Hans`、`zh-Hant`。`followSystem` 用
`Bundle.preferredLocalizations(from:)` 对随包语言做匹配，匹配不到回落英文。选择值由
`SettingsStore` 持久化到 `com.cueseeker.shared` 的 `appLanguage`，默认 `followSystem`。

切换不重启靠两件事：主窗口视图树按 `.id(appLanguage)` 取得新身份，语言变化时整棵树重建，
所有已解析的文案重新求值；菜单栏是 AppKit 手工构建的，不参与 SwiftUI 失效，因此由
`SettingsStore` 发一条 `cueSeekerAppLanguageChanged` 通知，`AppDelegate` 收到后重建菜单。

`.id()` 挂在 `ContentRootView` 内部而不是外层 `ContentView`。外层挂会让 `ContentView`
额外观察 `SettingsStore`，把 `SettingsStore` 的任意 `@Published` 变化都变成一次
`ContentView`/`AppSidebar` 重绘，直接违反既有的失效范围约束（
`searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` 会失败）。`ContentRootView`
本来就观察 `SettingsStore`，挂在它内部不新增任何观察边。

关键文件：
- `Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `Sources/CueSeekerApp/Workbench/ContentView.swift`
- `Sources/CueSeekerApp/App/AppDelegate.swift`

### 设置「语言」分类

新增分类使用地球图标，位于「Search」之下、「Deep Link」之上，内容是一个原生下拉框，
选项顺序为跟随系统 / English / 简体中文 / 繁體中文。三个具体语言名按惯例用各自语言书写，
只有「跟随系统」随界面语言变化。分类内容区按 `.id(appLanguage)` 重建，因此语言切换后
设置窗口自身也立刻更新，同时保留当前选中的分类。

关键文件：
- `Sources/CueSeekerApp/Settings/SettingsLanguageCategory.swift`
- `Sources/CueSeekerApp/Settings/SettingsView.swift`

### 打包

SwiftPM 生成的 `CueSeekerNative_CueSeekerApp.bundle` 由打包脚本复制进
`CueSeeker.app/Contents/Resources/`，缺失时打包直接失败。`Info.plist` 声明
`CFBundleLocalizations`。校验脚本增加两项检查：资源 bundle 存在，且三种语言的
`Localizable.strings` 都在包内。

关键文件：
- `scripts/package_macos_app.sh`
- `scripts/verify_macos_app_bundle.sh`
- `packaging/macos/Info.plist`

## Verification

- `swift build --product CueSeeker` 通过。
- 新增 `AppLocalizationTests`：三种语言各自解析到自己的 `.lproj` 并返回预期文案；
  `followSystem` 解析到随包语言之一。两个用例通过。这一层专门锁住上面提到的 `.lproj`
  目录名小写化问题。
- 整包 `swift test`（1015 个用例）：失败项与改动前基线同类，都是既有的环境相关不稳定
  用例（音频设备、窗口尺寸、滚动锚点）。其中
  `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` 曾因 `.id()` 挂错层级而
  失败，移到 `ContentRootView` 内部后恢复通过；`shioriTableStartsAtTopAfterPanelRemount`
  与 `showCueGroupInvalidationIsScopedToMountedShiori` 经过对照验证（临时还原
  `ContentView.swift` 到 HEAD 后重跑）确认为改动前就存在的失败，不是本次引入。
- Debug E2E（`--cueseeker-debug-e2e`，点击侧栏「Settings」再点第 5 个分类后 `capture`）：
  - 默认（跟随系统，英文环境）：分类名 `Language`，地球图标，位置在 Search 与 Deep Link
    之间；标题 `Language`，说明 `Choose the language used by CueSeeker.`，下拉显示
    `Follow System`。
  - `appLanguage=zh-Hans`：分类名与标题为「语言」，说明为「选择字幕求索使用的语言。」，
    下拉显示「简体中文」。
  - `appLanguage=zh-Hant`：分类名与标题为「語言」，说明为「選擇字幕求索使用的語言。」，
    下拉显示「繁體中文」。
- 打包路径：`scripts/package_macos_app.sh` 成功，校验脚本通过，`.app` 内确实带上
  `Contents/Resources/CueSeekerNative_CueSeekerApp.bundle` 与三份
  `Localizable.strings`。把 debug 可执行文件放进同一个 `.app` 目录结构后重跑 E2E，
  简体中文文案正常显示，证明 `Bundle.module` 能从 `Contents/Resources` 解析到资源，而不
  只是文件被复制进去了。

## Outcome

符合预期。

## 自动化缺口

原生下拉菜单（`NSMenu` 弹出窗口）无法用 Debug E2E 的 `click` 命中，`keyPress` 也没有可用
的替代路径，因此「在界面上选中某个语言」这一步不能自动化。本次改为直接写
`com.cueseeker.shared` 的 `appLanguage` 后重启 App 截图，覆盖的是「持久化选择 → 解析
bundle → 界面文案」这条真实路径，但不包含下拉框本身的点击选中。验证结束后该偏好已删除，
恢复默认的跟随系统。
