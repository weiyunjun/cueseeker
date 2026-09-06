# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（Sidebar、Sidebar Item、Workbench Titled Page Layout、Button / Neutral、Button / Destructive、Confirmation Dialog、Empty State、Settings Sidebar Layout、Library Overview Layout、Library Folder Detail Layout、Tabs、Tab）
- `docs/human/design/UI Application Rules.md`（指针）

# 需求描述

## 1. 目标

Settings 的 Library 类别整体迁出，成为一级页面 File；Library 一级与二级界面的 File 分段改名为 Metadata。

## 2. 边栏

1. 新增一级项 `File`，位于 Library 与 Shiori 之间，图标为文件夹。
2. Library 的图标改为 `square.grid.2x2`，让出文件夹图标。
3. 其余一级项、子项与 Settings 入口的位置和图标不变。

## 3. File 页面结构

使用 Workbench Titled Page Layout，自上而下依次为：

1. 页标题 `File`
2. 说明文字
3. `Add Folder` 与 `Index Now` 按钮
4. 索引状态区
5. 根目录列表

## 4. 说明文字

1. 位于页标题下方，左对齐，整段换行，使用 `--font-size-body` 与 `--color-text-secondary`。
2. 英文文案：`A subtitle file is paired with the video that shares its file name. Videos and subtitles in the same folder form one group, named after that folder; subfolders are not included.`
3. 简体与繁体各配一条同义文案。

## 5. 动作按钮

1. 位于说明文字下方，左对齐，从左到右为 `Add Folder`、`Index Now`，间距 `--spacing-2`。
2. 两者均为 Button / Neutral，图标与文案沿用现有取值，图标颜色维持次级灰。
3. 可用与置灰条件维持现状。

## 6. 索引状态区

1. 位于按钮下方，显示内容与显示逻辑完全维持现状：索引中、索引完成及其统计、索引失败、移除中、移除完成依次轮换。
2. 从未索引过时不显示任何内容，该区域不占位。
3. 成功态的绿色改用新增的 `--color-success-text`，不再使用系统默认绿色。
4. 数据库路径不再显示，也不迁移到其它位置。

## 7. 根目录列表

1. 位于状态区下方，行结构维持现状：左侧上为文件夹名、下为完整路径，右侧为 Remove 按钮，行间有分隔线。
2. Remove 改为 Button / Destructive，图标与文案同为 `--color-danger-text`。
3. 点击 Remove 仍弹出二次确认对话框，行为不变。
4. 一个根目录都没有时，显示与现状相同的 Empty State。

## 8. Settings 删除

1. 删除 Settings 的 Library 类别及其边栏入口。
2. 其功能全部由 File 页面承接，不改由 Toast 或任务面板承担。

## 9. 联动改动

1. Library 一级界面右上角的 `Add Folder` 按钮改为跳转到 File 页面。
2. 所有指向“在 Settings 中添加字幕文件夹”的空状态文案，统一改为指向 File 页面。
3. Library 一级与二级界面的分段 `Video / File` 改名为 `Video / Metadata`，仅改名称，内容与交互不变。

## 10. Token 变更

1. 新增 `--color-success-text`：Light `#047857`；Dark `#6EE7B7`。
2. Button / Destructive 的 Icon Color 由 `--color-text-secondary` 改为 `--color-danger-text`。

## 11. 样式约束

1. 禁止硬编码，所有视觉值必须可表达为 Design System 的 token 或组件规则。
2. File 页面的按钮、空状态、确认对话框复用现有组件，禁止另起一份实现。

## 12. 设计文档同步

本需求验收通过后再更新设计文档：`UI Design System.md` 新增 `--color-success-text`，修改 Button / Destructive 的 Icon Color，新增 File 页面的布局章节，边栏一级项清单补入 File 并更新 Library 图标，Library Overview Layout 与 Library Folder Detail Layout 的 Tabs 改为 `Video`、`Metadata`；`UI Application Rules.md` 指针规则 3 的界面切换清单中的 `Video/File` 改为 `Video/Metadata`。

# 验收

1. 边栏一级项自上而下为 Search、Recent（含两个子项）、Library、File、Shiori，Library 为网格图标，File 为文件夹图标。
2. 点击 File 进入页面，依次可见页标题、说明文字、左对齐的 Add Folder 与 Index Now、索引状态区、根目录列表。
3. 全新状态下（从未索引）状态区不占位，按钮与列表紧邻。
4. 执行一次 Index Now，状态区依次出现索引中与索引完成，完成态文字为新的成功色。
5. 一个根目录都没有时显示 Empty State；添加文件夹后出现对应行，行内为文件夹名与完整路径。
6. Remove 按钮文字与图标同为红色，点击后弹出二次确认，取消不移除，确认后该行消失。
7. Settings 边栏不再有 Library 类别，该页面不可达；应用内不再显示数据库路径。
8. Library 一级界面点击 Add Folder 跳转到 File 页面。
9. 未添加任何文件夹时，Library 与 Search 的空状态文案指向 File 页面。
10. Library 一级与二级界面的分段显示为 Video 与 Metadata，两者内容与改动前一致。
11. 确认对话框中的 Destructive 按钮外观与改动前一致。
12. Light 与 Dark 两个主题分别核对第 2、4、6 项。
13. 简体、繁体、英文三种语言分别核对说明文字与按钮文案。
14. 现有自动化端到端与单元用例全部通过。