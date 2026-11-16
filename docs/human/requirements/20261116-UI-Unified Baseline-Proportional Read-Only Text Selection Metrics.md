# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **只读文本选区度量 Tokens 规范（禁止硬编码与私自特殊实现）**：
   - **新增 Token（2 项）**：在 `UI Tokens.md`（`1.2 字体与文本`）新增全局只读文本选区相对基线的上下字号倍率 Token，全应用所有只读可选文本统一引用，严禁按单个界面硬编码偏移或编写私自特殊实现：
     - `--text-selection-ascent-scale`: `1.07`（选区上沿自文字基线向上延伸的字号倍率）
     - `--text-selection-descent-scale`: `0.35`（选区下沿自文字基线向下延伸的字号倍率；总选区高度为字号的 `1.42` 倍，在 `14px` 字号下对应约 `20px` 高度）

2. **全应用只读可选文本选区与容器行高解耦、统一按「基线 + 字号比例」绘制**：
   - 覆盖全应用三类只读可选文本作用域（① 页面、设置与弹窗连续静态文本流；② `Search` / `Excerpt` 表格普通模式下的固定表头数据列标题与表体各数据列单元格；③ `Playback Overlay` 与 `Command Panel` 字幕流中的可用台词）：
     - 无论所在组件是否显式定义 `Line Height` Token，无论单行常规显示、省略号截断还是多行自动折行，且无论纯西文字母（含 `g`、`j`、`p`、`q`、`y` 及方括号等下延字符）、汉字、日文假名或混排文本，每一视觉行的选中背景均以该行文字的**基线（Baseline）**为唯一垂直锚点，向上延伸 `Font Size × --text-selection-ascent-scale`、向下延伸 `Font Size × --text-selection-descent-scale`，不再随容器排版 `Line Height` 或单行实际字符墨迹外框浮动；
     - 同一字号在任意界面选中后的选区高度及文字在选区内的相对上下位置完全一致（如 `File` 卡片文件名、表格 `Display Title`、表格 `Cues` 主台词与 `Excerpt` 描述等 `14px` 文本选中高度统一；`Playback` 字幕流 `24px` 主台词与 `20px` 附加字幕按同比例放大，汉字与假名上下留白对称，西文 `j` 等下延字母底部与顶部均留有舒适空隙）。

3. **固定行高文本的语种无关基线定位与既有布局尺寸零变动**：
   - **显式定义 `Line Height` Token 的只读文本**：每一视觉行在各自 `Line Height` 行框内的垂直居中基线，统一按上述融合度量框的固定中心（基线上方 `Font Size × (--text-selection-ascent-scale - --text-selection-descent-scale) / 2`）定位，确保纯西文行、纯中日文行与混排行的基线绝对齐平；表格固定表头数据列标题的文字与选区基线严格对齐；`C-13.4 Playback Cue Reel` 中长截图复选框维持对齐首行可见字形中心的既有规则不变。
   - **未显式定义 `Line Height` Token 的静态可选文本**：维持原有排版高度与文字位置不变（严格保持 `UI Design Rules.md` 规定的对话框四边 `24px` Cap 顶等距留白，以及 `File` / `Task` 双行卡片 `68px` 基准高度不变）；选区上下边缘不得被文本组件自身边界或滚动视口顶底边缘（含 `File Info` 详情弹窗配对文件切换器下方滚动区首行）裁切。
   - **多行选区交界衔接**：任意只读可选文本在折行或跨行同时选中多视觉行时，若相邻两行选区上下边界发生接触或交叠，统一在两行对应选区间隙中点处平齐衔接，不重叠染色、不留缝隙。
   - **可编辑文本输入框**（`C-01.1` ~ `C-01.4` 及 `C-02.3 Hex Input`）：维持 macOS 原生编辑态光标与选区表现不变。

4. **设计文档同步安排**：
   - 关联 UI 设计文档（`UI Tokens.md`、`UI Text Selection Rules.md`、`UI Components - Controls.md`、`UI Components - Domain.md`）待本次改动完成视觉验收后再统一最小化同步提交。

# 验收标准

1. **跨界面同字号与跨语种选区视觉统一验收（Light & Dark）**：在 `File` 单集文件行、`Search` / `Excerpt` 表格（表头数据列标题、`Cues` 主/副台词、`Display Title`、`Time Range`、`Date Added`）、`Excerpt` / `Library` 二级页 `Cover Summary`（含展开态描述浮层）、`Settings` 各分类页及各模态弹窗/`Task Panel` 中，分别选中纯英文（如含 `A`、`j`、`[` `]` 的 `"Ave Mujica"` 与文件名）、中文、日文假名及中英日混排文本，同字号文本在各界面的蓝色选区高度完全一致，`j` 等下延字母不再贴底，中日文上下留白均匀对称。
2. **`Playback Overlay` 与 `Command Panel` 字幕流选区验收（Light & Dark）**：在 `Playback Current`、`Subtitle Playlist` 与 `Command Panel` 搜索结果中选中中英日单行或折行台词（如 `"也能让诸位沉浸在 Ave Mujica 的世界当中"`、纯英文无下延字母行与有 `j` 行），主台词与附加字幕顶部和底部留白比例与工作台一致，不再出现顶部空隙偏小或随单行字符上下浮动；松手弹出菜单定位与长截图复选框对齐零退步。
3. **既有布局高度零偏移、零裁切与多行平齐衔接验收**：所有模态对话框首行标题维持 `24px` Cap 顶边距不变，`File` 与 `Task` 列表卡片维持 `68px` 双行基准高度不变；紧凑单行文本及 `File Info` 切换器下方滚动区首行选中时上下边缘无裁切；折行多行连续选中时相邻选区在中线平齐衔接无深色叠边；可编辑输入框聚焦与选区保持原生表现不变。