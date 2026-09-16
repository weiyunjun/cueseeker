# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Core Tokens / 颜色 / Control；Selection Controls / Checkbox）

# 需求描述

## 1. 范围

Checkbox 的全部变体：Table Selection Checkbox、Playback Selection Checkbox、Form Checkbox。

## 2. 改动

1. Checkbox 按图标绘制：未勾选为空心圆，内部透明；勾选与半选为实心圆，勾与横线为镂空，透出所在表面。
2. 各状态颜色：
   - Unchecked：Control Color `--color-border-checkbox`。
   - Checked、Indeterminate：Control Color `--color-bg-checkbox-checked`。
   - Disabled：Control Color `--color-text-disabled`。
3. 删除 `--color-bg-checkbox-unchecked` 与 `--color-checkbox-icon`，Checkbox 不再有单独的 Indicator。

## 3. 保持不变

1. Checkbox 的外观、尺寸、焦点环与交互不变。
2. `--color-border-checkbox`、`--color-bg-checkbox-checked` 与 `--color-text-disabled` 的取值不变。

# 验收

1. Light 与 Dark 下，三种 Checkbox 的未勾选、勾选、半选与禁用外观与改动前一致。
2. 代码与设计文档中不再出现 `--color-bg-checkbox-unchecked` 与 `--color-checkbox-icon`。
3. 本次改动不新增任何自动化端到端或单元用例的失败。