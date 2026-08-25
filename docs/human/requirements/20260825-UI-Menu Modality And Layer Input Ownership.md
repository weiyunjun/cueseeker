# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`
- `docs/human/design/UI Design System.md`
  - `Components / 2.4 Menus`
  - `Layouts / 3.5 Filter Panel`
  - `Layouts / 3.8 Playback Overlay`
  - `Layouts / 3.9 Command Panel`

# 需求描述

## 1. 适用范围

五个菜单：Workbench 表格行右键菜单、Workbench 卡片与封面右键菜单、
视频播放倍速菜单、Playback Overlay 选中文字菜单、
Command Panel 选中文字菜单。

## 2. 界面层级

由低到高：

1. 页面：工作台页面；播放页视频与控制条。
2. 页面内浮层：Selection Action Overlay；Playback Overlay
   （Current、Playlist、Collage Editor 是它的同层模块）。
3. Command Panel，高于 Playback Overlay。
4. 菜单：归属于打开它的宿主层，只高于宿主自身，不高于任何更高层界面。
5. 对话框：Edit Cover、Shiori List Editor、Confirmation。

Toast 与播放反馈只有视觉，不接受任何输入，不参与层级归属。

Filter Panel 是页面内容，不是浮层。

## 3. 更高层界面对下层的屏蔽

1. 同一时刻只有最上层的可交互界面接受指针、滚轮与键盘。
2. 更高层界面打开时，下层完全不接受输入，并且视觉冻结：当前项、高亮与
   选中都停在原处，不清空，也不跟随指针。
3. 更高层界面打开不关闭下层已经打开的菜单。被冻结的菜单保持显示，
   不接受输入。
4. 更高层界面关闭后，下层恢复接受输入，冻结前的状态继续有效。
5. 恢复之后，下层的高亮只在指针真实移动之后才改变。

## 4. 菜单打开时禁止的事件

1. 禁止的是事件本身，与触发它的输入设备无关。
2. 快捷键不在禁止范围内。
3. 滚动：下列四个菜单打开期间，整个窗口禁止滚动 —— 表格行右键菜单、
   卡片与封面右键菜单、Playback Overlay 选中文字菜单、
   Command Panel 选中文字菜单。
4. 倍速菜单打开期间不禁止滚动。

## 5. 菜单打开时的通用操作规则

1. 上下键、回车与 Esc 归菜单。
2. 在菜单之外按下左键或右键，该次按下只用于关闭菜单，不传给下层。
3. 中键不关闭菜单。
4. 菜单打开期间，下层不得出现任何 hover 或选中的视觉变化。
5. 菜单的挂靠对象在菜单打开期间保持它打开时的高亮：右键菜单是被右键
   点中的行或卡片，倍速菜单是倍速按钮，选中文字菜单是被选中的文字。

## 6. 作废与更正的旧规则

1. 作废 `docs/human/requirements/20260824-UI-Menu Placement And Outside
   Interaction.md` §5.1 与验收第 5 条：「菜单打开期间，其余界面保留完整的
   Hover、滚动与点击能力」。
2. 同一文档验收第 2 条中由滚动触发跟随的部分作废；§4.1 的跟随规则本身
   继续有效，改由窗口缩放与布局变化触发。
3. 同一文档 §1 中「表格行菜单（⋯ 按钮与右键）」更正为：表格行菜单只由
   右键弹出，表格行没有 ⋯ 按钮。
4. 作废 `docs/human/requirements/20260824-UI-Overlay Layer Priority And
   Input Ownership.md` §4 与验收第 3、4 条：「打开 Command Panel 时立即
   关闭倍速菜单与选中文字菜单」。该文档 §2、§3 继续有效，其中界面层级由
   本需求 §2 取代。

## 7. 保持不变

1. 菜单的挂靠、方向、跟随与表格裁剪沿用
   `20260824-UI-Menu Placement And Outside Interaction.md` §2 至 §4。
2. 菜单的高亮、键盘导航与鼠标规则沿用
   `20260824-UI-Menu Highlight And Single Selection.md`。
3. 不新增、不修改、不替换任何颜色、尺寸、圆角与间距 Token。
4. 除本需求要求的冻结与挂靠对象保持高亮外，不改变任何界面的视觉表现。

# 验收

1. 四个禁止滚动的菜单，任一打开期间，滚轮在窗口任意位置都不产生滚动；
   菜单关闭后滚动恢复。
2. 倍速菜单打开期间滚轮行为与打开前一致。
3. 四个菜单打开期间，指针移到下层任何行或卡片上，都不出现 hover 或
   选中的视觉变化。
4. 右键菜单打开期间，被右键点中的行或卡片保持高亮，直到菜单关闭。
5. 先打开倍速菜单再打开 Command Panel：倍速菜单保持显示且不接受输入；
   上下键、回车与 Esc 归 Command Panel；点击 Command Panel 内任意位置，
   倍速菜单不关闭，该次点击由 Command Panel 正常响应。
6. 关闭 Command Panel 后，倍速菜单恢复响应上下键与回车。
7. 先打开选中文字菜单再打开 Command Panel，行为与第 5、6 条一致。
8. 打开对话框时，下层的当前项停在原处不清空；关闭对话框后，指针真实
   移动才改变当前项。
9. 菜单打开期间快捷键仍然生效。
10. 第 3、4 条依赖 Hover：Workbench 表格使用现有自动化端到端测试覆盖，
    SwiftUI 卡片与菜单使用人工验收。其余使用现有自动化端到端测试覆盖，
    不为本需求新增鼠标或键盘能力。

# UI 文档同步

验收完成后，由人类维护者更新并提交：

1. `UI Application Rules.md`：新增界面层级清单、更高层屏蔽与冻结规则、
   菜单模态规则，并逐菜单声明其禁止的事件。
2. `UI Design System.md`：
   - `2.4 Menus / Menu` 补 Modality：打开期间禁止的事件、挂靠对象保持高亮。
   - `3.9 Command Panel Root Layout / Layer` 删除「打开时关闭下层已展开的
     菜单」。
   - `3.8 Playback Overlay Layout` 的 `Covered` 状态补「菜单不关闭」。
   - `Filter Panel Layout / Position / Flow` 由 `Overlay` 更正为页面内容。
   - `2.6 Table Row` 与 `2.11 Media Card` 状态表补菜单打开期间的冻结与
     挂靠对象保持高亮。