# Search Page Chrome Clip Boundary

## Human-owned document

- `docs/human/requirements/20260820-UI-Workbench Page Scrollbar Ownership And Content Minimum Width.md`
  - 页面内容最小宽度第 4 条（页面各部分共用同一裁剪边界）。

## Problem

页面内容停止缩减后，Shiori 二级页的封面、工具栏与表格共用同一个裁剪窗口（左右各让出
页面内边距），三者在同一条竖线处被裁掉。Search 的 Chrome 裁在页面最右缘、表格却裁在
「页面宽 − 右侧内边距」处，两者相差一个页面内边距：Filter 面板一直画到窗口边缘，
表格提前停住，中间露出一条空白。

## Change

Search 的 Chrome 去掉自身的左右内边距，改为放进与表格滚动视口同宽的裁剪窗口，
再由该窗口统一施加页面内边距。Chrome 的定宽也随之由「表格内容宽 + 两侧内边距」
改为「表格内容宽」。

关键文件：`Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`

## Verification

- `swift build`、`swift test`：失败项与改动前基线一致，没有新增失败。
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift` 既有断言保持通过：
  表格容器仍位于页面内边距处、宽度仍为页面宽减两侧内边距。
- Debug E2E：Search `setWidth` 480 截图确认标题、搜索框、Filter 面板与表格在同一条
  竖线处被裁剪，右侧只剩与 Shiori 一致的页面内边距，不再出现宽窄不一的空白条；
  `setWidth` 1445 截图确认宽窗口下布局无变化。

## Outcome

符合预期。

## Abandoned approach

原计划是把 Search 的 Chrome 改由表格所在的原生滚动容器托管（与 Shiori 相同），
这样裁剪边界天然一致，横向位置也不必跨层传递，可以顺带消除 Chrome 落后表格一帧的
问题。实施后发现该托管方式要求固定区域声明**固定高度**，而 Search 的 Filter 面板
高度随宽度变化（网格列数会重排），固定高度会让面板溢出并与下方内容重叠。

Shiori 的 Filter 面板本来就被约束在固定高度上，Search 的则按自然高度增长——两页在
这一点上原本就不一致。要走原计划，必须先决定 Search 的 Filter 面板是否改为与 Shiori
相同的固定高度行为，这不在当前需求范围内。因此按计划中的退路只修裁剪边界，
Chrome 一帧延迟保留。
