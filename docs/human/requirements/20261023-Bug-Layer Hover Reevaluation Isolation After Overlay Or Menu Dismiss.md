# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`

# 需求描述

1. **上层浮层或菜单关闭后的 `Hover` 恢复与层级隔离**：
   - 当更高层界面（如 Playback Overlay、Command Panel、对话框）或菜单关闭时，恢复为当前最上层的可交互界面必须立即根据当前指针位置重新判定 `Hover`（指针位于某控件上时立即呈现 `Hover`，不在其上时保持或退回 `Default`），且后续移动鼠标时该层所有控件的 `Hover` 与 Tooltip 均正常响应。
   - 仍被更高层界面遮挡的下层界面（例如播放页打开期间位于底层的 Excerpt 二级界面或 Search 界面）在被遮挡期间保持静默，不得因上层浮层或菜单的开关、滚动防抖结束而干扰当前最上层界面的 `Hover` 判定。

2. **保持同层菜单切换与退场时的 `Open` 态同步清除**：
   - 当菜单关闭或同一层级通过右键（或点击）切换至新菜单时，原触发按钮（如 `...` 按钮、排序按钮等）的菜单界面与灰色底高亮必须同步消失并退回 `Default` 态（仅当此时该层未处于菜单冻结且鼠标实际仍停留在原按钮上时，才进入 `Hover` 态）。

# 验收标准

1. 从 Excerpt 二级界面（或 Search 界面）点击任意台词进入播放页，按回车进入 Playback Overlay 再退出 Playback Overlay 后，将鼠标移至播放页顶栏或底栏的任意图标按钮上，按钮均立即正常显示 `Hover` 态，停留满延迟后正常显示 Tooltip。
2. 在播放页退出 Playback Overlay、Command Panel 或关闭播放器菜单的瞬间，若鼠标指针正停留在播放页顶栏或底栏某个按钮上，该按钮立即显示 `Hover` 态；若指针不在按钮上，按钮保持 `Default` 态。
3. 在 Excerpt 二级界面或 Search 界面点击 `...` 按钮或排序按钮打开菜单后，在下方字幕表格区域点击右键弹出表格右键菜单：原菜单与原按钮的灰色底高亮同步消失；关闭表格右键菜单或滚动表格停止满 `300ms` 后，侧边栏、顶栏、工具栏按钮与表格行的 `Hover` 均正常响应。