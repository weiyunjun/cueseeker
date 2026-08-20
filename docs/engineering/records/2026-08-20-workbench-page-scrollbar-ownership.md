# Workbench Page Scrollbar Ownership

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 滚动条归属部分。内容区最小宽度部分由后续变更实现。

## Problem

Search 页面的 Scrollbar Overlay 被约束到表格自己的 `NSScrollView`：纵向条画在
表格内部、并且从表头下方才开始，横向条画在表格底部。Shiori 二级页面因为使用
Page Chrome 承载，Overlay 被约束到整页容器，位置正确，但所有权仍在表格代码里。

## Change

1. 新增 `Sources/CueSeekerApp/Shared/WorkbenchPageScrollbar.swift`：
   - `WorkbenchPageScrollbar` 由页面持有，显式绑定表格发布上来的真实滚动容器；
   - `WorkbenchPageScrollbarOverlay` 在页面视口层渲染既有的
     `SubtitleTableScrollbarOverlayView`；
   - `EnvironmentValues.workbenchPageScrollbar` 把页面持有的实例传给表格。
2. `SubtitleTableView` 不再创建、添加或约束任何 Scrollbar Overlay。它只把自己的
   `NSScrollView` 注册给页面持有的 `WorkbenchPageScrollbar`，并在滚动几何变化时
   通知它。Thumb 拖动状态回调保持原有的 hover 抑制行为。
3. `SchemaWorkbenchSearchShell` 持有 `WorkbenchPageScrollbar`，在两条布局分支
   之上统一渲染页面级 Overlay，Search 与 Shiori 二级页面共用同一条路径。

Scrollbar 的绘制几何、尺寸 Token、命中区域和交互全部沿用
`TableScrollbarPrimitive`，没有新增第二套 Primitive。

## Verification

- `swift build`、`swift build --build-tests` 通过。
- 新增 `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift`：在真实
  SwiftUI 宿主里断言 Overlay 不是表格容器或滚动视图的后代、表格容器内不再存在
  任何 `TableScrollbarOverlayView`、Overlay 覆盖整个页面视口且大于表格滚动视口、
  纵横 Thumb 分别贴页面视口右缘与底缘。
- `Tests/CueSeekerAppTests/SubtitleTableVirtualRowTests.swift` 改用页面持有的
  Scrollbar 装配表格；`pageChromeFramesForTesting()` 不再返回 Overlay 边界。
- 全量 `swift test`：失败项与改动前基线一致（NativePlayback 媒体/音频相关、
  DebugE2EController 场景相关、以及并行执行下的 UI 计数顺序敏感用例），
  没有新增失败。
- Debug E2E 真机验证：`swift run CueSeeker --cueseeker-debug-e2e`，
  `setWidth` 700 时纵向条位于窗口右缘并自页面顶部开始；`setWidth` 480 时横向条
  位于窗口底缘并横跨整页宽度。

## Outcome

符合预期。表格区域内部不再出现 Scrollbar，Search 与 Shiori 二级页面的
Scrollbar 位置一致。

## Notes

- `SubtitleTableView` 的 `isRedesign == false` 旧路径已无调用方，属于本次改动
  之前就存在的死代码，未在本次删除。
- `Shared/WorkbenchTable/WorkbenchDataTable.swift` 同样已无调用方，未改动。
