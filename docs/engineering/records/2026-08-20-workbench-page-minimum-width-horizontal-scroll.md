# Workbench Page Minimum Width And Horizontal Scroll

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 内容区最小宽度部分。滚动条归属部分见
    `2026-08-20-workbench-page-scrollbar-ownership.md`。

## Rule

页面内任何组件到达自身最小宽度后，页面内容整体停止缩减，改为横向滚动，横向
Scrollbar 出现在页面视口底缘。右侧区域没有独立的最小宽度常量，最小宽度就是页面
内容自身的最小宽度。App 窗口最小宽度不变。

Search 与 Shiori 二级页面的表格列有最小宽度，因此会触发；其余页面内容可自适应
重排，目前不触发。展开 sidebar 只是让可用宽度变小，因而更早触发同一条规则。

## Problem

表格列压到最小宽度后只有表格自己横向滚动，页面标题、工具栏、Filter 面板继续被
压窄和重排（480pt 时 Filter 面板由 4 列重排为 2 列）。

## Change

1. `SubtitleTableView` 的 Page Chrome 视口改为与表格滚动视图同宽，Chrome 取
   表格内容宽度并跟随其横向偏移；表头保持视口位置，仍由自身列布局承担横向偏移。
2. `WorkbenchPageScrollbar` 发布所绑定滚动容器的横向内容宽度与偏移。
3. `SchemaWorkbenchSearchShell` 的非 Page Chrome 分支（Search）把标题、工具栏和
   Filter 面板收进一个统一的 Chrome 容器，按表格内容宽度定宽、按表格横向偏移位移，
   再按页面宽度裁剪。

## Notes

- Chrome 定宽必须在按页面宽度显式定宽的容器内完成。先前用
  `frame(maxWidth: .infinity)` 收口时，Chrome 的固定宽度会向上传播，使 VStack 变宽、
  表格视口和页面内边距一起失真。
- 横向几何的发布放到下一轮主队列：AppKit 在 SwiftUI 自身的更新过程中回调几何，
  在那里改动被观察的状态会重入读取它的视图体，导致 `Fatal access conflict`。
  代价是拖动横向 Scrollbar 时 Chrome 落后表格一帧。
- 三个宿主型用例放进 `.serialized` Suite，避免与彼此并行创建/销毁
  `NSHostingView` 时崩溃。

## Verification

- `swift build`、`swift build --build-tests` 通过。
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift` 新增：
  - Chrome 定宽后表格容器仍位于页面内边距处、宽度仍为页面宽减内边距；
  - 列到达最小宽度后文档宽度大于视口宽度，横向 Scrollbar 可滚到末端；
  - Page Chrome 随横向偏移位移、表头保持视口位置、横向几何被正确发布。
- 全量 `swift test`：失败项与改动前基线一致，没有新增失败，也没有崩溃。
- Debug E2E 真机验证：Search 480pt、Shiori 二级页 700pt，标题/封面/工具栏/Filter
  面板与表格一起停止缩减并被页面裁剪，横向 Scrollbar 位于窗口底缘。

## Outcome

符合预期。

## Reverted work

同一需求下先前提交的 `6e026f31`（按页面推导窗口最小宽度）理解有误：它抬高了 App
窗口最小宽度，使表格永远无法压到列最小宽度，横向 Scrollbar 不再出现。该提交已由
`47ad007c` 回退。
