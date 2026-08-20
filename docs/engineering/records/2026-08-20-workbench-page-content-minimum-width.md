# Workbench Page Content Minimum Width Without A Table

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 页面内容最小宽度第 8～9 条。

## Problem

不含表格的 Workbench 页面没有任何带最小宽度的组件，可用宽度变小时内容会一直被压缩
和重排。窗口处于最小宽度时展开 sidebar，右侧区域被压到只剩 sidebar 之外的部分，
页面内容随之收窄。

## Change

为不含表格的页面加上内容宽度下限：取「App 窗口处于最小宽度且 sidebar 收起时的右侧
区域宽度」，也就是 App 最小窗口宽度本身，在 `AppShellLayout` 内由既有 Token 推导，
不写死数值。

四个页面容器原本就在页面层用 `WorkbenchScrollView` 承载、Scrollbar 也已经画在页面
视口边缘，因此不新增机制，只做两处调整：滚动轴由纵向改为纵向 + 横向；内容宽度由
「等于可用宽度」改为「可用宽度与下限取大」。

关键文件：
- `Sources/CueSeekerApp/Workbench/ContentView.swift`（下限推导）
- `Sources/CueSeekerApp/Shared/LibraryOverviewComponents.swift`（Library 概览、Shiori 概览）
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`（Recent、Library 二级页）
- `Sources/CueSeekerApp/Data/DataView.swift`

不在范围内：Settings 窗口与 Playback 覆盖层虽然使用同一个滚动容器，但不是 Workbench
页面，未改动。

## Verification

- `swift build`、`swift test`：失败项与改动前基线一致，没有新增失败。
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift` 新增用例：可用宽度小于
  下限时，页面文档宽度等于下限，且横向 Scrollbar 存在。
- Debug E2E：窗口 `setWidth` 480 并展开 sidebar，Library 概览与 Data 页截图确认内容
  按下限完整渲染、未被压缩重排，底部出现横向滚动条。

## Outcome

符合预期。
