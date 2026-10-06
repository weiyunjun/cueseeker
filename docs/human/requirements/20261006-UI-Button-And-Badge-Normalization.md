# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Icon Registry.md`

# 需求描述

## 1. 筛选与排序按钮归一化
1. **尺寸与结构**：
   - Library 排序按钮保持结构：`[18px 图标] [当前排序项文本]`；
   - Search 与 Excerpt List 筛选按钮调整为：`[18px 图标] [Filter/筛选文本] [数字徽标(若有)]`；
   - 文本走多语言（英文 `Filter`，中文 `筛选`）；
   - 图标尺寸统一为 18px（`--size-button-icon`），按钮高度 36px（`--height-control`），圆角 8px。
2. **Open 态与 Hover 态对齐**：
   - 排序按钮与筛选按钮展开菜单/浮层时，Open 态外观与 Hover 态保持一致（使用 hover 背景与 hover 边框）；
   - 移除 Open 态的 Accent 激活高亮颜色。

## 2. 数字徽标（Count Badge）配色收敛（方案 A）
1. **背景色**：
   - 改为比按钮 Hover 态（`#F3F4F6`）更深一阶的 Neutral 灰色（Light: `#E5E7EB`，Dark: `rgba(255, 255, 255, 0.20)` 或 `#4A4A52`）；
   - 确保按钮在 Hover 或 Open 时，数字徽标轮廓清晰可辨，不产生溶色。
2. **文字色**：
   - 改为 `--color-text-secondary`（Light: `#494949`，Dark: `#B9B9B9`），与左侧筛选分类文本（如 `Language`）及图标保持同一视觉层级。
3. **覆盖范围**：
   - 筛选按钮（Filter Trigger）上的数字徽标；
   - 顶栏任务入口（Task Entry）上的数字徽标；
   - Filter 弹窗内各分组项的紧凑数字徽标（Compact Badge）。

## 3. 顶栏与图标按钮 Open 态统一
1. 所有顶栏图标按钮（Task 入口、Settings 入口、Collage 切换等）及 File 卡片 `...` 按钮，Open 态外观与所在表面的 Hover 态一致，不再追加 Accent 激活颜色。

## 4. 批量选择「退出选择」按钮图标补充
1. 在 Search 和 Excerpt List 批量选择状态下的「退出选择」（Exit Selection）按钮文字左侧增加 Phosphor `sign-out` 图标（18px）。
2. 在应用图标资源中补充 `sign-out.svg`，并在 `AppIcon` 中注册 `signOut`。

# 验收标准

1. 筛选按钮展示「Filter/筛选」文本与 18px 漏斗图标，有选中项时右侧显示数字徽标。
2. 筛选按钮与排序按钮在展开状态（Open）下无 Accent 强调色高亮，外观与悬停（Hover）一致。
3. 顶栏所有图标按钮与 File 卡片 `...` 按钮在 Open 状态下无 Accent 高亮，外观与 Hover 一致。
4. 数字徽标背景色在 Light 下为 `#E5E7EB`、Dark 下为半透明白高光或 `#4A4A52`；文字颜色在 Light 下为 `#494949`（`--color-text-secondary`）、Dark 下为 `#B9B9B9`。
5. 鼠标悬停在带有数字徽标的按钮上时，数字徽标边缘清晰可见。
6. 进入批量选择模式后，「退出选择」按钮左侧展示 18px `sign-out` 图标。