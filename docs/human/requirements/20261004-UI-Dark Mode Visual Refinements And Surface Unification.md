# 需求：Dark Mode 视觉优化与容器背景色统一

## 1. 需求背景与目标

在深色模式（Dark Mode）下，存在以下视觉与层级问题：
1. **容器底色碎片化**：Dialog 与 Command Panel 的背景色（`#2F2F34`）比页面背景（`#1C1C1F`）高亮，导致子组件（如任务卡片、封面占位）在不同容器中出现对比度倒错（如任务卡片在 Dialog 中变黑凹陷、默认封面在 Command Panel 中融色）。
2. **局部组件深色对比度不足**：Toast 提示框在深色下未提亮且边缘生硬；表格行复选框样式不一致；搜索框与过滤标签在深色模式下层级感知偏弱。

**目标**：严格遵循奥卡姆剃刀原则，统一核心容器底色，消除跨界面组件倒错，并补齐高频组件在深色模式下的对比度与层次感。

---

## 2. 核心底色统一（Surface Unification）

统一模态弹窗与主页面的基底色，依托原生蒙层（Scrim）、大扩散投影（Shadow）与微光边框实现层级分离，消除阶梯灰度带来的组件适配成本。

| 容器/界面 | Token | Light Mode | Dark Mode (修改后) | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **Workbench 主体（不含 Sidebar）** | `--color-bg-surface` | `#FFFFFF` | `#1C1C1F` (保持现状) | 页面基底 |
| **Dialog（任务面板、编辑弹窗等）** | `--color-bg-dialog` | `#FFFFFF` | **`#1C1C1F`** (原 `#2F2F34`) | 与 Workbench 基底统一 |
| **Command Panel** | `--color-bg-dialog` | `#FFFFFF` | **`#1C1C1F`** (原 `#2F2F34`) | 与 Dialog / Workbench 统一 |
| **Playback Overlay** | `--color-subtitle-focus-overlay-bg` | `#F6F7F9` | `#242426` (保持现状) | 播放器沉浸独立抽屉，不变更 |

---

## 3. 组件 Dark Mode 细节规范

### 3.1 默认封面图占位（Excerpt / Library Cover Placeholder）
- **使用位置**：Workbench 摘录一级列表、二级详情页顶部、Command Panel 近期摘录列表、封面编辑预览。
- **Token**：`--color-library-cover-placeholder-bg`
  - **Light Mode**：`#E5E7EB`（保持现状）
  - **Dark Mode**：修改为 **`#2E2E33`**（RGB: 46, 46, 51）。
- **图标**：居中占位图标在 Dark Mode 下使用 `--color-text-muted`（`#979797`）。
- **效果**：在基底色 `#1C1C1F` 上形成稳定、清晰的微亮卡片层次，不再融色。

### 3.2 任务卡片与列表容器（TaskPanel）
- **卡片底色**：卡片使用 `--color-table-bg`（Dark Mode: `#26262A`）。基底统一为 `#1C1C1F` 后，卡片自然浮起（`#26262A` > `#1C1C1F`），彻底消除“凹陷黑坑”现象。
- **卡片边框**：`--color-border-control`（Dark Mode: `#4A4A52`）。
- **操作按钮**：卡片内部的次级操作按钮（如取消/重试）统一使用通用控制组件底色与边框（`--color-bg-control` + `--color-border-control`）。

### 3.3 搜索框（Command Panel & Workbench）
- **底色**：统一使用 `--color-bg-control`（Dark Mode: `rgba(255, 255, 255, 0.08)`）。
- **边框**：`--color-border-control`（Dark Mode: `#4A4A52`）；获得焦点时使用高亮边框与 Focus Ring（`--color-border-focus`）。
- **占位文本**：`--color-text-placeholder`（Dark Mode: `#606060`）。
- **规则**：Command Panel 搜索框与 Workbench 顶部搜索框遵循同一组输入框 Token 规范。

### 3.4 复选框（Checkbox）
- **统一规范**：表格行复选框、表头复选框与 Collage 复选框行为及样式保持一致。
- **未选中态**：透明底，1px 圆环描边（Dark Mode 使用 `--color-border-control` `#4A4A52` 或 `--color-border-checkbox` `#5A5A62`），不可出现全灰实心或失效态灰圈。
- **选中态**：填充 Accent 颜色，内部白色勾选符号。

### 3.5 浮动提示框（Toast）
- **背景色**：Dark Mode 下采用微亮悬浮底色 **`#2A2A2E`**，与深色页面形成明确对比。
- **边框**：四周均匀 1px 描边 `--color-border-control`（`#4A4A52`），禁止上边缘单边加粗。
- **文本与图标**：主文本使用 `--color-text-primary`（Dark Mode: `#E4E4E4`），图标保留状态语义色（成功绿、警告黄、错误红、普通 Accent 蓝）。

### 3.6 筛选面板（CueFacetFilterPanel）
- **面板底色**：随 `--color-bg-dialog` 自动生效为 `#1C1C1F`。
- **Filter Chips**：
  - 未选中：半透明微白底色（`rgba(255, 255, 255, 0.06)`）+ `--color-border-control`。
  - 选中态：使用系统语义 `--color-filter-chip-selected-bg`（基于 Accent 衍生透明度）与 `--color-filter-chip-selected-content`（Accent 原色），不硬编码紫色。

---

## 4. 验收标准

1. **容器底色**：
   - 在 Dark Mode 下，呼出 TaskPanel、Command Panel 及各编辑弹窗，其主体底色与 Workbench 右侧页面底色严格一致（`#1C1C1F`）。
   - 弹窗外围蒙层（Scrim）与阴影（Shadow）正常渲染，层级分明。
2. **封面与卡片**：
   - Command Panel 列表与 Workbench 摘录列表中的无封面项目，其默认占位灰色块在 Dark Mode 下清晰可辨，不与背景融色。
   - TaskPanel 内部的任务项呈现微亮浮起卡片感，不再显得黑于底板。
3. **高频组件**：
   - Toast 弹出时在深色背景上对比清晰，边缘无局部粗细不均。
   - 表格各行的复选框在 Dark Mode 下均呈现清晰的圆环描边，选中时高亮稳定。
   - Workbench 与 Command Panel 的搜索输入框在深色下均具有清晰的内凹浅色背景与边界线。