# Data Indexed Content Management

## 版本

main

## 关联设计

- `docs/human/design/UI Design System.md`

## 当前范围

新增 Data 一级页面，用于呈现数据库中已经 Index 的内容。本阶段只实现文件树展示及展开、折叠，不实现编辑功能或右键菜单。

## 导航与状态

1. Data 位于 Sidebar 的 Library 下方、Shiori 上方。
2. 默认展开全部根路径，显示其下全部对象文件夹；对象文件夹默认折叠。
3. 离开 Data 后不保留展开状态，再次进入时恢复默认状态。
4. 已经位于 Data 时再次点击 Data，不重置当前展开状态。

## 数据与层级

1. 使用数据库真实数据，不使用 Mock 数据。
2. 层级为：根路径 → 对象文件夹 → Display Title 对象 → 视频与字幕。
3. 每个已配置路径显示为独立根节点。根节点显示完整路径，去掉开头的 `/`，例如 `Volumes/Samsung/影视/`。
4. 对象文件夹显示相对于根路径的完整路径，开头不带 `/`。
5. 每个 Display Title 对象包含一个视频和所有关联字幕，依次显示：
   - Display Title
   - 视频完整文件名
   - 字幕完整文件名
6. 沿用数据库现有排序，界面不进行二次排序。

## 布局与样式

1. 页面边界、颜色及滚动条复用现有 Workbench 设计系统。
2. 树行最小高度为 `40px`，上下 Padding 为 `8px`，行间距为 `0`。
3. 每深入一级缩进 `24px`。
4. 行结构为：`16px 箭头槽位 + 8px + 16px 图标 + 8px + 文字`。
5. 不可展开的文件行仍保留箭头槽位。
6. 所有名称必须完整显示，允许按字符换行，禁止截断和省略号。
7. 多行文字时，箭头和图标与文字第一行对齐。
8. 字体：
   - 根路径、对象文件夹、Display Title：`14px / Medium / Text Primary`
   - 视频、字幕：`14px / Regular / Text Secondary`
9. 图标：
   - 根路径、对象文件夹：Folder
   - Display Title：`rectangle.stack` 线框图标
   - 视频：Video
   - 字幕：Subtitle
10. Display Title、视频和每个字幕分别具有独立的整行 Hover。
11. 对象之间使用 Divider；Divider 从文件图标列开始，不贯穿整行。对象内部不显示 Divider。
12. 只提供纵向滚动。Scrollbar 位于页面最右侧，复用 Shiori 二级页面的共享 Scrollbar。

## 后续扩展边界

1. 后续编辑功能统一从对应树行的右键弹出菜单进入。
2. 本阶段不创建空菜单或编辑功能。
3. 节点使用稳定数据库 ID 标识，不使用名称或路径作为身份。
4. 新增 Data Layout 和少量可复用树行、对象组合组件，不建立通用递归树框架、排序状态或持久化机制。
5. 树行负责展示与交互区域，数据库修改不得写入展示组件。

## 设计记录

视觉验收完成后，由项目 Owner 将最终稳定规则更新至 `UI Design System.md`。