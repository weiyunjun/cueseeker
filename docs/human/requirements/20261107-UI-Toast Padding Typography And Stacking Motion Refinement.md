# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **`C-09.1 Toast` 上下内边距、图文颜色与字重 Token 调整**：
   - **上下内边距（Padding Block）**：由 `--spacing-2`（`8px`）调整为 `--spacing-4`（`16px`），单行 Toast 高度由 `36px` 提升为 `52px`；左右内边距 `--padding-control-x`（`14px`）、图文间距 `--spacing-2`（`8px`）、圆角 `--radius-toast`（`10px`）与图标尺寸 `--size-toast-icon`（`16px`）保持不变。
   - **图标与文字颜色**：统一由 `--color-text-primary` 调整为 `--color-text-secondary`（Light `#494949`、Dark `#B9B9B9`）。
   - **文字字重**：统一使用专属 Token `--font-weight-toast`，并将 `--font-weight-toast` 的值由 `400` 修改为 `500`（不再跨组件借用 `--font-weight-control`）。

2. **`C-09.1 Toast` / `L-01.4 Toast Layout` 叠层几何与进退场动效优化**：
   - **底部中心锚点与叠层参数**：
     - 叠层卡片统一以底部中心（Bottom Center）为定位与缩放基准。
     - 后方叠层每层递减缩放步长 `--scale-step-toast-stack` 由 `0.05` 修改为 `0.10`（第 1 层 `1.00`、第 2 层 `0.90`、第 3 层 `0.80`）。
     - 后方叠层顶部向上露出的垂直间距 `--offset-toast-stack` 由 `9px` 修改为 `12px`。
   - **进退场轨迹与超出上限退场**：
     - **入场**：新 Toast 保持 100% 不透明，从底部向下偏移自身高度 `--distance-toast-motion`（由 `18px` 修改为 `150%`）的位置向上滑入，入场过程不做整体半透明淡入。
     - **到期退场**：未超出数量上限的 Toast 到时消失时，向下偏移自身高度 `150%` 滑出并淡出。
     - **超出 3 层上限退场**：连续触发超过 3 层时，最早的第 3 层卡片继续向后上方推挤缩小一层并同时平滑淡出为透明，过渡完成后移除。
   - **分层过渡时长**：
     - 外框位移、缩放与退场透明度过渡时长 `--duration-toast-motion` 由 `0.36s` 修改为 `0.50s`，缓动保持 `--easing-toast-motion`（`cubic-bezier(0.22, 1, 0.36, 1)`）。
     - 卡片退居后方时内部图文隐去的透明度过渡时长新增 `--duration-toast-content`（`0.25s`），缓动复用 `--easing-toast-motion`。
     - 新旧卡片行数不同时，后方叠层高度跟随最前层卡片高度的过渡时长新增 `--duration-toast-height`（`0.15s`）。

# 验收标准

1. **尺寸、配色与字重**：
   - 单行 Toast 高度为 `52px`（上下内边距各 `16px`、行高 `20px`），多行折行时上下内边距同样保持 `16px` 且左侧图标与第一行文字垂直居中。
   - Light Mode 与 Dark Mode 下，Toast 图标与文字颜色均为 `--color-text-secondary`（Light `#494949`、Dark `#B9B9B9`），文字字重采用 `--font-weight-toast`（`500`），与 `Neutral` 按钮的图文颜色及字重视觉一致。
2. **叠层与进退场动效**：
   - 触发单条或多条 Toast 时，新卡片以 100% 不透明状态从底部 `150%` 偏移处平滑向上滑入（时长 `0.50s`），无半透明重影或首尾条跳变。
   - 连续触发多条时，后方卡片向上推挤并以底部中心为基准按 `0.90`、`0.80` 比例缩小，顶部露出 `12px` 折叠边，内部图文在 `0.25s` 内快速隐去；单行与多行卡片混叠切换时，后方卡片高度在 `0.15s` 内平滑贴合最前层高度且底部不跳动。
   - 连续触发第 4 条时，原第 3 层卡片继续向后上方推挤缩小并淡出消失；卡片自然到期时向下 `150%` 滑出并淡出消失。