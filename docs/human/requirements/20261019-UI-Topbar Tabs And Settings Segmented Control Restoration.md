# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **顶部视图切换栏恢复为「纯文字 + 底部滑动横线」样式（`C-05.4`、`C-05.5`、`L-03.1`、`L-06.9`、`L-08.2`）**：
   - **适用范围**：Recent 界面顶栏（`Videos` / `Excerpt Lists`）、Playback Overlay 顶栏（`Current` / `Playlist`）、Task 弹窗顶部栏（`Current` / `Completed` / `Incomplete`），三处的顶栏居中布局与空间不足时的避让截断规则保持不变。
   - **外观与间距**：移除外框与背景底槽，恢复为纯文字 + 底部胶囊圆角短横线；相邻选项间距为 `16px`（`--spacing-4`），单选项左右内边距为 `8px`（`--spacing-2`），文字与底部横线垂直间距为 `4px`（`--spacing-1`），底部胶囊横线固定尺寸为 `24 × 2px`（水平居中于当前选中文字正下方）。
   - **字号与字重锁定**：文字字号统一为 `14px`（`--font-size-body`），选中项与未选中项统一固定为 `600`（Semibold）字重，切换时不改变字重。
   - **颜色对齐全局标准文字 Token**：选中项文字与底部横线颜色统一使用 `--color-text-primary`（Light `#1F1F1F`；Dark `#E4E4E4`），未选中项文字颜色统一使用 `--color-text-muted`（Light `#717171`；Dark `#979797`），移除旧有的独立 `--color-tab-selected` 与 `--color-tab-unselected` 色值；Playback Overlay 进入长截图编辑状态时的顶部居中标题 `Editing Collage` 同步对齐该选中文字样式（`14px`、`600`、`--color-text-primary`）。
   - **平滑滑动动效**：点击或按快捷键 `Tab` 切换选项时，底部 `24 × 2px` 胶囊横线以 `0.18s` 快启慢停（`cubic-bezier(0.22, 1, 0.36, 1)`）沿水平方向平滑移动至目标选项正下方，文字颜色同步以 `0.18s` 过渡；首次进入界面、弹窗打开或拖拽改变窗口尺寸时不触发横线滑动动画。

2. **设置界面分段控件恢复 Accent Color 样式与原紧凑尺寸（`C-02.4`、`L-02.3`、`L-02.5`）**：
   - **适用范围**：设置界面（Settings）中的所有分段选择项（通用外观模式、播放解码模式、字幕水平/垂直位置及边框类型）。
   - **颜色恢复**：外框容器背景恢复为 `--color-bg-control`（Light `#FFFFFF`；Dark `rgba(255,255,255,0.08)`），外边框恢复为 `--color-border-control`（Light `#E5E7EB`；Dark `#4A4A52`）；选中块背景恢复为 `--color-segmented-control-selected-bg: macOS accent color`，选中项文字恢复为 `--color-segmented-control-selected-content`（Light / Dark 均为 `#FFFFFF`），移除选中块额外内边框；未选中项背景透明、文字恢复为 `--color-text-primary`。
   - **尺寸恢复**：整体高度 `--height-segmented-control` 恢复为 `32px`（内边距 `3px`，选中块高度 `26px`，外圆角 `8px`，选中块圆角 `5px`），文字字号 `--font-size-segmented-control` 恢复为 `12px`（字重保持 `500`）。

# 验收标准

1. Recent 顶栏、Playback Overlay 顶栏与 Task 弹窗顶部栏均展示为纯文字 + `24 × 2px` 底部胶囊横线样式，选中与未选中文字均为 `14px`、`600` 字重，颜色分别为 `--color-text-primary` 与 `--color-text-muted`，切换时文字宽度无任何晃动。
2. 在上述三处点击切换选项（或在 Playback Overlay 中按 `Tab` 键切换）时，底部横线以 `0.18s` 平滑滑动至新选项正下方且文字颜色同步过渡；首次打开界面或缩放窗口时横线不产生多余滑动。
3. 设置界面中的外观模式、解码器选择、字幕位置与边框类型分段控件均恢复为 `32px` 高、`12px` 字号，选中项呈现系统强调色（Accent Color）背景与纯白文字。