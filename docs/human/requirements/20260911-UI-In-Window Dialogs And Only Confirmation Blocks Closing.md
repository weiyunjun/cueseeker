1# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级：红绿灯；更高层界面的屏蔽）
- `docs/human/design/UI Design System.md`（Dialogs）

# 需求描述

## 1. 对话框由 App 绘制

1. Edit Cover、Shiori List Editor、Rename、任务界面、Confirmation 五个对话框改为在主窗口内由 App 绘制，不再使用系统 sheet。
2. 除本需求列出的变化外，对话框的位置、外观、压暗、阴影、动画、叠加、输入屏蔽、键盘与焦点与改动前一致。
3. 压暗覆盖整个窗口，红绿灯除外。

## 2. 窗口操作

1. 对话框打开期间，红绿灯、移动窗口与缩放窗口属于窗口，不受对话框屏蔽。
2. 对话框打开期间，窗口顶部顶栏高度内除红绿灯外的区域：拖动可移动窗口，双击可缩放窗口。

## 3. 只有 Confirmation 阻止关闭 App

1. Confirmation 位于最上层时，红灯不可用，Cmd+Q 与 Dock 菜单中的退出不生效，Confirmation 保持打开。
2. 其它对话框位于最上层时，红灯、Cmd+Q 与 Dock 菜单中的退出与没有对话框时一致，对话框正在保存时也一样；App 直接关闭，未保存的内容直接放弃，不提示。
3. 对话框叠加时以最上层为准：任务界面上打开的 Confirmation 期间阻止关闭，该 Confirmation 关闭后恢复可关闭。
4. 系统关机、重启、注销在任何对话框打开时都不被阻止；此时 Confirmation 等同点击 Cancel，所确认的操作不执行。

## 4. 保持不变

1. 系统文件选择框（Choose Image、Add Folder、导出保存位置）保持系统行为。
2. 黄灯与绿灯不变。
3. Settings 窗口不属于本需求。

# 验收

1. 改动前后分别截图五个对话框，浅色与深色各一次，包含任务界面上叠加 Confirmation：除本需求的变化外，画面一致。
2. 打开与关闭五个对话框：动画与改动前一致。
3. 打开 Edit Cover：红灯可用，点击后 App 关闭。
4. 分别打开 Shiori List Editor、Rename、任务界面，重复第 3 条。
5. 打开 Edit Cover，按 Cmd+Q：App 退出；从 Dock 菜单选择退出：App 退出。
6. 打开任一 Confirmation：红灯不可用；Cmd+Q 与 Dock 菜单中的退出均不生效，Confirmation 保持打开。
7. 在任务界面上打开移除确认：红灯不可用；取消后回到任务界面，红灯恢复可用。
8. 打开任一 Confirmation 后注销：注销不被 CueSeeker 中断，所确认的操作没有执行。
9. 对话框打开期间：点击、hover、滚轮与键盘均不作用于下层；在顶栏高度内（红绿灯除外）拖动可移动窗口，双击可缩放窗口。
10. 对话框中回车、Esc、空格、Tab 与焦点的表现与改动前一致。