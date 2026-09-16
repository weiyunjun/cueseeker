# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Filter Chip、Button、Information Badge / Task Count Badge、Search / Excerpt Toolbar Layout、Filter Dialog Layout）

# 需求描述

## 1. 范围

Search 与 Excerpt 的 Filter Dialog，以及两处工具栏的 Filter Trigger。

## 2. 改动

### 2.1 Filter Chip

1. 圆角由胶囊形改为 `--radius-control`，其余外观不变。

### 2.2 Footer

1. 删除左侧的 Calculating Status。
2. Reset 移到 Footer 左侧；Cancel、Show 仍靠右。
3. 总数未知时（Search 搜索进行中、Excerpt 列表加载中），Show 的内容为 Spinner 与 `Calculating`，保持 Disabled；总数得出后显示 `Show N results` / `Show N excerpts`。

### 2.3 选中数量

1. Filter Trigger：图标右侧显示表格当前生效的筛选中选中的选项总数，外观同 Task Count Badge，为 0 时隐藏。
2. Section Header：名称右侧显示该组在对话框中当前选中的选项数，外观同 Task Count Badge，为 0 时隐藏。

## 3. 保持不变

1. Reset 的 Disabled 条件，以及 Cancel 与 Show 的行为不变。
2. 计数未知时 Filter Chip 内的占位块不变。

# 验收

1. Light 与 Dark 下，Filter Chip、Footer，以及 Filter Trigger 与 Section Header 的数字，外观与本文一致。
2. 搜索进行中打开 Filter，Show 显示 Spinner 与 `Calculating` 且不可点击；搜索完成后恢复为带数量的 Show。
3. 在对话框中改变选择时，Section Header 的数字随之更新；点击 Show 后，表格与 Filter Trigger 的数字随之更新。
4. 本次改动不新增任何自动化端到端或单元用例的失败。