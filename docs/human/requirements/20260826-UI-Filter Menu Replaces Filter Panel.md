# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Icon Button、Menu、Menu Item、Menu Divider、Checkbox / Filter Checkbox、Search / Shiori Toolbar Layout、Filter Panel Layout）
- `docs/human/design/UI Application Rules.md`（菜单模态、界面层级）

# 需求描述

## 1. 目标

页面内的筛选面板（Filter Panel）改为挂靠筛选按钮弹出的筛选菜单（Filter Menu）。适用于 Search 与 Shiori 详情两个界面。

## 2. 筛选按钮

1. 改为纯图标按钮：无文字、无边框，复用现有 Icon Button，图标沿用现有筛选图标。
2. 菜单打开期间，按钮背景为 macOS accent color，前景为白色（与边栏选中一致的视觉），通过新增 token 表达，不复用边栏 token。
3. 点击按钮打开菜单；菜单打开时点击按钮之外任意处关闭菜单（含按钮自身所在区域外的点击遵循菜单通用规则）。

## 3. 筛选菜单结构

1. 从上到下：标题、横线、Duration 与四个选项、横线、Character 与四个选项、横线、Language 与若干选项、横线、Watch Status 与三个选项。
2. 分节头带图标，沿用现有各分组图标。
3. 选项行：圆形 checkbox + 标签 + 右侧计数；计数与 calculating 的表现沿用现有筛选面板。
4. 原面板的卡片式框线不再存在；无 Reset / Cancel / Apply。
5. 菜单高度超过上限时出现内部滚动条，遵循现有菜单滚动条规则。

## 4. 筛选菜单交互

1. 勾选即时生效，勾选后菜单不关闭；Draft / Apply / Cancel / Reset 状态机废弃。
2. 左键点击或回车勾选/取消勾选当前高亮项；鼠标的勾选区域与 hover 区域一致，为整行。
3. 标题、分节头、横线不可高亮，键盘导航自动跳过；打开时默认高亮首个可选项（即 Duration 的 <1s），由菜单通用规则给出。
4. 其余交互全部遵循菜单通用规则：点外部关闭、打开期间下层无 Hover、整窗口禁止滚动、所属界面切换时关闭、Esc 关闭。
5. 菜单默认关闭；切换到其它页面再切换回来为关闭状态。

## 5. 新增菜单通用规则

适用于全部菜单：

1. 键盘上下键与真实的鼠标 hover 改变高亮；滚轮滚动与拖拽滚动条本身不改变高亮。
2. 键盘导航后，若高亮项不在可见范围内，菜单滚动使其可见。

## 6. 样式约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. 禁止为单个界面增加私有实现；Search 与 Shiori 详情共用同一实现。

## 7. 设计文档同步

本需求验收通过后再更新两份设计文档：Icon Button 增加打开状态与新 token；Menu 增加标题、分节头、筛选选项行三种元素及第 5 节通用规则；Toolbar Layout 的 Filter Trigger 改为 Icon Button；删除 Filter Panel Layout 及其相关 token；界面层级中 Filter Panel 的描述删除。

# 验收

1. 筛选按钮为纯图标无边框；默认透明背景，hover 出现灰底；菜单打开期间 accent 背景白色前景。
2. 菜单结构顺序与分节头图标正确，选项行的 checkbox、计数、calculating 表现与原面板一致。
3. 打开时默认高亮 <1s；上下键与真实 hover 移动高亮；滚轮与拖拽滚动条不移动高亮。
4. 键盘导航到可见范围外的选项时，菜单滚动使其可见。
5. 左键与回车可勾选/取消勾选，立即生效于表格结果，菜单保持打开。
6. 菜单遵守菜单通用规则：点外部关闭、打开期间下层无 Hover、整窗口禁止滚动、切换页面关闭、Esc 关闭。
7. 默认关闭；打开后切换页面再返回为关闭状态。
8. 菜单出现内部滚动条且不改变菜单宽度。
9. Search 与 Shiori 详情两界面行为一致。
10. 现有自动化端到端与单元用例全部通过。