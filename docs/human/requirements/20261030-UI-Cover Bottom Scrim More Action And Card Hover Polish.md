# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **封面右下角 `...` 按钮圆点尺寸加粗（`C-11.1 Cover`、`C-03.2 Icon Button`、`Icon Registry.md`）**：
   - **仅针对媒体卡片封面右下角的 `...` 按钮**：采用 `dots-three` 的 `Fill` 实心字重变体，在 `--size-control-icon`（`21px`）尺寸下，3 个实心圆点的显示直径为 **`3px`**，提升在复杂封面画面上的辨识度。
   - **其余位置保持不变**：表格行、File 卡片、Task 卡片、Cover Summary 的 `dots-three`（`Regular` 字重）以及播放器底栏的 `dots-three-vertical`（`Regular` 字重）均保持原有图标规格、尺寸与颜色不变。

2. **统一封面左下角徽章与右下角 `...` 按钮的深浅色模式基底及三态透明度（`C-08.3 Information Badge / Cover Badge`、`C-03.2 Icon Button`、`UI Tokens.md`）**：
   - **深浅色模式统一**：封面左下角徽章与右下角 `...` 按钮在 Light Mode 与 Dark Mode 下统一使用同一套深色基底（`#0F172A`）与不透明度，不再区分深浅色模式：
     - `--color-library-time-badge-bg`：Light 与 Dark 统一为 **`rgba(15, 23, 42, 0.72)`**。
   - **右下角 `...` 按钮三态透明度递减（底色逐级变浅）**：
     - **Default（指针悬停在卡片上、未移入 `...` 按钮时）**：`--opacity-library-cover-action-bg` 统一为 **`0.72`**（即 `rgba(15, 23, 42, 0.72)`，与左下角徽章底色完全一致）。
     - **Hover / Open（指针移入 `...` 按钮或通过该按钮打开菜单期间）**：`--opacity-library-cover-action-bg-hover` 统一为 **`0.56`**（即 `rgba(15, 23, 42, 0.56)`，透明程度增加，底色变浅一档）。
     - **Pressed（按下 `...` 按钮时）**：`--opacity-library-cover-action-bg-pressed` 统一为 **`0.40`**（即 `rgba(15, 23, 42, 0.40)`，透明程度继续增加，底色再变浅一档）。
   - 左下角徽章与右下角 `...` 按钮的尺寸、圆角、内外边距及位置布局均维持现状不变。

3. **移除媒体卡片封面区域的悬停与选中缩放效果（`C-11.5 Media Card`、`UI Tokens.md`）**：
   - 删除 `--scale-library-cover-hover`（`1.02`）。
   - 所有媒体卡片（Recent 观看卡片与摘录列表卡片、Library 文件夹卡片与剧集卡片、Excerpt 摘录列表卡片、Playback Overlay 选集卡片、Command Panel 卡片）在 `Hover` 与 `Selected` 状态下，封面图、底部进度条、左下角徽章与右下角 `...` 按钮均不再发生缩放。
   - **卡片背景色动画区分**：
     - Workbench 界面（Recent、Library、Excerpt）的媒体卡片在 `Hover` 状态切换时，卡片背景色（`--color-library-media-card-hover-bg`）保留 `--duration-library-cover-hover`（`0.12s`，`easeOut`）过渡动画。
     - Playback 界面（Playback Overlay 选集卡片与 Command Panel 卡片）在 `Hover` 与 `Selected` 状态切换时，卡片背景色立即切换，不带过渡动画。

# 验收标准

1. 悬停任意媒体卡片时，右下角 `...` 按钮的 3 个白色圆点直径为 `3px`，清晰醒目；表格行、File 卡片、Task 卡片、Cover Summary 与播放器底栏的 `...` / `⋮` 按钮样式完全不受影响。
2. 无论在浅色模式还是深色模式下，悬停媒体卡片时，右下角 `...` 按钮的默认底色与左下角进度/集数胶囊底色完全一致（均为 `rgba(15, 23, 42, 0.72)`）；当鼠标移入 `...` 按钮（或展开菜单）时底色变浅（`0.56`），鼠标按下时底色进一步变浅（`0.40`）。
3. 鼠标移入或通过键盘/手柄选中媒体卡片时，封面图、进度条、左下角胶囊与右下角 `...` 按钮均保持原尺寸不发生缩放；Workbench 界面卡片悬停背景有 `0.12s` 平滑变色过渡，Playback 界面卡片悬停与选中背景立即切换无过渡动画。