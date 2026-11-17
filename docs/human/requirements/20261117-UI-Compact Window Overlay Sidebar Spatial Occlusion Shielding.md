# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **紧凑窗口 `Overlay` 侧边栏局部覆盖区域的交互屏蔽（`L-01.1`、`L-01.2`，禁止硬编码与私自特殊实现）**：
   - 当主窗口处于紧凑宽度（`< --min-width-workbench-page-content + --width-app-sidebar`）且展开左侧 `Overlay` 形态 `Sidebar` 时，在 `Sidebar` 实际覆盖的左侧区域（宽 `--width-app-sidebar`、窗口全高）内，统一屏蔽下层被遮挡的顶栏区域与工作台页面区域的一切指针视觉与选择响应（含控件/卡片/表格表头与表格行的 `Hover`、鼠标指针形状切换为 `Grab` 或 `I-beam`、下层控件 `Tooltip` 触发与滞留、跨区文本起选及下层滚动条悬停响应）。
   - 对于横跨 `Overlay` `Sidebar` 右侧边界的下层控件（即左半部分被 `Sidebar` 遮挡、右半部分露在右侧可见区域），鼠标从右侧可见部分水平滑入左侧 `Sidebar` 覆盖区域时，该下层控件的 `Hover` 与已显示的 `Tooltip` 立即结束；鼠标从左侧 `Sidebar` 覆盖区域水平滑出至该控件右侧露出部分时，立即激活该控件 `Hover` 并正常开始 `1s` `Tooltip` 计时。
   - 位于 `Overlay` `Sidebar` 之上的窗口红绿灯与左上角 `Sidebar Toggle` 按钮，以及 `Sidebar` 内部导航项自身，保持正常 `Hover`、点击与 `Tooltip` 交互；右侧未被 `Sidebar` 覆盖的顶栏与工作台页面区域维持正常悬停、点击、选词、滚动与 `Tooltip` 交互不变。
   - 展开或收起 `Sidebar` 时维持既有进入 `Hover` 抑制态并清除残留 `Hover` 的规则，鼠标实际移动后按当前指针所在的最上层可见区域实时判定 `Hover` 与指针样式。

2. **设计文档同步安排**：
   - 本次改动使紧凑窗口 `Overlay` `Sidebar` 的遮挡表现严格对齐现有 `UI Interaction Rules.md` 与 `UI Layouts - Workbench.md`；待视觉与交互验收完成后按需复核设计文档。

# 验收标准

1. **紧凑窗口 `Overlay` 侧边栏覆盖区零穿透验收**：
   - 将主窗口拉窄至 `Sidebar` 自动收起，在 `Search`、`Excerpt` 二级页、`Library`、`Recent` 与 `File` 页面点击左上角 `Sidebar Toggle` 展开 `Sidebar`：将鼠标在左侧 `Sidebar` 覆盖区域内上下移动并停留满 `1s`，底下被遮住的顶栏后退/前进按钮、搜索框、表格表头与表格行、封面卡片、文件卡片均不亮起 `Hover`、指针不变为手型或 `I-beam`、不弹出下层控件 `Tooltip`、从侧边栏内向右拖入表格或可选文字区域不触发跨区文本起选。
2. **横跨侧边栏右边界控件的滑入/滑出切换验收**：
   - 在 `Search` 页面勾选任意行进入批量选择模式，将主窗口拉窄至最小宽度并展开左侧 `Sidebar`（使批量操作行按钮横跨 `Sidebar` 右边界）：先在按钮右侧露出部分停留满 `1s` 弹出 `Tooltip`，再保持同一高度水平向左滑入 `Sidebar` 区域，下层按钮 `Hover` 与 `Tooltip` 立即消失；再从 `Sidebar` 内水平向右滑出至该按钮露出部分并停留满 `1s`，正常亮起 `Hover` 并弹出 `Tooltip`。
3. **侧边栏自身、左上角切换按钮与右侧露出区交互验收**：
   - `Overlay` `Sidebar` 展开期间，鼠标移至左上角 `Sidebar Toggle` 正常亮起 `Hover` 并在停留满 `1s` 后显示收起提示 `Tooltip`，点击 `Sidebar` 导航项正常切换页面；鼠标在右侧未被遮住的页面区域内悬停、点击、选词、滚轮滚动与触发 `Tooltip` 均正常响应。
