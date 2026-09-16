# 版本

main

# 关联设计

- `docs/human/design/UI Application Rules.md`（界面层级、更高层界面的屏蔽）
- `docs/human/requirements/20260911-UI-In-Window Dialogs And Only Confirmation Blocks Closing.md`

# 需求描述

## 1. 现状

1. 在 Search 或 Shiori 表格进入 Select 模式，勾选若干行后 Export to Anki，在对话框点击 Export 或 Cancel，退出 Select 模式：之后点击任意结果行无反应，hover 正常；点击搜索框无反应。Library 与 Recent Videos 可正常点击进入播放页。
2. Export to Anki 对话框打开期间，下层表格仍有 hover，播放快捷键仍生效。

## 2. 要求

1. Export to Anki 对话框与 Edit Cover、Excerpt List Editor、Rename、Filter、任务界面、Confirmation 同样属于对话框层，打开期间按“更高层界面的屏蔽”规则屏蔽下层。
2. 对话框以任何方式关闭后，页面恢复接受输入：表格行可点击播放，搜索框可点击聚焦输入。

# 验收

1. 按第 1 节第 1 条复现路径操作，对话框关闭后点击 Search 与 Shiori 的结果行可进入播放页，点击搜索框可聚焦并输入。
2. Export 与 Cancel 两种关闭方式各验一次。
3. Export to Anki 对话框打开期间，表格无 hover，播放快捷键无效。
4. 现有自动化端到端与单元用例全部通过；不为本需求新增 E2E 能力。
5. 第 1 至 3 条人工验收。