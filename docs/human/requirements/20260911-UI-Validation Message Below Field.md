# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Text Field、Text Area、Shiori List Editor Dialog Layout、Rename Dialog Layout）
- 方案对比画布：https://claude.ai/code/artifact/b9cd5fba-5d18-4b70-9a00-052aac999162

# 需求描述

## 1. 范围

Text Field 与 Text Area 的校验信息，共三处：

1. Shiori List Editor 的 List Name。
2. Shiori List Editor 的 Description。
3. Rename Dialog 的 New Name。

## 2. 改动

1. 校验信息从 Label 与输入框之间移到输入框下方；它与输入框的间距等于 Label 与输入框的间距。
2. 没有校验信息时仍预留一行，报错出现与消失时对话框尺寸不变。

## 3. 保持不变

1. 校验信息的字号、颜色与单行上限不变。
2. 报错时输入框的边框颜色不变。
3. 字段总高、字段间距与对话框尺寸不变。
4. 校验时机、文案与能否确认的判定不变。

# 验收

1. 三处字段在空态时，Label 与输入框之间不再有空行。
2. 触发报错后，校验信息出现在输入框正下方。
3. 报错出现与消失前后，对话框尺寸、封面高度与底部按钮位置不动。
4. Light 与 Dark 两个主题分别核对以上各项。
5. 本次改动不新增任何自动化端到端或单元用例的失败。