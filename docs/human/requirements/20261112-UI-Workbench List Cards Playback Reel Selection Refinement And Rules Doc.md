# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **工作台与播放界面分组标题及底栏计数覆盖**：
   - 开放 `Recent`（`L-03.1`）与 `Command Panel` 二级页（`L-09.2`）的时间分组标题（`Last 7 Days`、`Last 30 Days`、`Earlier`、`Never Played`）、`Command Panel` 二级页顶部标题（搜索词、`Recent Videos`、`Recent Excerpt Lists`）、`File` 一级页（`L-04.5`）列表上方的 `All Folder` / `All Folders` 标题、二/三级页单集分组（`Episode File Group`）顶部的 `Display Title` 标题栏文字、以及 `Playback Footer`（`L-08.3`）左侧的状态计数文字为可选展示文本。

2. **无整卡左键点击动作的列表卡片文本选词与交互共存**：
   - **覆盖范围**：
     - `File` 二/三级页面（`L-04.5` / `L-04.6`）单集分组内部的视频文件行与字幕文件行文字（第 1 行文件名标题、第 2 行大小/路径副标题）；
     - `Task Panel` 任务面板（`L-06.9` / `L-06.10`）各标签页中的任务卡片文字（第 1 行标题、第 2 行副标题、`Incomplete` 标签页第 3 行红色错误信息）；
     - 远程文件夹弹窗 Step 2 目录浏览列表（`L-06.4`）中不可点击勾选的「已添加（`Added`）文件夹主卡片」标题文字（右侧 `Added` 徽章与卡片外独立 `>` 进入按钮除外）以及纯视频/字幕文件卡片标题文字。
   - **与父卡片 `Hover` 及业务右键菜单共存**：鼠标移入 `File` 单集文件行或 `Task` 任务卡片内的可选文字区域显示 `I-beam` 指针或拖拽选词期间，不阻断父行/卡片自身的 `Hover` 底色及右侧 `dots-three` 操作按钮的正常显现；在该行/卡片任意区域（含已选中的文字上）点击鼠标右键时，立即清除已有文字选区，并照常弹出原有的业务右键菜单。
   - **禁选边界收口**：各窗口拖拽顶栏、菜单、左侧导航栏、标签页、**`C-05.6 Breadcrumb` 面包屑导航（整条一刀切禁选：含 `File` 二/三级页面与远程目录浏览中的全部上级链接节点、分隔符及最右侧不可点击的当前目录末级节点）**、全部媒体封面卡片 `C-11.5 Media Card`、`File` 一/二级独立文件夹卡片、远程目录 Step 2 未添加文件夹主卡片與 `>` 按钮、全部状态与计数徽章、以及 `Toast` / `Tooltip` / 播放页播控栏均不可选中文本；从面包屑、独立卡片或空白处按下左键向右下斜拉进入单集分组或列表卡片时，严格按最初按下位置折算起点，从首个可选标题的第 1 个字符起完整连续选中。

3. **播放浮层与命令面板字幕流（`C-13.4`）内部非文字区拖入起选**：
   - `Playback Current`（`Focus Cue Reel`）、`Playback Subtitle Playlist` 与 `Command Panel Search Results`（`Cue Result Reel`）保持仅在单条可用台词内独立选词、不跨条连选、松手自动弹出 `Copy Selected Text`（及 `Playback Overlay` 下的 `Search Selected Text`）菜单并支持 `Cmd + C` 复制的既有规则不变；
   - 补齐在字幕流非台词文字区域（如左侧序号、时间轴圆点、下方剧集时间元数据或上下行间距）按下左键并拖入某条可用台词时，直接按最初按下位置在该单条台词内折算起点开始选词；`Playback Collage Editor` 维持不可选词不变。

4. **UI 规范文档收口（全部交互验收通过后执行）**：
   - 在本系列全部文本选词交互验收通过后，新增独立规范分册 `docs/human/design/ui/UI Text Selection Rules.md` 并纳入 `docs/human/design/ui/UI Index.md` 索引，统一记录全应用组件文本选中四分类、四类选区容器作用域、起点折算与自动滚屏、剪贴板序列化及 `Cmd + C` / `Cmd + A` 边界规则，并同步清理或对齐关联 UI 分册中的局部选词描述。

# 验收标准

1. **`File` 二/三级页面与斜拉轨迹验证**：在 `File` 二/三级页面中，整条面包屑（含末级当前目录节点）与独立文件夹卡片不可选中文本；从左上角面包屑上方或面包屑上按下鼠标向右下斜拉穿过第 01 集单集分组标题与内部视频/字幕文件行时，完整从单集分组标题第 1 个字符起连续选中至目标文件行，无开头漏字或截断现象。
2. **列表卡片 `Hover` 与右键菜单共存验证**：在 `File` 单集视频/字幕行、`Task Panel` 任务卡片及远程目录浏览已添加文件夹/纯文件卡片上支持 `I-beam` 拖选、双击/三击与 `Cmd + C` 复制；悬停文字或拖选期间 `File` 文件行与 `Task` 卡片的 `Hover` 背景及右侧 `dots-three` 按钮正常浮现，右键点击立即清除文字选区并正常打开业务右键菜单。
3. **播放字幕流与禁选边界验证**：在 `Playback Overlay`（`Current`、`Subtitle Playlist`）与 `Command Panel`（`Search Results`）字幕流中，从左侧序号或行间空白拖入某条可用台词可正常在该条台词内起选并在松手后弹出操作菜单；`Collage` 拼图编辑页、媒体封面卡片、播控栏与各类徽章均不可选中文本。
