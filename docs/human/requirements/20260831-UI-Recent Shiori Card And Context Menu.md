# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Media Card、Shiori List Card Layout、Recent Shioris Section Layout、Recent Shiori Resume Row Layout、Command Panel Secondary Layout）
- `docs/human/design/UI Application Rules.md`（菜单模态、Hover 与选中、指针）

# 需求描述

## 1. 目标

Recent Shioris 的呈现由 Resume Row 行列表改为与 Shiori 一级界面完全相同的卡片网格，并具备右键菜单。适用三个界面：Workbench Recent 一览、Workbench Recent Shioris、Command Panel Recent Shioris。

## 2. 卡片

1. 三处使用与 Shiori 一级界面完全相同的卡片：封面（右下角 cue 数徽章）、列表名、描述；卡片宽度与网格间距沿用一级界面。
2. Resume Row 的续读进度与最近一条 Shiori 内容不再显示。
3. 行分隔线取消。
4. Recent 一览中的 Recent Shioris 仍最多显示 5 个。
5. 卡片指针为手型，遵循应用规则的指针条款。
6. 排序不变，仍按最近使用。
7. Selected 与 Hover 为同一状态，遵循 Media Card 的既有规则；Recent 一览中视频卡片与 Shiori 卡片共用同一个高亮，同时只有一张亮。

## 3. 右键菜单

1. 三处的菜单项与 Shiori 一级界面完全一致：编辑列表、删除列表；列表总数为 1 时删除禁用。
2. 命中判定、打开与关闭行为遵循现有卡片右键菜单的通用规则。
3. Command Panel 中的编辑与删除照常打开对应对话框。

## 4. Command Panel 导航

1. Recent Shioris 由一维列表导航改为网格导航，方向键走位规则与 Recent Videos 一致。
2. 键盘选中项滚动可见的行为与 Recent Videos 一致。

## 5. 实现约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. 卡片与右键菜单为四个界面共用的一份实现，禁止按界面分别实现。
3. Resume Row 不再保留。

## 6. 设计文档同步

本需求验收通过后再更新设计文档：Recent Shioris Section Layout 改为卡片网格；删除 Recent Shiori Resume Row Layout；Command Panel Secondary Layout 的 Recent Shioris 内容改为卡片网格；Shiori List Card Layout 补充 Selected 状态与右键菜单项。

# 验收

1. 三处 Recent Shioris 与 Shiori 一级界面的卡片外观、尺寸、间距一致。
2. 三处均可右键打开菜单，菜单项与一级界面一致，只剩一个列表时删除禁用。
3. Command Panel 中编辑与删除可正常打开对应对话框。
4. Command Panel 中方向键在卡片网格内走位正确，键盘选中项滚动可见。
5. 卡片指针为手型；菜单打开期间遵循菜单模态与指针规则。
6. Recent 一览中的 Recent Shioris 最多 5 个，排序按最近使用。
7. Light 与 Dark 两个主题分别核对。
8. 现有自动化端到端与单元用例全部通过。