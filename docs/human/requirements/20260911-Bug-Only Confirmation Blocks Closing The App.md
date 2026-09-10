# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级：红绿灯）
- `docs/human/design/UI Design System.md`（Dialogs）

# 需求描述

## 1. 只有 Confirmation 阻止关闭 App

1. Confirmation 打开期间，红灯不可用，Cmd+Q 与 Dock 菜单中的退出不生效。
2. Edit Cover、Shiori List Editor、Rename、任务界面打开期间，红灯、Cmd+Q 与 Dock 菜单中的退出与没有对话框时一致，对话框正在保存时也一样；App 直接关闭，对话框中未保存的内容直接放弃，不提示。
3. 对话框叠加时以最上层为准：任务界面上打开的 Confirmation 期间阻止关闭，该 Confirmation 关闭后恢复可关闭。
4. 系统关机、重启、注销在任何对话框打开时都不被阻止，Confirmation 也不例外；此时 Confirmation 等同点击 Cancel，所确认的操作不执行。

## 2. 保持不变

1. 系统文件选择框（Choose Image、Add Folder、导出保存位置）保持系统行为。
2. 黄灯与绿灯不变。
3. 对话框的压暗、输入屏蔽与呈现方式不变。

# 验收

1. 打开 Edit Cover：红灯可用，点击后 App 关闭。
2. 分别打开 Shiori List Editor、Rename、任务界面，重复第 1 条。
3. 打开 Edit Cover，按 Cmd+Q：App 退出。
4. 打开 Edit Cover，从 Dock 菜单选择退出：App 退出。
5. 打开任一 Confirmation：红灯不可用；Cmd+Q 与 Dock 菜单中的退出均不生效，Confirmation 保持打开。
6. 在任务界面上打开移除确认：红灯不可用；取消后回到任务界面，红灯恢复可用。
7. 打开任一 Confirmation 后注销：注销不被 CueSeeker 中断，所确认的操作没有执行。