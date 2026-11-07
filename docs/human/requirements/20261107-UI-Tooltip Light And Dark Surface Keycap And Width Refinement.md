# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`

# 需求描述

1. **`C-08.6 Tooltip` 容器与主文字明暗模式配色对齐及固定深色表面规则**：
   - **容器背景（Background）**：由 `--color-toast-bg` 调整为 `--color-bg-popover`（Light `#FFFFFF`、Dark `#36363B`），去除原有的固定深色毛玻璃衬底。
   - **容器边框（Border Color）**：由 `--color-toast-border` 调整为 `--color-border-control`（Light `#E5E7EB`、Dark `#4A4A52`），线宽保持 `--border-width-control`（`1px`）。
   - **容器圆角与阴影**：圆角保持 `--radius-control`（`8px`），阴影保持 `--shadow-popover`。
   - **主文字颜色（Label Color）**：由 `--color-player-text-primary` 调整为 `--color-text-secondary`（Light `#494949`、Dark `#B9B9B9`）。
   - **播放页固定深色表面（Player Chrome）规则**：工作台、设置、对话框、`Playback Overlay` 与 `Command Panel` 区分 Light Mode 与 Dark Mode 样式；仅在视频播放页本体（`Player Chrome`：播放页顶栏、底栏控制条、台词队列控制栏）触发的 Tooltip 恒定使用 Dark Mode 样式。
   - **清理遗留 Token**：移除 `UI Tokens.md` 中已无任何组件使用的 `--color-toast-bg` 与 `--color-toast-border`。

2. **`C-08.6 Tooltip` 快捷键改为复用 `C-08.9 Keycap / Popover Surface`**：
   - Tooltip 右侧快捷键由纯文本改为复用 `C-08.9 Keycap / Popover Surface` 组件（无边框，高 `--height-keycap: 22px`、最小宽 `22px`、圆角 `--radius-keycap: 4px`、左右内边距 `--spacing-1: 4px`、字号 `--font-size-caption: 12px`、字重 `--font-weight-control: 500`）。
   - **拆分与排列**：修饰键（`⌃`、`⌥`、`⇧`、`⌘`）与主键各占一个独立 `Keycap`（回车键展示 `arrow-elbow-down-left` 图标），多个 `Keycap` 之间间距为 `--spacing-1`（`4px`），与左侧主文字间距保持 `--spacing-2`（`8px`）。
   - **配色**：键帽背景为 `--color-popover-surface-keycap-bg`（Light `#EDEFF2`、Dark `rgba(255,255,255,0.10)`），内部文字与图标颜色为 `--color-text-muted`（Light `#717171`、Dark `#979797`）。

3. **`C-08.6 Tooltip` 截断补全文本最大宽度与自适应包裹修正**：
   - `--width-tooltip-max`（`280px`）作为 Tooltip 容器整体的最大宽度上限。
   - 对于支持多行换行的截断补全 Tooltip：当单行文本自然宽度加上左右内边距（`2 × --padding-control-x`）不超过 `280px` 时，容器宽度按单行文本实际宽度紧凑包裹；仅当超出 `280px` 时，容器宽度锁定在 `280px` 并自动多行折行。

# 验收标准

1. **明暗模式配色、固定深色表面与键帽展示**：
   - 在工作台、设置、对话框、`Playback Overlay` 与 `Command Panel` 中，Tooltip 随 Light Mode 与 Dark Mode 切换配色（背景 `#FFFFFF` / `#36363B`、边框 `#E5E7EB` / `#4A4A52`、主文字 `#494949` / `#B9B9B9`）；在视频播放页本体（`Player Chrome`）上触发的 Tooltip 在 Light Mode 与 Dark Mode 下均呈现 Dark Mode 样式。
   - 带快捷键的 Tooltip 右侧以 `C-08.9 Keycap / Popover Surface`（无边框，背景 `#EDEFF2` / `rgba(255,255,255,0.10)`，文字/图标 `#717171` / `#979797`）呈现快捷键；组合键（如 `⌘,` 或多修饰自定义快捷键）按单键拆分为多个独立键帽，回车键显示回车图标。
2. **截断补全 Tooltip 宽度**：
   - 当窗口变窄导致顶栏短标题（如 `Recent`）发生截断省略时，悬停弹出的 Tooltip 宽度紧贴文字实际宽度包裹，右侧无多余空白。
   - 当截断补全文本超长时，Tooltip 容器外框总宽度不超过 `280px` 且内部文本正常换行显示。