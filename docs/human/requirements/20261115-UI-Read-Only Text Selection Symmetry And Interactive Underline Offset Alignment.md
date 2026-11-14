# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **行高与交互下划线 Tokens 规范（禁止硬编码与私自特殊实现）**：
   - **新增 Token（1 项）**：在 `UI Tokens.md`（`1.2 字体与文本 -> Typography`）新增状态指示文本单行行高 `--line-height-status-indicator: 20px`，供 `C-08.5 Status Indicator`（`Workbench Status Indicator`）统一引用（含 `File` 页更新/索引状态、`Search` 结果计数、`Excerpt` 条目计数、表格 `Select Mode` 已选计数、`Library` 文件夹计数、`Excerpt` 列表/台词计数；外层控件总高维持 `--height-control: 36px` 不变）；
   - **既有行高 Token 复用（不新增数值）**：`C-06.2 Table Header Cell` 表头数据列标题引用既有 `--line-height-table-cell`（`20px`），表头外层高度维持 `--height-table-header`（`44px`）不变；其余固定行高文本继续复用各自既有行高 Token；
   - **交互文本悬停下划线基准明确（数值不变）**：`--width-interactive-text-underline: 1px` 与 `--offset-interactive-text-underline: 2px` 数值保持不变；明确 `--offset-interactive-text-underline` 对齐标准 CSS `text-underline-offset` 语义——**以当前视觉行字体的默认下划线位置为基准向下偏移 `2px`**（同行混排不同字体时取该行最低默认下划线位置）。

2. **全应用只读可选文本选区上下对称规则**：
   - **显式定义 `Line Height` Token 的只读文本**（含 `C-13.2` / `C-13.3` / `C-13.4` 播放浮层与命令面板字幕流、`C-11.2 Cover Summary` 辅助信息行与 `Description Detail Popover`、`C-08.5 Workbench Status Indicator`、`C-06.2` 表头与 `C-06.4` 表格各数据列、`L-06.8` / `L-06.11` 详情弹窗顶部标题）：
     - 无论单行常规显示、单行省略号截断还是多行自动折行，且无论英文、数字、中文、日文或混排文本，每一视觉行字形均按该行实际可见字形高度在自身 `Line Height` 行框内垂直居中，同时保持同行英文文本基线平稳一致；
     - 选中文字时，每一视觉行的选区背景高度等于该行的 `Line Height`，并围绕该行可见字形的视觉中心上下 `1:1` 对称展开；
     - 在 `C-13.4 Playback Cue Reel`（`Playback Overlay` 与 `Command Panel` 字幕流）中，条目上下内边距（`--padding-subtitle-focus-cue-y: 8px`）不裁切首尾行选区边缘；同一逻辑字幕行自动折为多视觉行且相邻被选中两行的中心距小于各自半行高之和时，相邻选区在行间缝隙中点处平齐相接、互不重叠。
   - **未显式指定 `Line Height` Token 的静态可选文本**（含页面/弹窗标题、分组标题、`File` / `Task` 列表卡片文字、`Settings` 行标签、弹窗键值详情等）：
     - 维持原有排版高度与位置不变（严格保持 `UI Design Rules.md` 规定的模态框顶部 `24px` Cap 顶留白与 `File` / `Task` 双行卡片 `68px` 基准高度不变）；
     - 选中文字时，选区背景围绕每行可见字形的视觉中心上下对称绘制，不被文本外框底边裁切。
   - **原生编辑态输入框**（`C-01.1` ~ `C-01.4` 及 `C-02.3 Hex Input`）：维持 macOS 原生编辑态选区表现不变。

3. **全应用 4 处交互文本（`Grab`）悬停下划线一致性**：
   - `UI Text Selection Rules.md` §1.3 定义的全部 **4 处** `Grab` 可点击文本——① `Search` / `Excerpt` 二级页表格普通模式下有效数据行 `Cues` 列的主台词与附加字幕、② `File` 页面可点击的 `Workbench Status Indicator` 状态文字、③ `Library` 二级详情页 `Cover Summary` 的本地文件夹路径、④ `Excerpt` 二级详情页 `Cover Summary` 发生单行截断或含换行的描述文字——统一按 `--width-interactive-text-underline`（`1px`）与基于字体默认下划线位置向下偏移 `--offset-interactive-text-underline`（`2px`）绘制悬停下划线，消除重复扣减偏移与跨组件基准不一致。

4. **设计文档同步安排**：
   - 关联 UI 设计文档（`UI Tokens.md`、`UI Text Selection Rules.md`、`UI Components - Controls.md`、`UI Components - Domain.md`）待本次改动验收通过后再最小化同步提交。

# 验收标准

1. **播放浮层与命令面板字幕流选区对称**：在 `Playback Overlay`（`Current`、`Subtitle Playlist`）与 `Command Panel`（`Search Results`）中选中英文、中文、日文单行或多行折行台词时，蓝色选区上下留白均匀对称，首尾行选区不被内框裁切，折行多行全选时相邻选区在行间中线平齐衔接无重叠。
2. **工作台、表格与弹窗只读文本选区对称**：在 `Excerpt` / `Library` 二级页 `Cover Summary`（含超长截断描述行及展开浮层）、`File` 页 `Last Updated: ...` 状态文字及各页统计文字、`Search` / `Excerpt` 表格表头与单元格、列表卡片与详情弹窗中选中文字时，上下留白对称且底部无裁切，同时模态框顶部 `24px` Cap 顶留白与 `File` / `Task` 卡片 `68px` 基准高度保持不变。
3. **4 处 `Grab` 交互文本悬停下划线清晰一致**：鼠标悬停在上述全部 4 处可点击文本上时，`1px` 下划线与中日英文及数字底部均保持清晰舒适且一致的间距，不再紧贴或穿过字形底沿。