# Page Padding Inside The Table's Scroll Content

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 页面内容最小宽度第 11 条。

## Problem

含表格与不含表格的页面走了两套逻辑。不含表格的页面把整页内容连同左右内边距一起
作为滚动内容，滚动视口铺满整个右侧区域；含表格的页面把滚动视口左右各让出一个
内边距，内边距落在滚动区域外面。结果是含表格的页面右侧永远留着一条内边距宽的
空白，内容永远到不了窗口右缘，纵向 Scrollbar 左边总有一截固定空白。

## Change

页面内边距改由表格自己承担，放进滚动内容里：

1. 表格的滚动视口与 Page Chrome 视口不再让出内边距，直接铺满页面区域。
2. 文档宽度由「内容宽」改为「内容宽 + 两侧内边距」；列布局在唯一入口
   `tableColumnLayout(contentWidth:height:)` 里按「文档宽 − 两侧内边距」求解后整体
   右移一个内边距，行绘制、命中测试、Hover、文本选择、行内按钮都从该入口取列矩形，
   因此自动跟随。
3. 行 Hover / 选中背景与行分隔线按内容宽度收缩一个内边距，保持与封面、工具栏同宽；
   选择模式复选框的横坐标加上内边距。
4. Page Chrome 的横坐标改为「内边距 − 横向偏移」、宽度改为「文档宽 − 两侧内边距」。
5. `SubtitleTablePageChrome` 去掉 `horizontalInset`，内边距统一由
   `SubtitleTableView.horizontalContentInset` 提供，Search 与 Shiori 二级页各自传入
   同一个页面内边距 Token。
6. Search 页面的 Shell 不再由 SwiftUI 给表格容器加左右内边距，Chrome 的裁剪窗口
   恢复为整页宽度。

关键文件：
- `Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`

## Verification

- `swift build`、`swift test`：失败项与改动前基线一致，没有新增失败。
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift` 断言更新为统一后的几何：
  表格容器与滚动视口宽度等于整个页面宽度；文档宽度等于「列最小宽度之和 + 两侧
  内边距」；横向滚到末端时内容右边界与视口右边界重合；列矩形位于内边距之内；
  Page Chrome 宽度等于「文档宽 − 两侧内边距」并随横向偏移移动。
- Debug E2E：Search 480pt / 600pt 与 Shiori 二级页 600pt 截图确认左侧有内边距、
  内容一直画到窗口右缘、纵向 Scrollbar 左边不再有固定空白，横向 Scrollbar 位于
  窗口底缘，与不含表格页面表现一致。

## Outcome

符合预期。行 Hover / 选中高亮、行分隔线与选择模式复选框位置待项目 Owner 在真机上
最终确认。
