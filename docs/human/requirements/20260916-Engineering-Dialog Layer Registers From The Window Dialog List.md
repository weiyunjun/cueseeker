# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽）
- `docs/human/requirements/20260911-UI-In-Window Dialogs And Only Confirmation Blocks Closing.md`
- `docs/human/requirements/20260916-Bug-Export To Anki Dialog Leaves Page Unable To Take Input.md`

# 需求描述

## 1. 现状

1. “哪些对话框算对话框层打开”记录在两处：窗口的对话框绘制列表，以及协调器里单独维护的一份观察列表。新增对话框必须两处同改，漏改观察列表不影响编译与显示，只在层级屏蔽与焦点上出错（见 20260916 Bug 需求单）。

## 2. 要求

1. 对话框层的打开与关闭只由窗口的对话框绘制列表决定：列表非空即打开，为空即关闭。删除协调器里单独的观察列表。
2. 一个对话框只要加入绘制列表，就自动登记为对话框层，不需要再改第二处。

## 3. 保持不变

1. 对话框打开时页面让出焦点，且只在页面仍持有焦点时让出；输入框有焦点时任何对话框一次点击即出现；自带输入框并在打开时聚焦的对话框照常聚焦。
2. 对话框打开期间键盘留在对话框内；关闭后页面恢复接受输入。
3. Confirmation 叠加、任务界面被 Confirmation 覆盖、系统文件面板与警告框期间的压暗规则不变。
4. 不改变任何对话框的外观、动画与产品行为。

# 验收

1. 逐一打开并关闭 Edit Cover、Excerpt List Editor、Rename、Filter、Export to Anki、任务界面、Confirmation：打开时下层无 hover、播放快捷键无效；关闭后表格行可点击播放、搜索框可聚焦输入。
2. 搜索框有焦点时点击筛选按钮与任务按钮，对话框一次点击即出现；打开 Rename，名称输入框获得焦点。
3. 单元测试覆盖“绘制列表非空即对话框层打开、为空即关闭”。
4. 现有自动化端到端与单元用例全部通过；不为本需求新增 E2E 能力。
5. 第 1、2 条人工验收。