# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Table Row、Table Header Cell、Selection Action Overlay、Selection Action Overlay Layout）
- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽、Hover 与选中）

# 需求描述

## 1. 范围

Workbench Search 表格与 Shiori 二级界面表格，两者行为一致。

## 2. 最近选中行

1. 最近选中行指最近一次产生选中的操作所选中的行中，下标最大的那一行。
2. 取消选中的操作不改变最近选中行。
3. 点击表头全选后，最近选中行为表格最后一行。
4. 选中被清空时最近选中行一并清空；行集合平移或裁剪时它跟随，若被裁掉则取当前选中行中下标最大的一行。

## 3. Select 状态下的 Shift 多选

按住 Shift 用鼠标左键点击第 K 行：

1. 当前没有任何行被选中：选中第 1 行到第 K 行的全部行。
2. 当前有行被选中，且第 K 行已选中：只取消第 K 行的选中。
3. 当前有行被选中，且第 K 行未选中：选中第 K 行到最近选中行之间的全部行，含两端。

补充：

4. 与不按 Shift 时一致，行内任意位置都是点击区域。
5. Shift 点击表头与不按 Shift 时一致。
6. 非 Select 状态下按住 Shift 点击，行为与不按 Shift 时完全一致。
7. 选中状态的存储方式不变。

## 4. Overlay 随 Select 状态显隐

1. 点击工具栏 Select 按钮进入 Select 状态时，Selection Action Overlay 立即出现，不再等待选中任意行；退出 Select 状态时消失。
2. 选中行数为 0 时计数文案显示 `0 selected`。
3. Anki、Copy Deep Links、Copy Table 三个按钮在 0 选中时不置为 Disabled，外观与可点击性不变。
4. Overlay 的位置、两行结构、间距与 Exit 行为不变。

## 5. Overlay 区域不透传 Hover

1. 指针位于 Selection Action Overlay 覆盖区域内时，下层表格不更新 Hover：行 Hover 停在指针进入 Overlay 之前的位置，不清除也不跟随指针。
2. 指针离开 Overlay 回到表格上时，Hover 在指针真实移动后恢复跟随。

## 6. 文档同步

验收后在 `UI Design System.md` 同步：Table Row 增加 Shift 区间选中说明；Selection Action Overlay Layout 的显隐条件改为随 Select Mode。在 `UI Application Rules.md` 同步：Selection Action Overlay 只屏蔽自身覆盖区域，区域之外下层表格照常接受输入。

## 7. 保持不变

1. 行的 Hover、Selected 外观与行内 Checkbox 不变。
2. 表头在 Select 状态下的样式与整条点击全选行为不变。
3. 键盘 Tab、Space 的选择行为不变。
4. 表格列宽、排序、滚动与横向滚动行为不变。

# 验收

1. 进入 Select 状态，Overlay 立即出现并显示 `0 selected`，三个动作按钮不呈 Disabled 外观。
2. 无选中时 Shift 点击第 5 行，第 1 至 5 行全部选中。
3. 承接上一步，Shift 点击第 3 行，只有第 3 行被取消，选中为第 1、2、4、5 行。
4. 承接上一步，Shift 点击第 8 行，选中为第 1、2、4、5、6、7、8 行。
5. 退出并重新进入 Select 状态，Shift 点击第 5 行，第 1 至 5 行选中；Shift 再点第 5 行，选中为第 1 至 4 行；Shift 点击第 7 行，选中为第 1 至 7 行。
6. 点击表头全选后 Shift 点击任意行，只取消该行。
7. 非 Select 状态下按住 Shift 点击任意行，行为与不按 Shift 一致。
8. 指针从表格移到 Overlay 上，表格行 Hover 停在移入前那一行不再变化；移回表格后随指针恢复。
9. Search 与 Shiori 两个表格分别核对以上各项。
10. Light 与 Dark 两个主题分别核对第 1、8 项。
11. 本次改动不新增任何自动化端到端或单元用例的失败。