# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **可划选截断文本的 `Tooltip` 触发与选词互斥规则（`L-05.4`、`L-09.2`、`L-06.9`，禁止硬编码与私自特殊实现）**：
   - `Command Panel` 二级界面顶部标题（`Search Results`、`Recent Videos`、`Recent Excerpt Lists`）、`Search` 与 `Excerpt` 表格工具栏批量选择模式下的中间提示文本、以及对话框单行截断标题，均以文本实际渲染是否发生 `...` 省略为准决定是否启用 `Tooltip`；未发生省略时不触发。
   - 当上述文本实际发生省略时，鼠标移入文本热区或从界面切换/按键抑制中在文本热区内实际移动鼠标并停留满 `1s`（`--delay-tooltip-hover`），正常弹出完整文本 `Tooltip`（最大宽度 `--width-tooltip-max`，超出自动折行，适配当前明暗模式）。
   - 当鼠标点击、滚轮滚动或按键隐藏已显示的 `Tooltip` 后，无需先将鼠标移出该文本热区，只要在热区内再次实际移动鼠标并停留满 `1s`，即重新计时并再次显示 `Tooltip`（不触发免等待瞬时弹出）。
   - 按住鼠标左键（含拖拽划选文字期间）不启动计时、不弹出任何 `Tooltip`；拖选省略文本并复制仍完整还原未截断原文本。

2. **`Tooltip` 全局悬停抑制与遮挡门禁统一**：
   - 新打开对话框、`Task` 面板、`Command Panel`、弹出菜单，或发生界面/层级/分段切换、输入框打字进入 `Hover` 抑制态期间，预先停留在新界面控件（如弹窗右上角关闭按钮 `X`）上的静止鼠标不触发 `Tooltip`；待鼠标实际移动后按 `1s` 延迟正常计时显示。
   - 全界面常规按钮、禁用态原因提示、表格行状态图标及非可划选截断标题的 `Tooltip` 延迟展示、`0.3s`（`--delay-tooltip-skip-window`）跨目标免等待切换及失焦暴露窗口响应均保持既有规范不变。

3. **设计文档同步安排**：
   - 本次改动使实际表现严格符合现有 `UI Interaction Rules.md` 与 `Tooltip Usage Registry.md`；待验收完成后按需复核设计文档。

# 验收标准

1. **`Command Panel` 二级页超长搜索词标题 `Tooltip` 验收**：
   - 在播放页打开 `Command Panel`，输入超长搜索词按回车进入 `Search Results` 二级页使顶部标题出现 `...` 省略：无论进入前鼠标原本停在顶部标题区域内随后微移鼠标，还是从外部移入标题区域，停留满 `1s` 均正常弹出完整搜索词 `Tooltip`；点击、按键或滚轮隐藏后不移出标题直接在文字内移动鼠标满 `1s` 可再次弹出；按住左键选词不松手停留超过 `1s` 全程不弹 `Tooltip`，复制可得完整搜索词；短搜索词未省略时不弹出。
2. **表格批量选择横幅省略提示语 `Tooltip` 验收**：
   - 将主窗口拉窄至最小宽度，在 `Search` 一级页与 `Excerpt` 二级详情页勾选任意行进入批量选择使工具栏中间提示语出现 `...` 省略：鼠标移入或在提示语内移动并停留满 `1s` 正常弹出完整提示语 `Tooltip`；点击或按键打断后在文字内微移满 `1s` 再次弹出；按住左键选词超过 `1s` 不弹 `Tooltip`；拉宽窗口使提示语完整显示后不弹出。
3. **静止指针打开弹层不误弹 `Tooltip` 验收**：
   - 将鼠标预先停在即将弹出的对话框右上角关闭按钮 `X` 位置保持不动，通过快捷键或键盘回车触发打开对话框并等待超过 `1s`：静止期间既不亮起 `Hover` 也不弹出 `Close Esc` `Tooltip`；实际移动鼠标并停留满 `1s` 后正常显示。