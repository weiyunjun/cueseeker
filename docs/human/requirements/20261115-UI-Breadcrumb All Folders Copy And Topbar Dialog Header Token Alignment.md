# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **`File` 界面 `All Folders` 文案修正（`L-04.5 File Page Layout`）**：
   - 无论已入库的根文件夹数量为 `1` 个还是多个，`File` 一级界面列表上方标题与二、三级界面面包屑最左侧起点在英文下统一固定显示 `All Folders`（简中：`全部文件夹`，繁中：`全部資料夾`），移除根文件夹数量为 `1` 时显示 `All Folder` 的语法错误分支。

2. **面包屑去 Hover、统一字重及 `File` 一级标题同步（`C-05.6 Breadcrumb`、`L-04.5 File Page Layout`、`L-06.4 WebDAV / SMB / FTP / NFS Folder Dialog Layout`）**：
   - `C-05.6 Breadcrumb` 未激活上级节点（`Link Item`）移除悬停变色效果（`Hover: None`），文字维持字号 `--font-size-body`（`14px`）、字重 `--font-weight-control`（`500`）、颜色 `--color-text-secondary`；
   - `C-05.6 Breadcrumb` 当前所在末级节点（`Current Item`）字重由 `600` 调整为 `--font-weight-control`（`500`），字号 `--font-size-body`（`14px`）、颜色 `--color-text-primary` 与不可点击无 Hover 表现保持不变；分隔符 `caret-right` 尺寸引用 `--size-breadcrumb-separator`（`12px`），颜色 `--color-text-muted` 与间距 `--spacing-2` 保持不变；
   - 上述 `C-05.6 Breadcrumb` 规则在 `File` 二/三级界面与远程文件夹弹窗（`WebDAV` / `SMB` / `FTP` / `NFS`）第 2 步目录浏览中统一共用生效；
   - `File` 一级界面顶部的 `All Folders` 标题字重同步由 `600` 调整为 `--font-weight-control`（`500`），字号 `--font-size-body`（`14px`）与颜色 `--color-text-primary` 保持不变，使一级与二/三级切换时左上角 `All Folders` 字重与字宽一致无跳变。

3. **补齐缺失 Tokens 并对齐顶栏、标签页与弹窗标题规范（`UI Tokens.md`、`C-05.4 Tabs`、`C-05.5 Tab`、`C-10.1 Dialog`、`L-01.2`、`L-03.1`、`L-06.9`、`L-07.1`、`L-08.2`）**：
   - 新增 7 个设计 Tokens：
     - `1.2 字体与文本 -> Typography`：`--font-weight-tab: 600`、`--font-size-dialog-title: 20px`、`--font-weight-dialog-title: 600`；
     - `1.3 尺寸 -> Height`：`--height-tab-indicator: 2px`、`--height-window-controls-band: 45px`；
     - `1.3 尺寸 -> Size`：`--size-breadcrumb-separator: 12px`、`--width-tab-indicator: 24px`；
     - `1.6 动效 -> Interaction Motion`：`--easing-tab-motion: cubic-bezier(0.22, 1, 0.36, 1)`；
   - `Recent` 顶栏、`Playback Overlay` 顶栏与 `Task` 面板头部共用的 `C-05.4 Tabs` / `C-05.5 Tab` 统一引用上述标签页 Tokens；全部 `C-10.1 Dialog` 弹窗标题统一引用上述弹窗标题 Tokens；工作台顶栏侧边栏展开态功能区左侧内边距统一引用既有 `--spacing-6`（`24px`），播放器与 `Playback Overlay` 顶栏返回按钮边距统一对齐既有 `--padding-player-topbar-x`（`16px`）与 `--gap-player-window-controls-return`（`16px`），消除局部硬编码，视觉表现保持不变。

4. **`Task` 面板头部对齐标准弹窗视觉边界（`C-10.1 Dialog`、`L-06.9 Task Panel Layout`）**：
   - 移除 `Task` 面板头部私自绑定的分段控制器高度（`32px`）及行内未做字形补偿的关闭按钮特殊实现：左上角 `Task` 标题首行顶部（Cap 顶）与右上角 `Dialog Close` 关闭按钮（可见字形墨迹边缘）严格贴齐所有 `C-10.1 Dialog` 共用的四边 `--inset-dialog`（`24px`）视觉边界；中间 `Current / Completed / Incomplete` 标签页在头部行内保持与标题垂直居中、默认水平居中、窄宽下至少 `--spacing-3` 间距避让及左侧标题截断规则。

5. **设计文档同步安排**：
   - 关联 UI 设计文档待本次改动验收与视觉微调完成后再统一提交更新。

# 验收标准

1. **`File` 界面 `All Folders` 文案验收**：当 `File` 界面仅添加 `1` 个根文件夹或添加多个根文件夹时（含中英文切换），一级界面列表上方标题与二、三级界面面包屑最左侧节点在英文下均固定显示为 `All Folders`（不再出现 `All Folder`），简/繁中文保持 `全部文件夹` / `全部資料夾`。
2. **面包屑与 `File` 一级标题样式验收（Light & Dark）**：在 `File` 二/三级界面及 `WebDAV` / `SMB` / `FTP` / `NFS` 远程目录浏览第 2 步中，未激活上级面包屑节点鼠标移入不再变色（无 Hover 效果），未激活节点与当前末级节点字号均为 `14px`、字重均为 `500`（仅颜色区分 `--color-text-secondary` 与 `--color-text-primary`）；从 `File` 一级界面下钻至二级界面时，左上角 `All Folders` 字重保持 `500` 无粗细或字宽跳变；点击跳转、无障碍焦点环与整条禁选/跨区起选行为正常。
3. **顶栏与共用 `Tabs` 零硬编码与零退步（Light & Dark）**：`Recent` 顶栏、`Playback Overlay` 顶栏与 `Task` 面板头部的 `Tabs` 文字字重、底线宽高及切换滑动过渡正常，红绿灯控制带、顶栏左右边距及返回按钮位置与原表现一致，相关参数全部收口至统一设计 Token，无局部魔法数字或临时常量残留。
4. **`Task` 面板头部视觉边界与交互验收（Light & Dark）**：打开 `Task` 面板时，左上角 `Task` 标题首行顶部（Cap 顶）与右上角 `✕` 关闭按钮字形顶/右边缘均严格贴齐弹窗容器 `24px` 视觉内边距（与同尺寸的远程文件夹浏览弹窗等标准弹窗完全一致，不再偏下或向内偏移）；中间 `Tabs` 与标题行垂直居中并保持水平居中与窄宽避让；右上角 `✕` 悬停/按下/点击关闭、`Esc` 关闭（含上层叠加 `Task Info` 或 `Confirmation` 时的 `Esc` 屏蔽）及无障碍焦点遍历顺序均正常。