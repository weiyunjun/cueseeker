# 版本

main

# 关联设计

- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/playback/Controller.md`
- `docs/human/design/workbench/Settings and Localization.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Empty State Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/UI Accessibility Rules.md`

# 需求描述

1. **Collage 调整为 Playback Overlay 顶部同级标签页**：
   - 将 `Collage`（`Collage` / `长截图` / `長截圖`）提升为与 `Current`、`Playlist` 同级的顶部标签页，排列在最右侧（有播放列表时顺序为 `Current`、`Playlist`、`Collage`；无播放列表时顺序为 `Current`、`Collage`），支持鼠标点击、键盘无障碍焦点切换及手柄 `L1` / `R1` 肩键切换。
   - 移除 Playback Overlay 顶栏右侧原有的 `Collage Action`（`images-square`）图标按钮及顶栏 `Editing Collage…` 居中标题形态。
   - 在 `Collage` 标签页按 `Esc`（或手柄 `◯` 键）与 `Current`、`Playlist` 一致，直接关闭整个 Playback Overlay 返回视频播放。

2. **快捷键、设置项与手柄键位调整**：
   - 取消进入/退出长截图的快捷键 `P`；在 `Settings -> Shortcuts` 中移除 `Edit Collage` 项及独立的 `Collage` 分类。
   - 将 `Copy Collage` 与 `Export Collage` 并入 `Playback Overlay & Command Panel` 分类，并将 `Copy Collage` 的默认快捷键由 `C` 改为 `P`（`Export Collage` 保持 `E` 不变），与该分类下其余快捷键统一比较冲突。
   - 手柄键位调整：在 `Collage` 标签页中，手柄 `Create` 键对应 `Copy Collage`（复制长截图），`Triangle`（三角键）保持对应 `Export Collage`（导出长截图）；在其他标签页下 `Create` 键不再触发长截图切换。

3. **移除 Collage 页面左上角 `Collage Preview` 标题**：
   - 移除 `Collage` 页面左半区顶部的 `Collage Preview`（`Section Title`）文字及其下方标题间距，使左侧长截图预览视口直接占满左半区可用内容高度。

4. **Playback Overlay 左上角返回按钮改为 `Return to Playback`**：
   - Playback Overlay 顶栏左上角 `<`（`caret-left`）按钮的功能由返回工作台改为**关闭 Playback Overlay 并返回视频播放画面**（与按 `Esc` 行为一致）。
   - 该按钮的悬停提示（Tooltip）文案改为 `Return to Playback` / `返回播放` / `返回播放`，并固定显示快捷键 `Esc`。

5. **Collage 初始状态、独立焦点与草稿生命周期**：
   - 打开 Playback Overlay 的瞬间，`Current` 与 `Collage` 各自锁定当时的初始命中字幕为初始焦点字幕，且 `Collage` 默认勾选该条初始焦点字幕。
   - `Current` 与 `Collage` 之间完全独立、互不影响：在 `Current` 中滚动或改变焦点字幕不会改变 `Collage` 的焦点字幕；在 `Collage` 中滚动、勾选或点击左侧长截图跳转焦点也不会改变 `Current` 的焦点字幕。
   - 在 Playback Overlay 关闭前，切换顶部 `Current` / `Playlist` / `Collage` 标签页或打开/关闭 Command Panel 均保留 `Collage` 的长截图草稿（已勾选台词、左侧预览图及右侧焦点位置）；关闭 Playback Overlay 后清空草稿。

6. **Collage 未选择任何台词时的强调色空状态**：
   - 当用户在 `Collage` 右侧取消所有已勾选台词（已选数量为 `0`）时，左半区居中展示 `C-09.2 Empty State` 引导空状态（若当前字幕本身已不在媒体库中，则整页显示与 `Current` 一致的「此字幕已不在媒体库中」失效空状态）。
   - **空状态图标（`collage-hint`）**：`68×68px` 系统强调色双色调大图标，结构为左下后置圆角叠卡（新增 Token `--color-empty-icon-collage-back`：`macOS accent color` Alpha `0.52`，带 `12px` 镂空拼缝）+ 右上主图圆角底卡（复用 `--color-empty-icon-search-card`：`macOS accent color` Alpha `0.30`）+ 左上实心圆太阳与右下实心山峰块（复用 `--color-card-icon-accent-foreground`：`macOS accent color` `100%`）。
   - **空状态文案**：`Select cues to preview the collage.` / `选择台词以预览长截图。` / `選取台詞以預覽長截圖。`。

# 验收标准

1. **顶部标签页与返回行为**：打开 Playback Overlay 后，顶部显示 `Current`、`Playlist`（若有）、`Collage` 标签页，右侧不再有长截图图标按钮；点击左上角 `<` 按钮或按 `Esc` 均直接关闭 Playback Overlay 返回视频播放，悬停 `<` 按钮 1 秒显示 `Return to Playback` / `返回播放` 及 `Esc`。
2. **初始状态、独立性与草稿保留**：打开 Playback Overlay 后切到 `Collage`，初始焦点字幕已被默认勾选并显示预览；在 `Current` 与 `Collage` 之间分别滚动切换焦点或来回切换顶部标签页，`Current` 与 `Collage` 的焦点位置互不干扰，且 `Collage` 已勾选的台词与预览草稿在 Playback Overlay 关闭前始终保留。
3. **预览区布局与空状态**：`Collage` 左上角不再显示 `Collage Preview` 文字；当取消所有勾选台词（已选为 `0`）时，左半区居中展示系统强调色配色的 `collage-hint` 空状态图标与三语引导文案，再次勾选任意台词后恢复显示长截图预览。
4. **快捷键设置与手柄控制**：`Settings -> Shortcuts` 中已无 `Edit Collage` 与独立 `Collage` 分类，`Copy Collage`（默认 `P`）与 `Export Collage`（默认 `E`）位于 `Playback Overlay & Command Panel` 分类下且冲突判定正常；在 `Collage` 页面下键盘 `P` / `E` 及手柄 `Create` / `Triangle` 均可正常触发复制与导出长截图。