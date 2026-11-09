# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/workbench/Settings and Localization.md`

# 需求描述

1. **Workbench 与弹窗静态文本选中范围**：
   - 在保持既有输入框、Search / Excerpt 表格及播放浮层字幕流选词能力不变的基础上，为以下位置的展示文本开放鼠标左键拖选、双击选词、三击全选及 `Cmd + C` 复制：
     1. **`Folder Info` / `File Info` 详情弹窗（`L-06.8`）**：下方各属性分组（`Property Groups`）每一行右侧的具体数值、文件名与路径文本（含 `#1`、`#2`... 索引行右侧的关联字幕/视频文件名）。弹窗标题、顶部图标旁的文件夹/文件名称行、分组标题及每行左侧固定属性名（含 `#1`、`#2`... 序号）保持不可选。
     2. **`Task Info` 任务详情弹窗（`L-06.11`）**：下方各属性分组（`Property Groups`）每一行右侧的具体数值、路径、文件名列表（`#1`、`#2`... 右侧的原文件名、新文件名、目标文件夹路径）、进度条右侧百分比文字（`xx%`）及未完成任务的红色失败原因（`Failure Reason`）。弹窗标题、顶部任务类型名称行、分组标题及每行左侧固定属性名保持不可选。
     3. **`Rename Folder` / `Rename Files` 重命名弹窗（`L-06.3`）**：`Current Name` 右侧显示的当前文件夹名称或文件公共名称文本。
     4. **`Cover Summary` 顶部封面摘要区（`C-11.2`，位于 Library 二级与 Excerpt 二级详情页）**：主标题（`Title`）、副标题第 1 与第 2 行（`Supporting Content`：视频与字幕统计、文件夹路径、摘录集描述、有效台词统计与创建日期）以及播放进度上方文字（`Progress Label`）。底部操作按钮保持不可选。
     5. **工作台状态与统计指示文字（`C-08.5 Workbench Status Indicator` 及批量选择提示）**：
        - `Search` 工具栏结果数（`xx results`）；
        - `Excerpt` 二级工具栏有效台词数（`xx excerpts`）；
        - `Search` / `Excerpt` 批量选择模式（`Select Mode`）工具栏第 1 行的已选计数（`xx / yy rows selected`）与右侧批量选择提示文案（`Selection Banner`）；
        - `Library` 一级操作栏文件夹数（`xx folders`）；
        - `Excerpt` 一级操作栏统计（`xx lists  yy cues`）；
        - `File` 顶部操作栏状态文字（含闲置态 `Last Updated` 及已完成、进行中、失败状态文字；左侧图标除外）。
     6. **确认弹窗正文与校验报错红字**：
        - `Confirmation Dialog`（`C-10.2` / `L-06.7`）中间的 `Message` 说明正文；
        - 所有弹窗（`Rename`、`Excerpt List Editor`、`WebDAV / SMB / FTP / NFS Folder`、`Export to Anki`）与 `Settings -> Shortcuts` 中输入框下方的红色校验报错文字（`Validation Message`）；
        - `Export to Anki`（`L-06.5`）中 `Front` / `Back` 卡片容器为空时显示的红色错误提示文字。
   - 其余未列入上述范围的界面元素（含各级封面卡片、File 文件夹/文件卡片与单集分组标题栏、面包屑、远程目录浏览卡片、Task 任务卡片、空状态 `Empty State`、封面编辑 `Support Text`、导航栏、标签页、按钮、菜单项、徽章等）保持不可选中。

2. **文本选区交互、指针样式与生命周期规则**：
   - **鼠标指针样式（`UI Interaction Rules.md` §11.2）**：
      - 上述纯静态可选文本区域在鼠标移入时显示 `I-beam` 指针（弹出菜单或上层对话框打开导致下层冻结时，下层非 `I-beam` 区域恢复默认箭头，冻结层不响应新选区）。
      - `File` 界面除 `Last Updated: -` 外的可点击状态文字保持 `Grab` 手型指针与 Hover 下划线：在文字上原地按下并松开左键触发打开对应 `Task Info` 详情弹窗；按下左键并拖动则进入文字划选，松开时不触发打开弹窗。
   - **外部拖入起选与拖出边界跟随（`UI Interaction Rules.md` §5）**：
      - 支持从非交互区域（如空白区、左侧属性名/标签等）按下鼠标左键并拖入或划过上述可选静态文本时，自动从该段文本边界起选并更新选区；一旦进入选词状态，拖出文本边界后选区与指针样式持续跟随直至松开鼠标。
   - **全局单一选区与自动清除（`UI Interaction Rules.md` §3.8 / §5）**：
      - 同一时刻全应用仅保留一处活跃文字选区（含表格选区、播放浮层字幕选区、输入框选区与上述静态文本选区）。
      - 在当前选区所属文本之外按下鼠标左键或右键、开始新的文字划选、聚焦输入框、打开任意弹出菜单或模态对话框、切换页面/标签页或关闭所属弹窗时，立即清除已有的静态文本选区。

3. **移除 Settings 中的 `Maintenance` 与 `Developer` 分类（`L-02.2` / `L-02.3`）**：
   - 从 `Settings` 窗口左侧导航栏移除 `Maintenance` 与 `Developer` 两个分类入口，仅保留 `General`、`Play`、`Shortcuts`、`Subtitle` 四个分类（无障碍遍历顺序同步更新为 4 个分类项）。
   - 移除 `Maintenance` 页面（数据库存储统计、手动刷新、压缩数据库及二次确认弹窗、数据库路径展示）与 `Developer` 页面（`FTS Vocabulary Diagnostics` 开关及 `FTS Vocabulary Data` 统计卡片），以及相关的禁用态 Tooltip 与本地化文案。

# 验收标准

1. **指定静态文本可选中与复制**：
   - 在 `Folder Info`、`File Info`、`Task Info` 各属性行右侧数值/路径/文件名/报错原因、`Rename` 当前名称、Library / Excerpt 二级 `Cover Summary` 的标题/副标题/进度文字、工作台各处统计计数（`xx results`、`xx excerpts`、`xx / yy rows selected` 及批量选择提示语、`xx folders`、`xx lists  yy cues`）、`Confirmation Dialog` 说明正文、以及各处红色校验报错文字上，均可通过鼠标左键拖拽划选（含从外部非交互区域按下并拖入文字起选、拖出文字边界持续跟随）、双击选词、三击全选，并按 `Cmd + C` 复制选中内容；左侧属性名、分组标题、卡片列表项、空状态提示与封面说明小字等非目标区域不可选中。
2. **指针样式与点击/拖选分流**：
   - 鼠标移至上述非 `Grab` 的可选静态文本上时稳定显示 `I-beam` 指针；移至 `File` 可点击状态文字上时显示 `Grab` 手型指针与下划线，单击正常打开对应的 `Task Info` 弹窗，按住左键拖拽（或从外部空白处拖入）则划选状态文字且松手不弹出 `Task Info`。
3. **选区互斥与自动清除**：
   - 选中上述任一位置的静态文字后，在窗口其他位置按下鼠标、聚焦输入框、划选另一处文本、打开任意菜单或弹窗、或切换页面时，原文字选区高亮立即清除，不会同时残留多处选区。
4. **Settings `Maintenance` 与 `Developer` 移除**：
   - 打开 `Settings` 窗口，左侧分类栏仅展示 `General`、`Play`、`Shortcuts`、`Subtitle` 四项，无障碍遍历在顶栏前进/后退与这 4 个分类及右侧控件间正常循环，不再存在 `Maintenance` 与 `Developer` 相关界面与操作。