# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 缩减按钮高度
1. 所有标准按钮高度由 40px（`--height-control`）调整为 **36px**。
2. 覆盖的按钮类型包括：
   - **普通按钮（Neutral）**：如弹窗 Cancel、文件页 Add Folder / Index Now 等；
   - **强调色背景按钮（Primary）**：如 Cover Summary 的 Resume / Play、各保存按钮等；
   - **警示按钮（Destructive）**：如弹窗 Remove 按钮等；
   - 以上包含与不包含 Leading Icon 的所有按钮。

## 2. 保持其余属性不变
1. **字号与字重**：保持 14px、500 Medium。
2. **图标尺寸与间距**：保持图标 18px、图文间距 8px。
3. **横向内边距与圆角**：保持横向内边距 14px、圆角 8px。
4. **焦点环 (Focus Ring)**：保持原有绘制逻辑与尺寸，不在本次调整范围。

## 3. 关联对齐适配
1. File 页面 Status and Action Row 状态指示行高度与按钮保持 1:1 对齐（同步收敛为 36px）。

# 验收

1. **尺寸测量**：普通按钮、Primary 按钮、Destructive 按钮及带图标按钮高度均为 36px。
2. **比例协调**：14px 文字与 18px 图标在 36px 高度下视觉紧凑协调，无多余空旷感。
3. **功能正常**：按钮 Hover、Disabled、点击交互正常，File 页面状态行对齐正常。