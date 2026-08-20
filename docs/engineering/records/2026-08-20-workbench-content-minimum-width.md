# Workbench Content Minimum Width

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 内容区最小宽度部分。滚动条归属部分见
    `2026-08-20-workbench-page-scrollbar-ownership.md`。

## Problem

窗口最小宽度是固定值，与当前页面和 sidebar 状态无关。窗口缩到最小后展开
sidebar，右侧内容区被继续压缩，含表格的页面会被挤到列最小宽度以下。

## Change

1. 新增 `Sources/CueSeekerApp/Workbench/WorkbenchContentMinimumWidth.swift`：
   由当前 `WorkbenchPanelMode` 和是否处于 Shiori 二级页推导内容区最小宽度。
   含表格页面取 `SubtitleTableColumnLayout.minimumContentWidth` 加两侧页面内边距，
   与表格实际列宽解析共用同一个函数；无表格页面取 App 最小窗口宽度。
   窗口最小宽度 = 内容区最小宽度 + sidebar 展开时的宽度。
2. `ContentView` 用该推导值同时驱动 SwiftUI 根视图的 `minWidth` 和主窗口的
   `minSize`，并在窗口比新的最小宽度窄时加宽窗口。全屏时不改窗口尺寸。
3. 删除按窗口宽度阈值自动收起 sidebar 的规则
   （`collapseSidebarForCompactWindowIfNeeded` 与 `sidebarAutoCollapseWindowWidth`）。

## Notes

`NSHostingView` 会把 SwiftUI 根视图的 `minWidth` 传播成窗口的内容最小尺寸，
只设置 `window.minSize` 会被它覆盖。两者必须来自同一个推导值，否则窗口最小宽度
会回落到 SwiftUI 声明的旧固定值。

自动收起规则与新规则直接冲突：无表格页面展开 sidebar 后的窗口最小宽度低于原
阈值，旧规则会在最小宽度处立刻把 sidebar 收起，使用户无法在最小宽度下保持
sidebar 展开。新规则已经从窗口最小宽度侧保证内容区不被压缩，旧阈值不再需要。

## Verification

- `swift build`、`swift build --build-tests` 通过。
- `Tests/CueSeekerAppTests/WorkbenchLayoutStateTests.swift` 新增两个用例：内容区
  最小宽度随页面变化（Search < Shiori 二级页；无表格页面等于 App 最小宽度），
  以及 sidebar 展开时窗口最小宽度按 sidebar 宽度累加而不是压缩内容区。原有两个
  自动收起用例随规则删除。
- 全量 `swift test`：失败项与改动前基线一致，没有新增失败。该环境下 NativePlayback
  媒体/音频、DebugE2EController 场景相关用例稳定失败，另有一组用例在并行执行下
  顺序敏感、单独执行全部通过。
- Debug E2E 真机验证（`setWidth` 请求 300pt，读取实际生效宽度）：
  - Search + sidebar 展开：914（674 + 240）
  - Search + sidebar 收起：674
  - Data + sidebar 展开：720（480 + 240）
  - Shiori 二级页 + sidebar 展开：1034（794 + 240）
  - 在最小宽度处点击 sidebar 开关：窗口由 674 加宽到 914，右侧内容区宽度不变。

## Outcome

符合预期。
