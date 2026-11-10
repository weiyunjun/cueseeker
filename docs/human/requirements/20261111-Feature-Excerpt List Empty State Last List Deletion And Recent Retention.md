# 版本

main

# 关联设计

- `docs/human/design/workbench/Excerpt and Export.md`
- `docs/human/design/playback/Playback Edge Cases.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Empty State Icon Registry.md`
- `docs/human/design/ui/Toast Usage Registry.md`

# 需求描述

1. **初始不创建默认摘录集与允许删除最后一个摘录集**
   - 全新初始化时不再自动创建名为 `Default` 的默认摘录集，初始摘录集数量为 `0`；已有数据升级时保留用户现有摘录集不变。
   - 移除“全局仅剩 1 个摘录集时禁用 `Delete List`”的限制：Excerpt 一级界面卡片菜单、Excerpt 二级界面更多菜单、Recent 界面与播放页 Command Panel 的摘录集卡片菜单中，`Delete List` 均正常可用；在 Excerpt 二级界面删除当前（包括最后一个）摘录集后自动退回 Excerpt 一级界面。
   - 没有任何摘录集时，在搜索结果或播放浮层触发保存到摘录集，弹出的目标菜单仅展示 `New List` 项（无分割线），新建完成后自动将目标台词保存至该摘录集。

2. **Recent Excerpt Lists 收录范围与历史播放分组规则**
   - Workbench 的 `Recent -> Excerpt Lists` 与播放页 `Command Panel -> Recent Excerpt Lists` 收录全部已存在的摘录集（含新建的空摘录集、全部摘录均失效的摘录集以及含有效摘录的摘录集）；仅当全局摘录集数量为 `0` 时展示空状态。
   - 摘录集在 Recent 中所属的时间分组（`Today` / `Yesterday` / `Last 7 Days` / `Earlier` / `Never Played`）仅由历史实际播放行为决定，与列表当前内容状态无关：
     - 从未实际播放过的摘录集归入 `Never Played`（组内按创建时间正序排列）；
     - 曾实际播放过的摘录集保持其最近一次实际播放时间对应的分组，不因列表内摘录全部失效或被清空而回退至 `Never Played`；
     - 尝试播放被拦截（未产生实际播放行为）时，不记录或刷新最近播放时间。

3. **无可用摘录时的展示、点击拦截与提示文案**
   - **Excerpt 二级界面顶部 `Cover Summary`**：
     - 界面已同步最新状态且列表内无任何有效摘录（含空列表或全部摘录失效）时，隐藏进度区域，主按钮显示为 `Disabled` 状态的 `Play` 按钮。
     - 界面处于未更新冻结状态，而后台变更已导致列表内无任何有效摘录时，点击 `Play` 或 `Resume` 按钮不进入播放页，直接在当前界面拦截并弹出右下角警告 Toast（持续 3 秒）。
   - **Recent Excerpt Lists 点击拦截**：
     - 在 Workbench `Recent -> Excerpt Lists` 或播放页 `Command Panel -> Recent Excerpt Lists` 中打开空的或无任何有效摘录的摘录集时，不进入播放（Command Panel 保持打开），直接拦截并弹出右下角警告 Toast（持续 3 秒）。
   - **无可用摘录提示文案**：
     - 上述三处点击拦截 Toast，以及播放摘录列表期间切集发现列表内已无任何有效摘录时的播放器左上角 1 秒 `Playback Feedback`（`warning` 图标），统一使用以下文案（搜索播放列表切集无可用项维持原 `No Available Results` 不变）：
       - 英文：`No Available Excerpts`
       - 简体中文：`没有可用的摘录`
       - 繁体中文：`沒有可用的摘錄`

4. **Excerpt 一级界面无摘录集引导空状态**
   - 当全局没有任何摘录集时，侧边栏与顶栏照常显示（顶栏标题为 `Excerpt`），隐藏顶部整个操作栏（搜索框、排序按钮、原 `+ New List` 按钮及统计数量），并清空残留的列表搜索词。
   - 在页面内容区水平、垂直居中展示引导空状态，自上而下依次为：
     1. **强调色摘录图标**：复用现有单层圆角燕尾书签空状态图标造型与尺寸，配色改为系统强调色（`macOS accent color`）。
     2. **引导提示文字**：复用搜索空白状态提示文字样式，文案为：
        - 英文：`Create an excerpt list to collect excerpts.`
        - 简体中文：`创建摘录集以收集摘录。`
        - 繁体中文：`建立摘錄集以收集摘錄。`
     3. **新建按钮**：复用原顶部操作栏的 `+ New List`（`Neutral` 按钮，带 `plus` 图标），点击打开新建摘录集对话框。

# 验收标准

1. **初始空状态与删除最后一个摘录集**：全新库启动后无默认 `Default` 摘录集，Excerpt 一级界面仅保留侧边栏与顶栏，正文居中展示强调色燕尾书签图标、提示文字与 `+ New List` 按钮；仅剩 1 个摘录集时各处菜单的 `Delete List` 均可正常点击删除，删空后 Excerpt 一级界面正确切换为引导空状态、两处 `Recent Excerpt Lists` 展示空状态，且保存台词菜单仅显示 `New List` 并可新建后保存。
2. **Recent 分组稳定性**：新建空摘录集出现在 `Recent Excerpt Lists` 的 `Never Played` 分组中；曾播放过的摘录集在内部摘录全部失效或被手动删空后，仍保留在原有的已播放时间分组中，不消失也不退回 `Never Played`。
3. **无可用摘录拦截与按钮状态**：在两处 `Recent Excerpt Lists` 点击空的或全部失效的摘录集，或在未刷新的 Excerpt 二级界面点击已全部失效摘录集的 `Play` / `Resume` 按钮时，均不进入播放、不更新播放时间（不跳入 `Today` 分组），并在右下角弹出 3 秒 `No Available Excerpts` / `没有可用的摘录` / `沒有可用的摘錄` Toast；刷新后的 Excerpt 二级界面对无有效摘录的列表隐藏进度条并展示禁用的 `Play` 按钮；播放摘录列表切集无可用项时左上角反馈同样显示该文案。