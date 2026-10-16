# 版本

main

# 关联设计

- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Toast Usage Registry.md`

# 需求描述

1. **已选计数文案统一（`L-08.3 Playback Footer Layout` & `L-05.5 Selection Action Overlay Layout`）**：
   - Collage 编辑界面底栏左侧状态由总字幕数改为已选与总数对比：英文 `%d / %d cues selected`，简体中文 `已选 %d / %d 条台词`，繁体中文 `已選 %d / %d 條台詞`（分子为当前已勾选台词数，分母为当前字幕总台词数）。
   - 同步将工作台表格批量选择状态文案（`table.selected_count`）的简/繁中文由 `已选取 %d / %d 行` / `已選取 %d / %d 行` 统一精简为 `已选 %d / %d 行` / `已選 %d / %d 行`（英文保持 `%d / %d rows selected`）。

2. **Collage 按钮收口至底部 Footer 与全宽对齐（`L-08.3` & `L-08.6`）**：
   - 移除 `Collage Preview Region` 底部原有的 `Copy Collage` 与 `Export Collage` 两个 `Button / Neutral` 按钮，左侧预览区仅保留标题与预览画布。
   - Collage 界面底栏（`Playback Footer`）不再局限于右半栏，而是位于左右双栏内容区正下方，使用与父容器一致的左右 `--spacing-8`（`32px`）内边距，使底栏左侧状态文本与左侧预览图左边缘对齐，底栏右侧动作区与右侧字幕区右边缘对齐（右侧 Collage 字幕区同样跟随右半栏 `--spacing-8` 边距，不套用单栏 `960px` 上限）。
   - 底栏右侧动作区依次展示三个 `C-03.3 Shortcut Action Button`：`Copy Collage`（默认键 `C`）、`Export Collage`（默认键 `E`）、`Select`（固定键 `Return`）。点击动作按钮或按下对应快捷键均执行相同的复制/导出逻辑。

3. **Settings -> Shortcuts 新增 `Collage` 分组（`L-02.4 Settings Shortcuts Layout`）**：
   - 在 `Settings -> Shortcuts` 的 `Playback Overlay & Command Panel` 分组下方新增 `Collage` 分组（简中：`长截图`，繁中：`長截圖`），依次包含：
     - `Copy Collage`（简中：`复制长截图`，繁中：`拷貝長截圖`）：默认键 `C`
     - `Export Collage`（简中：`导出长截图`，繁中：`匯出長截圖`）：默认键 `E`
   - 录入限制与浮层分组一致：回车与方向键在 `Collage` 分组下作为导航保留键静默忽略。
   - 冲突判定：`Collage` 分组内的快捷键与同组功能、`Edit Collage`（在 Collage 内用于退出）以及全局的 `Open Command Panel` 判定冲突；与 `Playback Overlay & Command Panel` 中的 `Save to Excerpt List`、`Copy Cue Text`、`Copy Deep Link` 生效界面互不重叠，不判定冲突。
   - Collage 底栏中 `Copy Collage` 与 `Export Collage` 的 Keycap 动态跟随 `Settings / Shortcuts` 中的当前有效键位；快捷键已清空或处于冲突状态时隐藏 Keycap，按钮点击照常生效。

4. **Collage 复制与导出 Playback Feedback 完善（`Toast Usage Registry.md`）**：
   - 在 Collage 界面触发 `Copy Collage` 或 `Export Collage`（含按钮点击、键盘快捷键、手柄按键）时，统一在 `Playback Center` 按以下 4 个状态分支展示 Feedback：
     1. **未勾选任何台词（`selectedCueCount == 0`）**：弹出警示 `Select at Least One Cue` / `请至少选择一条台词` / `請至少選擇一條台詞`（图标 `warning`，持续 `3秒`，Scenario ID：`playback.feedback.collage_no_cue_selected`）。
     2. **未就绪（刚进入或刚勾选，预览仍在异步渲染生成中 `isRendering == true`）**：弹出警示 `Collage Not Ready` / `长截图未就绪` / `長截圖未就緒`（图标 `warning`，持续 `3秒`，Scenario ID：`playback.feedback.collage_not_ready`）。
     3. **失败（预览抽帧合成已报错失败，或剪贴板写入 / 磁盘导出写入抛错）**：
        - 复制失败：复用 `Copy Failed` / `复制失败` / `拷貝失敗`（图标 `warning`，持续 `3秒`，Scenario ID：`playback.feedback.copy_failed`）。
        - 导出失败：弹出 `Export Failed` / `导出失败` / `匯出失敗`（图标 `warning`，持续 `3秒`，Scenario ID：`playback.feedback.export_failed`；若预览阶段已失败则直接报错不弹保存面板）。
     4. **成功**：
        - 复制成功：弹出 `Collage Copied` / `已复制长截图` / `已拷貝長截圖`（图标 `copy`，持续 `1.5秒`，Scenario ID：`playback.feedback.collage_copied`）。
        - 导出成功：用户在系统保存面板确认且文件写入成功后，弹出 `Collage Exported` / `已导出长截图` / `已匯出長截圖`（图标 `export`，持续 `1.5秒`，Scenario ID：`playback.feedback.collage_exported`）；用户在保存面板点击取消时不触发任何提示。

5. **设计文档同步**：
   - 待全部改动验收通过后，再将最终 UI、快捷键与 Toast 注册表规则同步更新至 `docs/human/design/` 下对应文档。

# 验收标准

1. 进入 Collage 界面后，左侧预览图下方不再显示旧版按钮；底栏横跨双栏下方，左侧 `xx / yy cues selected`（`已选 xx / yy 条台词`）与预览图左边缘齐平，右侧 `Copy Collage C`、`Export Collage E`、`Select ↵` 与右侧字幕右边缘齐平，勾选或取消勾选时计数实时更新。
2. 工作台表格进入批量选择后，状态文案显示为 `已选 xx / yy 行` / `已選 xx / yy 行` / `xx / yy rows selected`。
3. 在 Collage 界面按下 `C`、`E`（或修改后的快捷键）及点击底栏对应按钮，均可正常复制或导出长截图；未选台词、渲染未就绪、成功、失败 4 类场景下的 Playback Feedback 文案、图标与时长均符合第 4 节规定。
4. `Settings -> Shortcuts` 在 `Playback Overlay & Command Panel` 下方显示 `Collage` 分组及 `Copy Collage`、`Export Collage` 两项，默认键分别为 `C` 和 `E` 且默认无冲突报错；修改、清空、恢复默认及与同生效域按键（相互之间、`Edit Collage`、`Open Command Panel`）的冲突检测、底栏 Keycap 联动均符合规则。