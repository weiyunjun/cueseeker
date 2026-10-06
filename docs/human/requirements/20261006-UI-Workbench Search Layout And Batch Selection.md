# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 页面布局分层（覆盖搜索与摘录表格）
1. **第一行（搜索框）**：
   - 全宽独立成行，胶囊圆角。
   - 移除原框内挤占的结果数量。
   - 处于批量选择状态时禁用（Disabled）。
2. **第二行（默认状态）**：
   - 左侧：展示结果数量（Search 展示 `xx results` / `xx 条结果`，Excerpt 展示 `xx excerpts` / `xx 条摘录`，字体保持现状）。
   - 右侧：放置筛选按钮（Neutral 样式）。

## 2. 批量选择模式触发
1. 默认未选中时，鼠标 Hover 到某一行（整行任意区域）该行序号显示圆圈 Checkbox，Hover 到表头 `#` 时表头显示圆圈 Checkbox。
2. 点击表头 `#` Checkbox：全选所有行并进入批量选择模式。
3. 点击单行 Checkbox：仅选中该行并进入批量选择模式（此时点击行的其他区域仍为常规单行点击）。

## 3. 批量选择状态表现
1. **第二行高亮横幅**：
   - 宽度与表格同宽，圆角与控件统一。
   - 底色采用系统浅 Accent 色，边框采用系统 Accent 色。
   - 左对齐文案：系统 Accent 色文字 `已进入批量选择状态：点击任意行即可勾选，支持 Shift 连选`（英文：`Batch selection active: click any row to select, Shift+click for range`）。
   - 右对齐按钮：中性按钮（Neutral Button）`退出选择`（`Exit Selection`）。
3. **表格行交互**：
   - 第一列常驻显示 Checkbox（已失效的条目不显示 Checkbox，保持显示行号，且不可被选中）。
   - 点击整行任意区域均可直接切换该行的勾选状态（失效行除外）

## 4. 退出批量选择
1. 点击第二行右侧中性按钮 `退出选择`。
2. 键盘按下 `Esc` 键。
3. 取消所有勾选（手动全部取消，或点击表头全选后再点全消）时，自动退出批量选择模式并恢复第二行默认布局。

## 5. 底部浮层（Selection Action Overlay）
1. 移除内部的“退出 [Esc]”按钮，保留导出与复制动作按钮。
2. 保留键盘按 `Esc` 退出批量选择模式的交互。

# 验收标准

1. 搜索框独立全宽，第二行左侧展示结果数、右侧放置筛选按钮。
2. 未选中时 Hover 序号显示 Checkbox，仅点 Checkbox 进入选择；有选中后第二行变为系统 Accent 色横幅，点击整行可切换勾选。
3. 点击第二行“退出选择”按钮、按 `Esc` 键或清空勾选后，均能立即退出批量选择并完全复原第二行与表格序号。
4. 底部浮层无“退出 [Esc]”按钮，颜色严格跟随系统 Accent 色。