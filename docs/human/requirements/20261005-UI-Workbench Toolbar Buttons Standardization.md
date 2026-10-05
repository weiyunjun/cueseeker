# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 按钮体系层级划分
1. **顶栏全局辅助按钮**（Task、Settings）：
   - 保持 Ghost 规范（无边框、透明底色），仅在 Hover 时显示浅灰背景，Open 时显示浅 Accent 背景。
2. **Workbench 页面操作按钮**（搜索框旁筛选、排序、多选及后续页面级操作）：
   - 统一收敛为 **Neutral 按钮规范**：具有 1px 控制边框（`--color-border-control`）、实体底色（`--color-bg-control`）与 8px 圆角（`--radius-control`）。

## 2. 工具栏按钮形态统一
1. **筛选按钮（Filter Trigger）**：
   - 由 Ghost 样式变更为 Neutral 样式。
   - 内部包含漏斗图标与数字 Badge；数字大于 0 时在图标右侧展示，数字底色为 Accent、字体为白字。
2. **多选按钮（Select Mode Trigger）**：
   - 由 Ghost 样式变更为 Neutral 样式纯图标按钮，与筛选按钮保持相同的容器尺寸与圆角。
3. **排序按钮（Sort Control）**：
   - 保持现有的 Neutral 样式（图标 + 文字）。

## 3. Open 激活状态与色彩联动
1. 当按钮挂靠的菜单、弹窗处于打开状态，或对应功能激活时，按钮呈现 **Open 状态**：
   - 背景色呈现浅 Accent 底色（`--color-bg-active`）。
   - **文字与图标联动高亮**：前景文字转为 `--color-text-active`，图标转为 `--color-icon-active`，消除灰色图标与浅色背景脱节的问题。
2. 筛选按钮展开 Filter Dialog 时，进入该 Open 状态，且数字 Badge 正常共存。

# 验收标准

1. **外观一致性**：
   - 搜索栏右侧的筛选按钮、排序按钮、多选按钮视觉形态统一，均带有标准 Neutral 边框与实体底色，高度与圆角整齐对齐。
   - 顶栏的 Task 按钮与设置按钮保持纯净无框的 Ghost 样式。
2. **Open 态色彩表现**：
   - 筛选按钮展开 Filter 浮层、排序按钮展开单选菜单、设置按钮展开窗口时，按钮均呈现浅 Accent 底色，且内部图标与文字高亮为 Accent 色。
3. **多模式与无硬编码**：
   - Light 模式与 Dark 模式下色彩、边框与对比度均正常适配。
   - 严格绑定现有 Design Token，无硬编码。