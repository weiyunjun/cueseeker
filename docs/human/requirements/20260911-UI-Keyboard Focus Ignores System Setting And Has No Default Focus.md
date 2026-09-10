# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级、菜单模态）
- `docs/human/design/UI Design System.md`（Dialogs、各组件的 Focused 状态）

# 需求描述

## 1. 不受系统设置影响

1. CueSeeker 的键盘焦点不受 macOS「系统设置 → 键盘 → 键盘导航」开关影响，开与关表现完全一致。
2. 系统自身的界面（文件选择框、系统提示框、菜单栏）不属于本需求。

## 2. 没有默认焦点

1. 任何界面出现时都不自动获得焦点，包括 App 启动、页面切换、浮层、Command Panel、对话框与 Settings 窗口。
2. 例外：
   1. Confirmation 打开时，焦点在 Cancel 按钮。
   2. Rename 打开时，光标在新名称输入框。
   3. Command Panel 打开时，光标在搜索框。
3. 对话框关闭后，下层不恢复打开对话框之前的焦点。
4. 切换到其它 App 再切回，焦点保持离开时的状态。

## 3. Tab 与焦点

1. Tab 与 Shift-Tab 可以把焦点移到按钮等控件上，与系统开关打开时的现状一致；哪些控件参与、顺序如何，保持现状。
2. Tab 已有的专门用法不变：Playback Overlay 中切换 Current / Playlist / Collage，字幕表格中进入复选框。
3. 鼠标点击按钮不使按钮获得焦点；点击输入框照常获得光标。
4. 焦点只使用设计文档已定义的 Focused 外观，不显示系统自带的焦点环。

## 4. 保持不变

1. 回车与 Esc 的行为不变。
2. 菜单打开时取消焦点、菜单关闭后不恢复的规则不变。
3. 不新增、不修改任何 token。

# 验收

系统「键盘导航」开、关两种状态各验收一次，结果必须一致。

1. 启动 App：没有任何控件显示焦点。
2. 分别打开 Edit Cover、Shiori List Editor、任务界面：没有任何控件显示焦点，右上角 X 不被聚焦。
3. 打开 Rename：光标在新名称输入框，其它控件没有焦点。
4. 打开 Command Panel：光标在搜索框。
5. 打开任一 Confirmation：Cancel 显示焦点；按空格或回车等同点击 Cancel。
6. 在 Confirmation 中按 Tab：焦点在 Cancel、确认按钮与 X 之间移动。
7. 在 Workbench 中按 Tab：焦点可以移到按钮上，显示设计文档定义的 Focused 外观。
8. 用 Tab 把焦点移到某个按钮，用空格打开对话框后关闭：该按钮不再显示焦点。
9. 用鼠标点击任意按钮：按钮不显示焦点。
10. Playback Overlay 中按 Tab 仍切换 Current / Playlist / Collage。