# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`
- `docs/human/design/UI Design System.md`
  - `Layouts / 3.8 Playback Overlay`
  - `Layouts / 3.9 Command Panel`

# 需求描述

## 1. 适用范围

播放页上可同时存在的界面：视频画面与播放控制条、Playback Overlay、
Command Panel、倍速菜单、选中文字菜单。

## 2. 界面层级

由低到高：页面 < Overlay < 菜单 < 对话框。

Playback Overlay 与 Command Panel 都属于 Overlay，Command Panel 位于
Playback Overlay 之上。

## 3. 输入归属

1. 同一时刻，只有最上层的可交互界面拥有键盘和滚轮。
2. Overlay 打开时，完全屏蔽下层界面的指针、滚轮与键盘，下层只保留视觉。
3. Command Panel 打开时，滚轮只作用于 Command Panel 自己的列表；
   Playback Overlay 的列表与滚动条不得响应。
4. Command Panel 打开时，上下键、回车与 Esc 归 Command Panel。

## 4. 打开更高层界面时关闭下层菜单

1. 打开 Command Panel 时，立即关闭已打开的倍速菜单与选中文字菜单。
2. 菜单关闭后不恢复，关闭 Command Panel 不重新打开它们。

## 5. 保持不变

1. 菜单自身的高亮、键盘导航与鼠标规则沿用
   `docs/human/requirements/20260824-UI-Menu Highlight And Single Selection.md`。
2. Command Panel 未打开时，Playback Overlay 的滚轮、滚动条与键盘行为不变。
3. 不新增、不修改、不替换任何颜色、尺寸、圆角与间距 token。
4. 不改变任何界面的视觉表现。
5. 菜单的定位与穿透规则不属于本需求。

# 验收

1. 在 Playback Overlay 中打开 Command Panel，滚轮只滚动 Command Panel
   的列表，Playback Overlay 的列表与滚动条不动。
2. 在 Playback Overlay 中打开 Command Panel，上下键、回车与 Esc 均由
   Command Panel 响应。
3. 先打开倍速菜单再打开 Command Panel：倍速菜单立即关闭，上下键与回车
   归 Command Panel。
4. 先打开选中文字菜单再打开 Command Panel：选中文字菜单立即关闭，
   上下键与回车归 Command Panel。
5. 关闭 Command Panel 后，倍速菜单与选中文字菜单不自动重新出现。
6. Command Panel 未打开时，Playback Overlay 的滚轮、滚动条与键盘行为
   没有回归。
7. 全部使用现有自动化端到端测试覆盖，不为本需求新增鼠标或键盘能力。

# UI 文档同步

验收完成后，由人类维护者更新并提交：

1. `UI Application Rules.md`：新增界面层级与输入归属规则。
2. `UI Design System.md` 的 `Playback Overlay Layout` 与
   `Command Panel Root Layout` 状态表：补充 Command Panel 打开时
   Playback Overlay 不接受输入。