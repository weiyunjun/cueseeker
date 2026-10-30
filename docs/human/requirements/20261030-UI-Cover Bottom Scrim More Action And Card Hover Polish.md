# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **封面底部一体式渐变遮罩、左下角角标与右下角 `...` 按钮视觉重构（`C-11.1 Cover`、`C-08.3 Information Badge`、`C-03.2 Icon Button`）**：
   - **常驻底部深色渐变遮罩**：
     - 在所有媒体卡片封面（`C-11.1 Cover`，含 Recent 观看卡片、Library 一级文件夹卡片与二级剧集卡片、Excerpt 一级摘录集卡片，以及播放页内列表卡片）底部常驻显示从下往上线性淡出的深色渐变遮罩（明暗模式同色，属于固定深色表面）。
     - 新增尺寸 Token `--height-library-cover-bottom-scrim: 52%`（占封面高度比例）；渐变底端起始色复用 `--color-player-topbar-gradient-start`（`rgba(18,18,24,0.66)`），顶端结束色复用 `--color-player-topbar-gradient-end`（`rgba(18,18,24,0)`）。
   - **左下角信息角标（`Cover Badge`）去框化与字号调整**：
     - 移除原有的独立深色圆角底块、内边距与圆角，废弃 `--color-library-time-badge-bg`、`--padding-library-time-badge`、`--radius-library-time-badge`。
     - 时间、视频数量与摘录数量文字直接以纯白色 `--color-library-time-badge-text`（`#FFFFFF`）叠放在底部渐变遮罩左下角；字号 `--font-size-library-time-badge` 由 `10px` 调整为 `12px`（Semibold，数字等宽，文字阴影复用 `--shadow-player-topbar-title` `0 1px 2px rgba(0,0,0,0.50)`）。
   - **右下角更多按钮（`More Action Slot`）对齐与三档底色状态**：
     - 维持 `C-03.2 Icon Button / Default` 的 `32×32px` 圆角正方形规格（`--size-icon-button: 32px`、圆角 `--radius-control: 8px`、图标框 `--size-control-icon: 21px`），距封面右边缘、底边缘各 `--spacing-2`（`8px`）；左下角 `Cover Badge` 距封面左边缘 `--spacing-2`（`8px`），垂直方向与右下角 `32×32px` 按钮的水平中线对齐。
     - 废弃 `--opacity-library-cover-action-bg`、`--opacity-library-cover-action-bg-hover`、`--opacity-library-cover-action-bg-pressed`；封面右下角 `dots-three` 按钮改为与播放页顶底栏图标按钮一致的三档状态（图标色恒为 `--color-library-time-badge-text` `#FFFFFF`）：
       - `Default`（卡片指针 Hover 浮现时）：背景为 `Transparent`（透明无底框）；
       - `Hover` / `Open`（指针悬停于按钮或通过该按钮打开菜单期间）：背景复用 `--color-player-control-bg-hover`（`rgba(255,255,255,0.16)`）；
       - `Pressed`（按住按钮期间）：背景复用 `--color-player-control-bg-pressed`（`rgba(255,255,255,0.24)`）。

2. **全局三点图标（`dots-three` 与 `dots-three-vertical`）实心圆点尺寸升级（`Icon Registry.md`）**：
   - 将全局三点图标（横向 `dots-three` 与播放控制条纵向 `dots-three-vertical`）的实心圆点制作规格统一调大，使 `21px`（`--size-control-icon`）下单个圆点的显示直径为 `3px`（对应 `256×256` 母版画布中半径 `10` 的实心圆加同宽描边，随各尺寸线宽表等比变化），并在 `Icon Registry.md` 中补齐 `dots-three` 的名录条目。

3. **取消媒体卡片（`C-11.5 Media Card`）Hover 与 Selected 的封面缩放**：
   - 废弃 `--scale-library-cover-hover`（`1.02`）；所有媒体卡片在 `Hover` 与 `Selected` 态下，封面图、左下角角标文字、底部进度条与右下角 `...` 按钮均保持几何尺寸不变，不再发生缩放。
   - 卡片外层背景色过渡规则：Workbench 界面（Recent / Library / Excerpt）卡片 `Hover` 背景色（`--color-library-media-card-hover-bg`）以 `--duration-library-cover-hover`（`0.12s`，`easeOut`）平滑过渡；Playback 界面（Playback Overlay 与 Command Panel）卡片的 `Hover` 与 `Selected` 背景色（`--color-library-media-card-selected-bg`）切换均不带动画，即时生效。

# 验收标准

1. 所有封面卡片底部常驻显示占封面高度 `52%`、从 `rgba(18,18,24,0.66)` 到透明的深色渐变遮罩；左下角时间/数量文字无独立黑框，以 `12px` 纯白字叠放在遮罩左下角并与右下角 `32×32px` `...` 按钮水平中线对齐。
2. 指针移入卡片时右下角 `...` 按钮默认透明无底框；指针移上 `...` 按钮或展开菜单时显示 `rgba(255,255,255,0.16)` 圆角正方形底色；按住 `...` 按钮时显示 `rgba(255,255,255,0.24)` 底色。
3. 封面卡片、Cover Summary、File 卡片、Task 卡片、表格行的横向 `...` 图标以及播放控制条的纵向 `⋮` 图标，圆点均统一放大为 `21px` 下直径 `3px` 的饱满实心圆点。
4. 鼠标 Hover 或键盘/手柄选中任意媒体卡片时，封面及内部文字、进度条、按钮均不再放大缩放；Workbench 卡片 Hover 背景色带 `0.12s` 过渡，Playback 卡片 Hover 与 Selected 背景色无动画即时切换。