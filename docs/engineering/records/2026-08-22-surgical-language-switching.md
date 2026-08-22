# Surgical Language Switching Without A Full Interface Rebuild

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Problem

上一次提交里，切换语言靠的是给整棵主窗口视图树换一个身份，逼 SwiftUI 全部丢弃重建。
之所以要这么做，是因为取文案的入口是一个普通函数调用，SwiftUI 无从知道界面上哪些地方
依赖语言——语言变了，但它在观察的东西一个都没变，已经渲染好的界面没有任何理由重新计算。

代价是整窗口连同表格一起销毁重建：表格要重新测量行高、重新布局，产生明显闪烁，纯视图
内部状态（侧栏分组展开收起、表格滚动位置）也会被重置。

## Change

### 语言变成被观察的值

新增 `AppLocalizationStore`，只在语言真正变化时发布。语言的读取、持久化、解析新的语言
资源全部收拢到它身上，`SettingsStore` 只持有它，不再自己发布语言。

这一点是关键：语言此前挂在 `SettingsStore` 上，而 `SettingsStore` 被大量界面观察，任何
一次语言变化都会波及所有观察者，正是既有失效范围约束禁止的事。独立的 store 让失效边界
收敛到「真正显示文案的视图」。这与既有的 `CueGroupPresentationStore` 是同一种做法。

### 移除整体重建

主窗口和设置窗口两处 `.id(语言)` 一并删除。设置窗口改为由 `SettingsView` 观察
`AppLocalizationStore`（分类名要重新求值），语言分类自己也观察它并直接绑定到 store。
菜单栏仍然走通知重建，因为它是 AppKit 手工构建的，不参与 SwiftUI 失效。

关键文件：
- `Sources/CueSeekerApp/App/AppLocalization.swift`
- `Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `Sources/CueSeekerApp/Settings/SettingsView.swift`
- `Sources/CueSeekerApp/Settings/SettingsLanguageCategory.swift`
- `Sources/CueSeekerApp/Workbench/ContentView.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- 新增 `changingTheLanguagePublishesOnlyOnTheLocalizationStore`：切换语言时
  `AppLocalizationStore` 发布一次，`SettingsStore` 一次都不发布；同时断言语言被持久化、
  文案确实切换到新语言。这条用例把「不得整体重建」变成可回归的约束。
- `CueGroupRefreshScopeIntegrationTests` 与 `AppLocalizationTests` 单独运行：16 个用例中
  14 个通过，失败的两个是 `shioriTableStartsAtTopAfterPanelRemount` 与
  `showCueGroupInvalidationIsScopedToMountedShiori`，此前已通过把 `ContentView.swift`
  临时还原到基线对照确认为改动前就存在的失败。
- 整包 `swift test` 中 `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` 失败，
  但把本次改动 stash 掉、在 HEAD 上重跑整包同样失败，单独运行则稳定通过（0.4 秒 vs 整包
  下的 7 秒）。它是整包并行执行下的既有干扰，不是本次引入。
- Debug E2E 真机验证：先在侧栏把 Recent 分组收起（这个展开状态存在视图内部，整体重建会
  把它重置成默认展开），再打开设置、进入语言分类、点开下拉框并用方向键选中另一种语言。
  切换后设置窗口就地更新为新语言（分类名、标题、说明、下拉当前值），仍停留在语言分类；
  主窗口的 Recent 分组仍然是收起状态，说明视图树没有被重建。验证结束后偏好已删除，恢复
  默认跟随系统。

## Outcome

符合预期。

## 尚未覆盖的部分

需求第 4 条里「文字缓存在原生图层中的界面（搜索结果表格、媒体库表格、Shiori 表格、播放
字幕区）必须在切换后重画为新语言」这一句，本次无法验证，因为这些界面目前还没有任何
本地化文案。它们不参与 SwiftUI 失效，需要在各自被翻译的那几个提交里接上自己的重画通道，
并在那时验证。
