# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 入口与唤起
1. File 页面三级文件卡片（File Card）的 `dots-three` 操作菜单中新增 `Get Info` 选项。
2. 菜单项图标使用 Phosphor `info`（U+E2CE），点击后弹出对应文件的通用详情对话框（File Detail Dialog）。

## 2. 对话框结构与通用边距
1. 对话框尺寸采用最大宽度预设 `--width-dialog-x-large`（720px），高度随内容自适应。
2. 对话框内容区最大高度受窗口安全高度约束，超出时内容区在内部垂直滚动，对话框自身绝不超出当前窗口上下边界。
3. 对话框严格保持四边等距（Visual Inset = `--inset-dialog`: 24px）：
   - 左边距：标题、标头图标与下方各卡片左边缘对齐到 `--inset-dialog`（24px）。
   - 右边距：右上角关闭按钮（X 墨迹外缘）与下方各卡片右边缘对齐到 `--inset-dialog`（24px）。
   - 上边距：标题文本 Cap 顶线到顶边缘距离为 `--inset-dialog`（24px，应用 cap-top inset 补偿）。
   - 下边距：内容滚到底时最后一个卡片底部到对话框底边缘距离为 `--inset-dialog`（24px）。
4. 对话框 Header：左侧展示 `File Info` 主标题（20px Semibold），右上角展示关闭按钮（支持 Esc 关闭），移除 Header 下方的分割线。

## 3. 文件标头（File Header Row）
1. 位于对话框主底色上（无卡片背景与外框）。
2. 图标底框与字形尺寸（Token 约束）：
   - 底框尺寸：`--size-detail-file-icon-container`: `40px`
   - 底框圆角：`--radius-control`: `8px`
   - 底框背景色：`--color-bg-hover`
   - 图标字形尺寸：`--size-detail-file-icon-glyph`: `20px`（视频为 `video`，字幕为 `subtitles`）
3. 图标与右侧文件名标题的水平间距严格对齐 `--inset-dialog`（`24px`）。
4. 文件名标题排版：
   - 字号：`--font-size-body`（`14px`）
   - 字重：`--font-weight-control`（`500` Medium）
   - 颜色：`--color-text-primary`
   - 行高：`--line-height-detail-file-title`: `20px`
   - 折行与对齐：单行时与 40px 图标垂直居中；超长时最多折为 2 行（2 行 × 20px = `40px`，高度与图标底框严格对齐齐平），超出两行尾部截断省略。

## 4. 属性卡片排版规范
1. 采用 Settings 风格卡片：外置小标题（`--font-size-body`: 14px Semibold，左内缩 16px `--spacing-4` 与卡片内部文本首字符对齐） + 圆角卡片（背景 `--color-settings-group-bg`，圆角 `--radius-settings-group`: 10px，边框 1px `--color-border-divider`）。
2. 单行全宽两端对齐：左侧为属性名称（Label），右侧为具体数值（Value），行高保底 40px（`minHeight: 40px`），上下内边距 8px，行间以 1px `--color-border-divider` 分隔。
3. 文本约束与对齐：
   - 常规属性 Label 最小宽度：`--min-width-detail-label`: `100px`（颜色 `--color-text-secondary`）
   - 序列号 Label 最小宽度：`--min-width-detail-index-label`: `40px`（颜色 `--color-text-secondary`）
   - Label 与 Value 水平间距：`--spacing-4`（`16px`）
   - 右侧 Value 为 `--color-text-primary`，整体靠右，超长折行时内部**严格左对齐**（首字符齐平），不呈阶梯状。
4. 字体与数字对齐：统一采用标准系统字体（SF Pro），禁止使用等宽字体族（Monospace）；纯数字、时长、时间日期等字段使用系统 `.monospacedDigit()` 保持数字等宽对齐。

## 5. 视频文件详情展示
1. **Video**：展示 Resolution、Frame Rate、Codec、Bitrate、Duration。
2. **Audio（多音轨分卡片）**：若包含多个音轨，每个音轨独立为一个卡片，小标题依次为 `Audio #1`、`Audio #2`...，内部展示 Codec、Channels、Language、Title（仅展示有效项）。
3. **Subtitles（关联字幕）**：小标题为 `Subtitles`，卡片内多行展示关联字幕，左侧 Label 统一使用序列号 `#1`、`#2`...，右侧为字幕文件名。
4. **File Details**：展示 File Size、Format、Path、Created、Modified。
   - 时间字段（Created / Modified）格式统一为 `yyyy-MM-dd HH:mm:ss`。

## 6. 字幕文件详情展示
1. **Subtitle Specifications**：仅保留 Encoding 与 Cue Count（直接从数据库 `subtitle_cue_lines` 统计行数）。
2. **Video**：小标题为 `Video`，左侧 Label 为 `#1`，右侧展示关联的唯一视频文件名。
3. **File Details**：展示 File Size、Format、Path、Created、Modified，时间格式统一为 `yyyy-MM-dd HH:mm:ss`。

# 验收

1. **入口与交互**：File 页面三级文件卡片菜单展示带 `info` 图标的 `Get Info` 项，点击唤起弹窗；支持点击 X 或按 Esc 关闭。
2. **窗口高度与滚动**：弹窗高度受窗口安全高度约束，超出时内部滚动，Header 与右上角关闭按钮始终保持吸顶可见，弹窗整体不超出窗口边界。
3. **视觉边距与四边等距**：四边视觉边距严格均为 24px；标头图标与文件名间距为 24px；文件名 2 行折行时与 40px 图标严格等高。
4. **字体与样式**：卡片标题为 14px Semibold 并与内容首字左对齐；属性排版使用标准系统字体，无等宽字体族，数字与时间采用 `.monospacedDigit()` 规整对齐。
5. **多音轨与多字幕**：多音轨独立展示为 `Audio #1`、`Audio #2`... 卡片；关联字幕与关联视频均以 `#1` 序列号展示。
6. **规格与时间精度**：字幕 Cue Count 与数据库统计一致；所有时间均符合 `yyyy-MM-dd HH:mm:ss` 格式。