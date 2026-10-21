# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **按钮类触发器、筛选筹码与可点击文件夹卡片引入按下态（Pressed）视觉与交互规则**：
   - **适用组件白名单**：
     - **`C-03.1 Button`**：`Neutral`、`Cover Summary`、`Primary`、`Destructive` 全部变体（含设置页字幕 `Font` 下拉触发器）；
     - **`C-03.2 Icon Button`**：`Default`、`Inline Clear`、`Row Action`、`Dialog Close` 全部尺寸与表面变体（含 `C-05.2 Sidebar Toggle`、File 卡片与任务卡片右侧 `dots-three` 按钮、设置页快捷键「恢复默认」图标按钮、导出 Anki 弹窗 `+` 按钮及卡片内数据条目右侧 `✕` 移除按钮）；
     - **`C-03.3 Shortcut Action Button`**：`Overlay Surface`、`Popover Surface`（按下时内部 `C-08.9 Keycap` 同步切换至 Pressed 态）；
     - **`C-02.5 Filter Chip`**：未选中态与已选中态；
     - **File 一级与二级可点击文件夹卡片（`L-01.5 File View`）**：一级根目录文件夹卡片与二级子文件夹卡片（按住卡片本体时整卡显示 Pressed 背景色；按住卡片右侧 `dots-three` 按钮时仅该按钮显示 Pressed 态，卡片维持 Hover 背景色）；
     - **播放页控制按钮**：`C-12.1 Player Speed Button`、播放页顶底栏图标按钮、以及 `C-12.5 Player Volume Control` 左侧静音喇叭图标按钮区域（拖拽右侧音量滑块时不触发按钮按下态）。
   - **非白名单维持无按下效果**：其余组件（媒体封面卡片、File 剧集分组文件行、远程目录浏览弹窗卡片容器、任务卡片容器、表格表头与表格行、侧边栏导航项、顶栏与弹窗文字标签页 `Tabs`、面包屑节点、弹出菜单项、分段控制器、复选框、原生开关、输入框、颜色选择器、播放页进度条与台词流等）保持按住不改变外观。
   - **视觉与交互行为**：
     - **不缩放几何尺寸**：按下时控件宽高、边框、内边距与文字/图标位置保持零偏移，仅背景色在 Hover 态基础上推进一档至 Pressed 色（带边框控件在 Pressed 时保持 Hover 边框色）。
     - **`Open` 态维持现状**：当按钮挂靠的菜单、弹窗或所控模式处于打开状态时，`Open` 态继续使用对应的 Hover 外观；已处于 `Open` 态的按钮再次被左键按住时，同样切换为 Pressed 外观。
     - **按下移出与移回（后悔机制）**：左键在热区内按下时显示 Pressed 态；按住期间指针移出热区则退回普通外观（未打开时为 `Default`，已打开时为 `Open`），未松手移回热区则恢复 Pressed 态；按住移动期间不触发其他元素的 Hover 高亮；在热区内松开触发点击，在热区外松开取消本次点击。

2. **补齐与修正缺失的 Hover 效果，并统一设置分组卡片背景**：
   - **主按钮（`C-03.1 Primary`）补齐 Hover 态**：修复此前主按钮 Hover 与默认背景色相同的问题，建立「默认 $\rightarrow$ Hover $\rightarrow$ Pressed」三级色彩阶梯。
   - **海报摘要按钮（`C-03.1 Cover Summary`）改为半透明白色阶梯**：窄屏 `Backdrop Form` 下按钮的背景色基准由 `--color-cover-summary-scrim`（`#000000`）改为 `--color-cover-summary-text`（`#FFFFFF`），配合 `14%`（默认）$\rightarrow$ `24%`（Hover / Open）$\rightarrow$ `34%`（Pressed）不透明度阶梯，在暗色遮罩与封面上清晰提亮。
   - **已选中筛选筹码（`C-02.5 Filter Chip`）补齐 Hover 与 Pressed 态**：使未选中与已选中状态均具备完整的「默认 $\rightarrow$ Hover $\rightarrow$ Pressed」三级背景反馈。
   - **统一设置分组卡片与文件详情分组卡片背景（移除 `--color-settings-group-bg`）**：移除历史遗留的 `--color-settings-group-bg`；Settings 各分类分组卡片（`L-02.3`）与 `File Info` 详情弹窗属性分组卡片（`L-06.8`）统一复用 `--color-table-bg`（Light `#FFFFFF`；Dark `#2E2E34`）与外边框 `--color-border-control`（Light `#E5E7EB`；Dark `#4A4A52`），卡片内行分割线保持 `--color-border-divider` 不变。

3. **Token 调整与新增清单**：
   - **移除 Token**：`--color-settings-group-bg`。
   - **调整 Token**：
     - `--color-primary-button-bg-hover`：Light 为 `macOS accent color` 混入 `12%` `#000000`；Dark 为 `macOS accent color` 混入 `12%` `#FFFFFF`。
   - **新增 Token**：
     - `--color-bg-pressed`：Light `#E5E7EB`；Dark `rgba(255,255,255,0.16)`；
     - `--color-primary-button-bg-pressed`：Light 为 `macOS accent color` 混入 `22%` `#000000`；Dark 为 `macOS accent color` 混入 `22%` `#FFFFFF`；
     - `--color-danger-bg-pressed`：Light `#FEE4E2`；Dark `#4C1D1D`；
     - `--color-filter-chip-selected-bg-hover`：Light 为 `macOS accent color` Alpha `0.12`；Dark 为 `macOS accent color` Alpha `0.18`；
     - `--color-filter-chip-selected-bg-pressed`：Light 为 `macOS accent color` Alpha `0.16`；Dark 为 `macOS accent color` Alpha `0.24`；
     - `--color-overlay-surface-shortcut-button-bg-pressed`：Light `#E1E4E9`；Dark `rgba(255,255,255,0.12)`；
     - `--color-overlay-surface-keycap-bg-pressed`：Light `#C4C9D3`；Dark `rgba(255,255,255,0.22)`；
     - `--color-popover-surface-shortcut-button-bg-pressed`：Light `#EDEFF2`；Dark `rgba(255,255,255,0.12)`；
     - `--color-popover-surface-keycap-bg-pressed`：Light `#D2D6DE`；Dark `rgba(255,255,255,0.22)`；
     - `--color-player-control-bg-pressed`：Light / Dark 均为 `rgba(255,255,255,0.24)`；
     - `--opacity-cover-summary-button-bg-pressed`：`34%`；
     - `--color-row-action-bg-pressed`（File 卡片与任务卡片右侧 `dots-three` 按钮 Pressed 背景）：Light `#DEE2E8`；Dark `#4E4E58`；
     - `--color-file-folder-card-bg-pressed`（File 一级与二级可点击文件夹卡片 Pressed 背景）：Light `#F3F4F6`；Dark `#3E3E47`。

# 验收标准

1. 白名单内的全部按钮、图标按钮、带键帽快捷动作按钮（含内部键帽）、筛选筹码、File 一级与二级可点击文件夹卡片、播放页倍速与静音喇叭按钮，在 Light / Dark 模式下均具备清晰的「默认 $\rightarrow$ Hover $\rightarrow$ Pressed」三级背景色变化且尺寸无缩放；`Open` 态继续保持 Hover 背景色，处于 `Open` 态时再次按住同样呈现 Pressed 背景色。
2. 在白名单控件上按下左键后移出范围，控件退回未按下外观且不触发其他元素的 Hover 高亮；未松手移回则恢复 Pressed 外观；在外部松开取消点击，在内部松开正常触发动作。非白名单组件按住期间外观保持不变。
3. 宽屏分栏下的主按钮（如 `Resume`）与窄屏海报背景下的半透明白色按钮（`Resume`、`View in File`、`...`）均具备清晰可见的 Hover 与 Pressed 视觉阶梯。
4. Settings 分组卡片与 `File Info` 弹窗属性分组卡片在 Light / Dark 模式下均使用 `--color-table-bg` 背景与 `--color-border-control` 外边框，设置页快捷键「恢复默认」图标按钮的 Hover 与 Pressed 底块清晰可辨。
