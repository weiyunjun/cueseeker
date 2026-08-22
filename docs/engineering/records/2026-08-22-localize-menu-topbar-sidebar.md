# Localize The Menu Bar, Topbar And Sidebar

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Problem

需求覆盖范围里的第一批界面：菜单栏、顶栏与侧栏。此前全部是硬编码英文。

## Change

### 菜单栏与窗口标题

菜单栏的 15 条文案改为按当前语言取值，「退出」一项用格式串拼上本地化的应用名，因此
中文下是「退出字幕求索」。主窗口标题改为本地化应用名，设置窗口标题改为本地化的「设置」。

菜单栏和窗口标题都是 AppKit 状态，不参与 SwiftUI 失效，所以在语言变化的通知处理里一起
刷新，而不是各自去观察。

### 顶栏与侧栏

顶栏的返回按钮、边栏开关，以及侧栏的全部导航项、分组展开收起、底部设置项改为按当前语言
取值。侧栏导航项的文字来自 `WorkbenchPanelMode.sidebarLabel`，在那里一次性本地化，六个
入口共用。

`AppTopBar` 与 `AppSidebar` 观察语言存储，语言变化时只有这两棵子树重新求值，其余界面
不受影响。

关键文件：
- `Sources/CueSeekerApp/App/AppDelegate.swift`
- `Sources/CueSeekerApp/App/WorkbenchLayoutState.swift`
- `Sources/CueSeekerApp/Workbench/ContentView.swift`

### 一处刻意不翻译

`TitlebarBackgroundView` 里出现的 `Maximize` 与 `Minimize` 不是界面文案，而是读取 macOS
系统偏好 `AppleActionOnDoubleClick` 时用于比较的取值。翻译它们会让「双击标题栏」的行为
判断失效，因此保持原样。

## Verification

- `swift build --product CueSeeker` 通过。
- `CueGroupRefreshScopeIntegrationTests`、`AppLocalizationTests` 等 65 个用例运行：除
  `shioriTableStartsAtTopAfterPanelRemount` 与 `showCueGroupInvalidationIsScopedToMountedShiori`
  两个改动前就存在的失败外全部通过。托管 `ContentView` 的测试补上了语言存储的注入。
- Debug E2E 真机验证：英文状态下截图，再在设置里用下拉框切到简体中文，不重启直接截图。
  侧栏实时变为「搜索 / 最近 / 最近视频 / 最近 Shiori / 媒体库 / 数据 / Shiori」，底部
  设置项变为「设置」；场景信息里主窗口标题变为「字幕求索」、设置窗口标题变为「设置」，
  说明语言变化的通知处理确实执行了。验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 未能自动验证的部分

菜单栏本身不属于窗口，Debug E2E 的 `capture` 只截窗口并集，截不到它。本次的间接证据是：
窗口标题和菜单栏在同一个语言变化处理函数里刷新，而窗口标题已被证实实时更新，因此菜单栏
的重建同样执行了；菜单项文案走的是与其它界面相同的取文案入口。菜单项的实际显示需要人工
打开菜单确认。

另外，macOS 应用菜单最左侧那个粗体的应用名来自 App 包自身的名称，由系统语言决定，不受
应用内语言设置控制，因此它仍显示 `CueSeeker`。需求里的「应用名」一行已在菜单项、窗口
标题等我们能控制的位置生效。
