# 版本

main

# 关联设计

- `docs/human/design/workbench/Excerpt.md`
- `docs/human/design/playback/Playback Edge Cases.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **各界面摘录数量统一仅统计有效字幕（Available Cues）**：
   - **Recent Excerpt Lists**（含 Command Panel 最近摘录列表）封面卡片的 `xx cues`、**Excerpt 一级界面**顶部的总览统计（`xx lists  yy cues`）与各列表卡片的 `xx cues`、**Excerpt 二级界面**顶部封面右侧的 `xx excerpts` 与 `#x / y` 播放进度分母、**二级界面工具栏 Filter 按钮右侧**的 `xx excerpts`，以及 **Filter Dialog（筛选弹窗）** 内各筛选项旁边的数字与底部 `Show (xx)` 按钮数字，均**只统计有效字幕（不含失效字幕）**。
   - 若某个摘录列表仅剩失效字幕（有效字幕数为 `0`），Excerpt 一级界面卡片仍正常展示并显示 `0 cues`；Excerpt 二级界面顶部与筛选栏显示 `0 excerpts`，只要列表中仍存有摘录行（含失效行），表格正常展示表头与失效行（仅当列表没有任何摘录行时才隐藏表头并展示空状态提示）。

2. **Excerpt 二级界面表格中失效字幕的 `#` 列与位置规则**：
   - **位置不变**：失效字幕在 Excerpt 二级界面表格中的原有排列位置保持不变。
   - **`#` 列留空且不可勾选**：失效字幕行的 `#` 列**不显示数字**，且在鼠标悬停（Hover）或整表处于多选模式（Select Mode）下均**不变为复选框（Checkbox）**，不可被勾选。
   - **有效字幕序号连续递增**：`#` 列中有效字幕的序号跳过失效字幕行，仅在有效字幕行之间正常按 `+1` 连续递增。

3. **失效字幕 `Cues` 列左侧 `Unavailable` Badge（替换原右侧 `?` 图标）**：
   - **移除右侧 `?` 图标**：失效字幕在 `Cues` 列右侧不再显示 `?`（`question`）图标；仅“内容已变化但仍有效（Content Changed）”的字幕保留右侧 `clock-counter-clockwise` 图标（若某行同时发生内容变化与失效，以失效状态为准，仅展示左侧 `Unavailable` Badge）。
   - **展示左侧中性 `Unavailable` Badge**：在失效字幕 `Cues` 列主台词文字左侧展示中性 `Unavailable` Badge（文案随界面语言显示：英文 `Unavailable`、简体中文 `已失效`、繁体中文 `已失效`），悬停 Badge 时触发与原 `?` 图标相同的 4 项失效原因说明 Tooltip（`table.cue_state.unavailable`）。
   - **悬挂缩进对齐**：当主台词文字过长折行时，主台词的所有折行均对齐在 Badge 右侧（与首行主台词左对齐，不绕回 Badge 下方）；若开启 `Show Cue Group` 展示上下文扩展行，下方灰字扩展行仍从 `Cues` 列最左端（与 Badge 左边缘对齐）起始。
   - **Badge 视觉与新增 Tokens（`UI Tokens.md`）**：背景透明，高度 `--height-cue-unavailable-badge`: `20px`，圆角 `--radius-cue-unavailable-badge`: `4px`，水平内边距 `--padding-cue-unavailable-badge-x`: `6px`，与右侧主台词间距 `--gap-cue-unavailable-badge`: `6px`，字号 `--font-size-caption`（`12px`）、字重 Medium（`500`），边框 `1px solid var(--color-cue-unavailable-badge-border)`（Light `#717171` / Dark `#71717A`），文字颜色 `--color-cue-unavailable-badge-text`（Light `#1F1F1F` / Dark `#E4E4E4`）。

4. **页面已打开时后台数据库变更的冻结与刷新边界**：
   - **默认冻结**：当 `Recent`、**Excerpt 一级界面**或 **Excerpt 二级界面**处于已打开状态时，若后台完成 `Index` 或 `Remove Folder` 导致字幕失效或恢复，当前停留在屏幕上的界面保持冻结，不原地跳变数字、序号或突然显示/隐藏 `Unavailable` Badge，待离开页面再重新进入时刷新。
   - **主动更新操作解除冻结**：在 **Excerpt 二级界面**内输入/修改搜索词，或打开/修改 Filter 筛选条件时，以及在 **Recent 界面**点击顶栏 `Videos / Excerpt Lists` 分段切换时，均视为用户主动更新页面，直接拉取最新数据库状态刷新页面。
   - **冻结期单行移动/复制/删除（保持其余行冻结，局部更新数字）**：在冻结的 Excerpt 二级界面中，若对后台已失效的行执行移动或复制，直接拦截并弹出气泡提示 `This cue is no longer in the library`；若执行删除（或对仍有效的行执行移动），仅将当前行从表格移除，其余行继续保持冻结；顶部与筛选栏的有效字幕数按被移除行在当前界面上的显示状态局部更新（界面上显示为有效则 `-1`，界面上已显示 `Unavailable` Badge 则保持不变），且在离开页面解冻前不覆盖刷新顶部的播放进度。
   - **冻结期点击列表播放但已无任何有效台词**：当用户在冻结的 `Recent` 摘录卡片或 **Excerpt 二级界面**顶部点击 `Play` / `Resume`，而该列表在后台实际上已无任何有效台词可播时，统一进入播放页黑屏并在顶栏展示红色报错横幅 `This item is no longer in the library`。

# 验收标准

1. **有效字幕数量统计准确**：当摘录列表中包含失效字幕时，Recent 摘录列表卡片、Command Panel 最近摘录列表、Excerpt 一级界面顶部总览与卡片、Excerpt 二级界面顶部摘要与 `#x / y` 进度分母、工具栏 Filter 按钮右侧计数、以及 Filter 弹窗内各筛选项数字与底部 `Show (xx)` 按钮数字，均只统计有效字幕；若列表内全部为失效字幕，数字显示为 `0`，二级界面表格仍正常显示表头与失效行。
2. **`#` 列序号与勾选行为正确**：Excerpt 二级界面表格中，失效字幕保持原有位置不变，其 `#` 列为空白，悬停或多选模式下均不出现复选框且无法被勾选；有效字幕行的 `#` 序号跳过失效行连续 `+1` 递增（如第 1 行有效、第 2 行失效、第 3 行有效，则 `#` 列依次显示 `1`、空白、`2`）。
3. **`Unavailable` Badge 样式、多语言、对齐与 Tooltip 正确**：失效字幕行不再显示右侧 `?` 图标，改为在 `Cues` 列主台词左侧显示 `20px` 高、`4px` 圆角、透明背景带中性边框的 `Unavailable` / `已失效` Badge；主台词多行折行时保持悬挂缩进对齐于 Badge 右侧，`Show Cue Group` 上下文扩展行与 Badge 左边缘对齐；悬停 Badge 正常弹出失效原因 Tooltip。
4. **后台变更冻结与解冻边界符合预期**：停留在 Recent 或 Excerpt 一/二级界面期间后台移除文件夹或重新索引，当前界面保持冻结；在 Excerpt 二级界面输入搜索词、打开/修改筛选条件，或在 Recent 顶栏切换 `Videos / Excerpt Lists` 时，页面立即更新为最新状态；冻结期删除已显示 `Unavailable` 的行时有效数不变，删除当前显示为有效的行时有效数 `-1` 且其余行保持冻结；冻结期点击已无有效台词的列表播放时，进入播放页黑屏并显示顶栏红色报错横幅。