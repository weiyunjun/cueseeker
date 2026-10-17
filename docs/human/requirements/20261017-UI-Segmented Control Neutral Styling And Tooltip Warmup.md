# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **Segmented Control 改为中性灰凹槽与浮起选中块样式（`C-02.4` & `UI Tokens.md`）**：
   - 移除原本使用 `macOS accent color` 的高饱和度选中块配色，统一改为无内部阴影的中性灰凹槽 + 亮面细边框选中块方案（严守 `UI Tokens.md`“容器内部元素不各自投射阴影”的规范），确保在 Workbench 顶栏（`#FFFFFF` / `#1C1C1F`）、Playback Overlay（`#FAFBFD` 或 `#F6F7F9` / `#18181B` 或 `#242426`）、Task 弹窗（`#FFFFFF` / `#36363B`）、Settings 卡片（`#F2F4F7` / `#242429`）四种表面上均有清晰层次：
   - **Token 定义与调整**：
     - `--color-segmented-control-bg`（新增，Container 背景）：Light `rgba(0,0,0,0.055)`；Dark `rgba(255,255,255,0.06)`。
     - `--color-segmented-control-border`（新增，Container 外边框，线宽 `--border-width-control: 1px`）：Light `transparent`；Dark `rgba(255,255,255,0.08)`。
     - `--color-segmented-control-selected-bg`（更新，选中项背景）：Light `#FFFFFF`；Dark `rgba(255,255,255,0.16)`。
     - `--color-segmented-control-selected-border`（新增，选中项边框，线宽 `--border-width-control: 1px`）：Light `#E5E7EB`（同 `--color-border-control`）；Dark `rgba(255,255,255,0.12)`。
     - `--color-segmented-control-selected-content`（更新，选中项文字颜色）：同 `--color-text-primary`（Light `#1F1F1F`；Dark `#E4E4E4`）。
     - `--color-segmented-control-unselected-content`（新增或复用 `--color-text-muted`，未选中项文字颜色）：同 `--color-text-muted`（Light `#717171`；Dark `#979797`），未选中项背景与边框均为 `transparent`。
   - **几何尺寸调整与交互**：外高 `--height-segmented-control: 36px`（与 `--height-control` 一致），内边距 `--padding-segmented-control: 3px`（选中项高度 `30px`），选项间距 `--gap-segmented-control: 2px`，外圆角 `--radius-control: 8px`，选中项圆角 `5px`，字号 `--font-size-segmented-control: 14px`（与 `--font-size-control` 一致），字重 `500`，各选项等宽，无 Hover 态变化。

2. **Tooltip 连续悬停免等待机制（Warmup / Skip Delay Window `300ms`）**：
   - **新增动效 Token**：在 `UI Tokens.md` 的 `Interaction Motion` 下新增 `--delay-tooltip-skip-window: 0.3s`（`300ms`）。
   - **交互状态机规则（`TooltipCenter`）**：
     - **首次悬停延迟**：当全局当前无已显示的 Tooltip 且未处于免等待时间窗内时，指针移入带有 Tooltip 的目标控件需保持满 `--delay-tooltip-hover`（`1s`）后才显示 Tooltip。
     - **开启免等待时间窗**：当某个 Tooltip **已经成功显示出来**，随后因**指针移出该目标控件热区（`hoverEnded`）**而隐藏时，记录该 Tooltip 消失的时间戳，开启时长为 `--delay-tooltip-skip-window`（`300ms`）的免等待时间窗。
     - **时间窗内立即显示**：若在当前 Tooltip 处于显示状态期间直接移入相邻目标，或在前一个已显示的 Tooltip 因移出而消失后的 **`300ms` 以内**移入另一个可显示 Tooltip 的目标控件热区，则**跳过 `1s` 等待，立即显示**新目标的 Tooltip。
     - **时间窗失效与重置**：
       1. 若指针移出前一个 Tooltip 后超过 `300ms` 仍未进入新的 Tooltip 目标，免等待时间窗自然过期，下次移入恢复 `1s` 等待；
       2. 若前一个悬停尚未满 `1s`（Tooltip 尚未显示出来）就移出，不开启免等待时间窗；
       3. 若 Tooltip 是因**鼠标按下/点击、滚轮滚动、键盘按键、打开菜单或对话框**而被动强制隐藏（`hideImmediately`），则立即清空免等待时间窗时间戳，下次悬停恢复完整的 `1s` 等待。

3. **设计文档同步**：
   - 待全部改动验收通过后，同步更新 `UI Tokens.md`、`UI Components - Controls.md`、`UI Interaction Rules.md` 与 `Tooltip Usage Registry.md`。

# 验收标准

1. Light 与 Dark 模式下，Workbench Recent 顶栏、Playback Overlay 顶栏、Task 弹窗、Settings 外观设置及 File 编辑弹窗中的 `WorkbenchSegmentedControl` 均呈现中性灰凹槽与亮面细边框选中块样式，不再出现彩色 Accent 选中块，无内部阴影。
2. 首次悬停带 Tooltip 的按钮满 `1s` 显示 Tooltip；移出该按钮后在 `300ms` 内移入相邻带 Tooltip 的按钮时，新 Tooltip 无需等待立即显示。
3. 移出按钮超过 `300ms` 后再移入新按钮，或点击按钮/按 Esc/打开菜单关闭 Tooltip 后再移入其他按钮，均恢复完整的 `1s` 悬停等待。