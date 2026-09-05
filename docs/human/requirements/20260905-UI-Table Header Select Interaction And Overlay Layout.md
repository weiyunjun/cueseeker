# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Table Header Cell、Selection Action Overlay、Selection Action Overlay Layout、Search / Shiori Table Layout、Button / Neutral）
- `docs/human/design/UI Application Rules.md`（菜单模态、Hover 与选中、指针）

# 需求描述

## 1. 范围

Workbench Search 表格与 Shiori 二级界面表格，两者行为一致。

## 2. 表头在 Select 状态下的样式与交互

1. 进入 Select 状态后，表头列标题保持 `--color-text-secondary`，不使用 Disabled 色。表头高度、字号、字重、内边距、底部分隔线均不变。
2. `#` 列在 Select 状态下仍显示全选 Checkbox，其余列标题文字不变。
3. Select 状态下点击表头任意位置，效果与点击全选 Checkbox 一致；表头整条为一个点击区域，包含列标题文字所在区域。
4. 表头不提供 Hover 反馈，指针保持箭头。
5. 普通状态下表头不响应点击，行为不变。
6. Select 状态下表头文字框选保持关闭，不变。

## 3. Selection Action Overlay 布局与 Exit

1. Overlay 改为两行：第一行 `N selected`，第二行动作按钮。锚点仍为表格视口底部居中。
2. `N selected` 左对齐到按钮行起点，颜色仍为 `--color-text-muted`。
3. 按钮行顺序：Anki、Copy Deep Links、Copy Table、Exit。
4. 新增 Exit 按钮，Button / Neutral，图标 `xmark`，文字 `Exit`，与其余三个按钮同间距，不加分隔线。Overlay 可见期间始终可用。
5. 点击 Exit 退出 Select 状态，与点击工具栏 Select 按钮关闭选择模式完全一致，包括清空已选行。
6. 尺寸：两行间距 `--spacing-2`，按钮行内间距 `--spacing-3`，Overlay Padding Inline `--spacing-3`、Padding Block `--spacing-2`。不新增 token。
7. 显隐条件不变：选中行数为 0 时隐藏。

## 4. 筛选菜单水平边界

1. 筛选菜单的右边界不越过页面内容框右边界。页面内容框即工具栏与表格所在的区域，其右边界与表格行分隔线右端、Select 按钮右边缘一致。
2. 菜单仍优先与筛选按钮左边缘对齐；放不下时贴页面内容框右边界。
3. 菜单的宽度、垂直位置、与按钮的间距、开合与键盘行为不变。

## 5. 文档同步

验收后在 `UI Design System.md` 同步：Table Header Cell 增加 Select 状态下的颜色与整条点击说明；Selection Action Overlay 与 Selection Action Overlay Layout 改为两行结构、补入 Exit、修正 Content Gap 与 Padding 取值。

## 6. 保持不变

1. 三个原有动作按钮的功能、文案、图标不变。
2. 行的 Hover、Selected 外观与行内 Checkbox 不变。
3. 表格列宽、排序、滚动条与横向滚动行为不变。
4. 菜单模态、按住不改变外观、指针规则不变。

# 验收

1. 进入 Select 状态，表头列标题颜色与普通状态一致，无变灰。
2. Select 状态下点击表头空白处、列标题文字处，全选状态与点击 Checkbox 一致；再次点击可全部取消。
3. 普通状态下点击表头无任何反应；表头悬停无底色，指针为箭头。
4. 选中至少一行后，Overlay 为上下两行，`N selected` 在上并与 Anki 按钮左边缘对齐。
5. Exit 按钮位于按钮行最右侧，图标为 `xmark`，点击后退出 Select 状态且选中被清空。
6. 打开筛选菜单，菜单右边缘与表格行分隔线右端对齐，不再探出到页面右边距上。
7. 拖动窗口宽度到最小与较大宽度，第 4、6 两项仍成立。
8. Search 与 Shiori 两个表格分别核对以上各项。
9. Light 与 Dark 两个主题分别核对以上各项。
10. 本次改动不新增任何自动化端到端或单元用例的失败。