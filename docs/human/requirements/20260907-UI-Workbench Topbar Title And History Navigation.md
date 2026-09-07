# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`（App Topbar Layout、App Sidebar Layout、Workbench Titled Page Layout、Recent Overview Layout、Library Overview Layout、Workbench Page Title、Icon Button、Tabs、Tab、Empty State、Height）
- `docs/human/design/UI Application Rules.md`（指针）

# 需求描述

## 1. 目标

Workbench 各页的标题移入顶栏；顶栏增加后退与前进按钮，按浏览器式历史在 Workbench 页面间导航；Recent 合并为单层页面；退出播放页回到进入前的页面。

## 2. 顶栏

1. 新增 token `--height-workbench-topbar`：`54px`，为 Workbench 顶栏高度。`--height-app-topbar` 保留为红绿灯带高度，红绿灯位置不变；Settings 窗口与播放页不受影响。
2. 结构自左向右：红绿灯、Sidebar Toggle、后退、前进、标题、任务入口。Sidebar Toggle 保持在红绿灯带的中线上，位置不变；后退、前进、标题在顶栏内垂直居中，不与红绿灯对齐。
3. 后退与前进为 Icon Button / Default，图标 `chevron.left` 与 `chevron.right`，不可用时按 Icon Button / Disabled。
4. 标题为 Workbench Page Title，字号改为 `20px`，字重改为 `600`，左对齐，单行。Toggle 到后退、前进到标题的间距复用现有 Toggle 到后退的间距（`12px`）；后退到前进的间距为 `--spacing-1`（`4px`）。
5. 一级页标题为 Search、Recent、Library、File、Shiori；Library 与 Shiori 的二级页无标题。
6. 尺寸过渡期间后退与前进不接受点击且外观不变，与现有后退按钮一致。

## 3. 页面

1. Search、Recent、Library 一级页、File、Shiori 一级页移除页内标题，内容上移，页面顶部内边距不变。
2. Library 与 Shiori 的二级页布局不变。
3. Sidebar 顶部留白改为跟随 `--height-app-topbar`，Sidebar 的位置与内容不随顶栏加高而变。
4. Sidebar 移除 Recent Videos 与 Recent Shioris 两个子项，导航项为 Search、Recent、Library、File、Shiori。

## 4. Recent

1. Recent 只有一层。页面内容第一项为 Tabs：`Recent Videos`、`Recent Shioris`，左对齐，首个标签与页面内容左边界对齐，组件与摆法沿用 Library 一级页的 Tabs。
2. 默认选中 Recent Videos。Tab 选择在本次运行内跨界面保留，不持久化。
3. 每个 Tab 显示该类的全部条目，不显示计数。原一级页的分组标题、计数、箭头与两个二级页一并移除。
4. Tab 切换按 Library Tabs 的指针规则处理为界面切换。

## 5. 历史与后退、前进

1. 历史只在内存中，启动时以恢复的页面为第一条，退出 App 即清空。
2. 条目为页面身份：Search、Recent、Library 一级页、Library 某文件夹、File、Shiori 一级页、Shiori 某列表。Recent 的 Tab、二级页内的 Tab、搜索词都不属于条目。
3. 产生一步历史的动作：点击 Sidebar 切到另一区（落在该区一级页）、进入或离开 Library 文件夹、进入或离开 Shiori 列表、当前二级页被删除或消失时自动跳回一级页。
4. 位于某区的一级或二级页时点击该区的 Sidebar 项，页面不变，不产生历史。
5. 后退回到上一条，前进回到后退前的条目；后退后产生新历史时清空前进。位于首条时后退不可用，位于末条时前进不可用。
6. 后退与前进按下后指针恢复默认样式。
7. 不设置快捷键。

## 6. 未知页面

1. 后退或前进落到的 Shiori 列表已删除、Library 文件夹已不存在时，该条目保留，页面显示未知页面。
2. 顶栏标题：简体 `未知页面`、繁体 `未知頁面`、英文 `Unknown Page`。
3. 正文用 Empty Hint 显示：简体 `该页面已不存在`、繁体 `該頁面已不存在`、英文 `This page no longer exists.`。
4. Sidebar 高亮该条目所属的一级项。

## 7. 播放页

1. 进入播放页时记录当时的 Workbench 页面，包括 Recent 的 Tab、Shiori 列表与 Library 文件夹；退出播放页回到该页面。
2. 播放期间的任何操作都不改变退出后的落点，包括 Command Panel 搜索并播放、从 Command Panel 打开 Recent 视频或 Shiori、从 Playback Overlay 播放 Shiori、Deep Link。
3. 播放期间不产生历史。

## 8. 设计文档同步

本需求验收通过后再更新设计文档：Height 新增 `--height-workbench-topbar` 与顶栏控件间距 token；Workbench Page Title 字号与字重；App Topbar Layout 的结构、尺寸与状态；Workbench Titled Page Layout 去掉 Page Title；Recent 相关 Layout 改为单层 Tabs；App Sidebar Layout 移除两个子项；Tab 字号改为与实现一致的 `14px`；`UI Application Rules.md` 界面切换清单加入 Recent Tabs 与后退、前进。

# 验收

1. 五个一级页的标题显示在顶栏，页内不再有标题；顶栏高 54px，红绿灯、Sidebar Toggle 与 Sidebar 的位置与改动前一致。
2. 顶栏自左向右为红绿灯、Toggle、后退、前进、标题，标题 20px、字重 600，后退与前进间距 4px；Sidebar 收起时顺序不变。
3. Library 与 Shiori 二级页除顶栏外与改动前一致，顶栏无标题。
4. Sidebar 为五项，没有 Recent 子项。
5. 进入 Recent 默认显示 Recent Videos，Tabs 左对齐；切到 Recent Shioris 后去别的页再回来仍是 Recent Shioris，重启后回到 Recent Videos。
6. 刚启动时后退与前进均不可用。若不在 Search 则先点击 Search，再依次点击 Recent、Library、进入某文件夹；后退三次依次回到 Library 一级页、Recent、Search，前进三次原路返回。
7. 在 Library 二级页与 Shiori 二级页点击对应 Sidebar 项，页面不变，后退与前进可用状态不变；从别的区点击 Library 或 Shiori 回到一级页。
8. 切换 Recent Tabs 与 Library 的 Video/Metadata 不改变后退与前进的可用状态。
9. 后退回到 Library 一级页后点击 Shiori，前进变为不可用。
10. 进入某 Shiori 列表的二级页，后退，删除该列表，前进，显示未知页面，标题与正文文案正确，Sidebar 高亮 Shiori；再后退回到 Shiori 一级页。
11. 分别从 Recent Shioris、Shiori 二级页、Library 二级页进入播放，播放中用 Command Panel 搜索并播放，退出后各自回到进入前的页面，后退与前进可用状态与进入前一致。
12. Light 与 Dark、简体、繁体、英文分别核对顶栏与未知页面。
13. 现有自动化端到端与单元用例全部通过。