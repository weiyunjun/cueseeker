# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Toast Usage Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/workbench/Excerpt and Export.md`
- `docs/human/design/workbench/Search and Filter.md`
- `docs/human/design/data/Data.md`

# 需求描述

1. **批量选择工具栏（Select Mode 第 2 行）新增摘录批量操作按钮与自动换行布局（`L-05.4 Search / Excerpt Toolbar Layout`、`L-05.3 Excerpt List Detail Layout`）**：
   - **Search 表格（Select Mode 第 2 行）**：从左到右依次排列 4 个按钮：
     1. `Export to Anki`（`Button / Neutral`，图标 `export`，快捷键 `A`）
     2. `Copy Deep Links`（`Button / Neutral`，图标 `link-simple`，快捷键 `D`）
     3. `Copy Table`（`Button / Neutral`，图标 `copy`，快捷键 `T`）
     4. `Save to Excerpt List`（`Button / Neutral`，图标 `arrow-right`，快捷键 `S`，文案随语言显示 `Save to Excerpt List` / `保存到摘录集` / `儲存到摘錄集`）
   - **Excerpt 表格（Select Mode 第 2 行）**：从左到右依次排列 6 个按钮：
     1. `Export to Anki`（`Button / Neutral`，图标 `export`，快捷键 `A`）
     2. `Copy Deep Links`（`Button / Neutral`，图标 `link-simple`，快捷键 `D`）
     3. `Copy Table`（`Button / Neutral`，图标 `copy`，快捷键 `T`）
     4. `Move to ...`（`Button / Neutral`，图标 `arrow-right`，快捷键 `M`，文案随语言显示 `Move to ...` / `移动到…` / `移動至⋯`）
     5. `Duplicate to ...`（`Button / Neutral`，图标 `arrow-right`，快捷键 `C`，文案随语言显示 `Duplicate to ...` / `复制到…` / `複製至⋯`）
     6. `Remove Excerpt`（`Button / Destructive`，图标 `bookmark-simple`，快捷键 `R`，文案随语言显示 `Remove Excerpt` / `移除摘录` / `移除摘錄`）
   - **窗口缩小时自动换行与吸顶联动**：
     - 当窗口宽度不足以在单行容纳第 2 行全部批量操作按钮时，超出部分按从左到右顺序自动折入下一行并保持左对齐；同行按钮水平间距为 `--spacing-4`，折行后的上下行间距为 `--spacing-2`，每行高度为 `--height-control`。
     - 在 Excerpt 详情页中，当第 2 行按钮因换行变为多行时，吸顶工具栏区域高度同步动态增加，下方表头与表格内容同步下移，不遮挡表头。

2. **快捷键、Tooltip 与目标摘录集菜单交互（`C-01.1`、`C-04.2 Excerpt Destination Menu`、`UI Interaction Rules.md` §4.9–§4.10、`Tooltip Usage Registry.md`）**：
   - **单键快捷键与悬停 Tooltip**：
     - 在表格批量选择状态下（且无弹窗/菜单打开、焦点不在输入框内），按 `S`（Search）或 `M` / `C` / `R`（Excerpt）触发对应批量操作。
     - 鼠标悬停满 1 秒展示带固定英文快捷键后缀的 Tooltip：
       - `Save to Excerpt List (S)` / `保存到摘录集 (S)` / `儲存到摘錄集 (S)`
       - `Move to ... (M)` / `移动到… (M)` / `移動至⋯ (M)`
       - `Duplicate to ... (C)` / `复制到… (C)` / `複製至⋯ (C)`
       - `Remove Excerpt (R)` / `移除摘录 (R)` / `移除摘錄 (R)`
   - **目标摘录集菜单（`Excerpt Destination Menu`）**：
     - 点击 `Save to Excerpt List`、`Move to ...`、`Duplicate to ...` 按钮（或按对应快捷键 `S` / `M` / `C`）时，在触发按钮正下方左对齐弹出 `Excerpt Destination Menu`（下方空间不足时朝上展开），顶部为可滚动的目标摘录集列表（`Move to ...` 与 `Duplicate to ...` 排除当前所在摘录集），底部固定 `New List`。
     - 菜单打开期间，触发按钮保持 `Open` 状态（底色 `--color-row-selected`），立即隐藏当前 Tooltip 且不触发新 Tooltip；再次点击该按钮、再次按下同一快捷键、按 `Esc` 或点击外部区域关闭菜单。
     - 点击菜单底部 `New List` 时，打开「新建摘录集（`New Excerpt List`）」弹窗；创建成功后自动将当前已勾选的所有有效项批量保存/移动/复制到该新建摘录集中。

3. **批量处理规则、重复项跳过、二次确认与操作后勾选保持（`Excerpt and Export.md`、`Toast Usage Registry.md`、`C-10.2 Confirmation Dialog`）**：
   - **无单次处理数量上限与顺序保持**：批量保存、移动、复制、移除均不设勾选数量上限；批量写入目标摘录集时保持所选行在当前表格中的先后顺序。
   - **有效性校验**：操作前自动过滤仍在媒体库中的有效项；若所选行因后台索引变化已全部不在媒体库中，弹出 `warning` Toast（`table.action.cue_not_in_library`，单条 / 多条对应文案）。
   - **重复项处理与 Toast 反馈**：
     - **批量保存 / 批量复制**：目标摘录集中已存在相同台词的项自动跳过（保留目标列表中原有的添加时间不变），仅将未重复的有效项写入目标列表。
     - **批量移动（严格跳过）**：目标摘录集中已存在相同台词的项严格跳过、**留在原摘录集列表中不移除**；仅将未重复的有效项移入目标列表并从原列表中移除。
     - **Toast 提示**：只要本次操作有至少 1 条有效项成功写入/移入目标列表（含部分重复被跳过的情况），即弹出既有成功 Toast（`Saved to “{List Name}”` / `Moved to “{List Name}”` / `Duplicated to “{List Name}”`）；仅当所选有效项 **100% 全部在目标列表中已存在** 时，弹出 `warning` Toast（`This excerpt already exists in “{List Name}”` / `“{List Name}”中已存在该摘录` / `「{List Name}」中已存在該摘錄`）。
   - **批量移除二次确认**：
     - 点击 `Remove Excerpt` 或按 `R` 时，弹出 `Confirmation Dialog`（标题：`Remove Excerpt` / `移除摘录` / `移除摘錄`，按钮：`Cancel` 与 `Remove`）：
       - 仅勾选 1 条时：`Remove this excerpt from “{List Name}”?` / `确定要从“{List Name}”中移除这条摘录吗？` / `確定要從「{List Name}」中移除這條摘錄嗎？`
       - 勾选多条（`N > 1`）时：`Remove {N} excerpts from “{List Name}”?` / `确定要从“{List Name}”中移除这 {N} 条摘录吗？` / `確定要從「{List Name}」中移除這 {N} 條摘錄嗎？`
     - 确认移除后不弹出 Toast（与单条移除一致）。
   - **操作后保留勾选状态**：
     - **批量保存 / 批量复制**：操作完成后保持批量选择状态，所有已勾选行原样保持勾选。
     - **批量移动**：成功移走的行从当前列表移除；若因目标列表重复被跳过而仍有已勾选行留在当前列表中，则保持批量选择状态且剩余这些行继续保持勾选（同步更新左上角 `xx / yy rows selected` 计数）；若所有勾选行均已成功移走（剩余勾选行数为 `0`），则自动退出批量选择状态。
     - **批量移除**：点击取消时保持原勾选状态不变；确认移除后所有已勾选行被删除（剩余勾选行数为 `0`），自动退出批量选择状态。

# 验收标准

1. **按钮排布与自动换行**：在 Search 与 Excerpt 表格勾选任意行进入批量选择状态，第 2 行按上述顺序、图标与样式展示对应批量按钮；将窗口宽度拉窄时，放不下的按钮自动换行左对齐排布，Excerpt 详情页吸顶工具栏高度随换行动态增高且不遮挡下方表头。
2. **快捷键、Tooltip 与菜单交互**：鼠标悬停新增批量按钮满 1 秒显示含快捷键的对应语言 Tooltip；按 `S`（Search）或 `M` / `C` / `R`（Excerpt）或点击按钮可正常打开目标摘录集菜单或移除确认弹窗，菜单打开期间触发按钮呈 `Open` 态，支持键盘方向键、手柄、`Esc` 及通过底部 `New List` 新建列表并完成批量转存。
3. **批量保存与复制（含重复跳过与保留勾选）**：在 Search 批量保存到摘录集、或在 Excerpt 批量复制到其他摘录集时，操作完成后当前列表仍保持批量选择状态且原勾选行保持勾选；部分重复时静默跳过重复项并弹出成功 Toast，100% 全部重复时弹出已存在警告 Toast。
4. **批量移动（严格跳过与部分保留勾选）**：在 Excerpt 勾选多条执行批量移动，若目标列表已存在其中部分台词，已存在的行留在当前列表不消失且继续保持勾选状态，未重复的行移入目标列表并弹出移动成功 Toast；若所选行全部未重复并成功移走，移走后自动退出批量选择状态；若 100% 全部已存在，所有行均留在原列表且保持勾选，并弹出已存在警告 Toast。
5. **批量移除二次确认**：在 Excerpt 勾选 1 条或多条点击 `Remove Excerpt`（或按 `R`），弹出对应单数/复数文案的二次确认弹窗；点击取消保留勾选不变，点击确认后一次性移除所选摘录、更新列表计数并自动退出批量选择状态。