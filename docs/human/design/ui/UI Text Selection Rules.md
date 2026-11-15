# 说明

1. 本文档由人类维护，统一规定 CueSeeker 全应用的文本选择元素分类、指针映射、选区作用域、跨区拖拽与滚屏手势、剪贴板复制格式、`Cmd + C` / `Cmd + A` 边界及全界面可选范围。
2. 界面层级、菜单模态与指针通用状态机详见 [`UI Interaction Rules.md`](UI%20Interaction%20Rules.md)；视觉与度量约束详见 [`UI Design Rules.md`](UI%20Design%20Rules.md)；组件与布局编号详见 [`UI Index.md`](UI%20Index.md)。

---

# 1. 文本选择元素四分类与指针表现

全应用所有界面元素按文本选择能力与指针表现划分为以下四类：

1. **可编辑文本输入（`I-beam`）**
   - **范围**：`C-01.1 Text Field`、`C-01.2 Text Area`、`C-01.3 Search Field`、`C-01.4 Number Field`、`C-02.3 Color Well` 中的 `Hex Input`（`C-01.5 Shortcut Field` 为按键录入控件，不属于文本输入）。
   - **指针与交互**：整个输入框容器（`Search Field` 清除按钮除外）显示 `I-beam` 指针；点击聚焦并将光标置于点击位置（自动获焦除外），支持框内拖拽划选、双击选词、三击选整行/整段、`Shift` 扩展选区及标准编辑快捷键。

2. **纯静态可选文本（`I-beam`）**
   - **范围**：各界面与弹窗中开放选词且无左键单击业务动作的标题、统计指示、表单标签、键值详情、无整卡点击动作的列表卡片文本、表格普通模式下的静态列（表头数据列标题、表体非点击数据列、已失效 `Unavailable` 行的 `Cues` 文本）、空状态提示语、红色校验/错误提示，以及播放字幕流中的可用台词文字。
   - **指针与交互**：指针悬停显示 `I-beam`；支持左键拖拽划选；除播放字幕流（`C-13.4 Playback Cue Reel`）仅响应拖拽划选外，其余纯静态可选文本均支持**双击选中所在词**、**三击选中当前单元格或段落全文**。

3. **点击 + 拖选复合文本（`Grab`）**
   - **范围**（全应用仅以下 **5 处**）：
     1. `Search` 与 `Excerpt` 二级页表格普通模式（非 `Select Mode`）下，有效数据行 `Cues` 列的主台词与 `Cue Group` 附加字幕（`C-06.4 Interactive Text`）：单击跳转播放；
     2. `File` 页面顶部操作栏（及一级空状态下方）除从未索引 `Last Updated: -` 外的可点击状态文字（`C-08.5 Workbench Status Indicator`，左侧图标除外）：单击打开对应任务的 `Task Info` 弹窗；
     3. `Library` 二级详情页 `C-11.2 Cover Summary` 第 2 行的本地文件夹路径文字（远程文件夹路径不可点击，归入纯静态 `I-beam` 文本）：单击在 Finder 中打开；
     4. `Excerpt` 二级详情页 `C-11.2 Cover Summary` 第 2 行发生单行截断或包含换行的摘录列表描述文字（完整单行描述与 `No description` 占位文案不可点击，归入纯静态 `I-beam` 文本）：单击原地展开 `Description Detail Popover`；
     5. `Settings -> About` 页 `Repository` 行右侧的 `GitHub Repository` 链接文字（右侧 `link-simple` 图标不可选，与文字共用点击与 Hover 热区）：单击在默认浏览器中打开项目仓库。
   - **指针与分流规则**：悬停时显示与当前文字同色的下划线（线宽 `--width-interactive-text-underline`，自当前行字体默认下划线位置向下偏移 `--offset-interactive-text-underline`）及 `Grab` 手型指针；原地按下并松开左键触发对应单击动作；按住左键拖动达到起选阈值（或从外部拖入划过）时，立即转入文字划选并锁定 `I-beam` 指针，松开鼠标不触发单击动作。其中表格有效行 `Cues` 文本不响应双击与三击选词。

4. **不可选文本与组件边界**
   - **自带原生拖拽职责的组件**（按下左键执行组件自身拖拽，不触发跨区选词）：各窗口拖拽顶栏（含顶栏标题）、可编辑文本输入框、滚动条（`C-07.1`）、播放进度条与音量滑块（`C-12.3` / `C-12.5`）、封面裁剪框（`C-11.3 Cover Crop Editor`）、`Export to Anki` 卡片内可上下拖拽排序的数据对象胶囊（`L-06.5`）。
   - **纯点击、导航与展示元素**（自身文字不可选，但支持在其上按下左键向外拖入可选区域起选）：左侧导航栏（`C-05.1` ~ `C-05.3`）、顶栏与弹窗标签页（`C-05.4` / `C-05.5`）、**`C-05.6 Breadcrumb` 面包屑导航（整条一刀切禁选，含全部上级链接节点、`caret-right` 分隔符及最右侧当前目录末级节点）**、所有按钮与下拉触发器（含 `Shortcut Field`、`File Info` 顶部配对文件切换触发器）、开关/复选框/分段控制器/`Filter Chip`、所有弹出菜单与 `Command Panel` 一级选项（`C-04`）、全部媒体封面卡片（`C-11.5 Media Card`）、`File` 一/二级独立文件夹卡片、远程目录浏览 Step 2 中的未添加文件夹主卡片与独立 `>` 进入按钮、表格首列 `#` 选择/序号槽位与失效行 `?` 状态图标、全部徽章与按键帽（`Watch Status Badge`、`Cover Badge`、`Task Count Badge`、`Tag`、`Keycap`、`Added` 徽章）、播放页顶底栏与播控组件、`Playback Collage Editor` 预览与字幕区、以及视觉穿透层（`Toast`、`Tooltip`、`Playback Feedback`、`Player Error Banner`）。

---

# 2. 四类选区作用域与层级屏蔽规则

1. **全局单一活跃选区与视觉表现**
   - 全应用（跨主窗口与独立 `Settings` 窗口）同一时刻最多仅保留 **1 处**活跃文字选区。
   - 只读可选文本选中时，有显式行高 Token 的文本在各自 `Line Height` 内垂直居中且选区高度等于该 `Line Height`（`C-13.4 Playback Cue Reel` 中相邻同时选中行若行距小于半行高之和，选区在行间中线平齐衔接）；其余静态可选文本保持自然行高，选区围绕文字上下对称包裹且不被容器裁切。
   - 遵循 [`UI Interaction Rules.md` §1 ~ §2](UI%20Interaction%20Rules.md) 层级屏蔽规则：更高层界面（菜单、模态对话框、`Playback Overlay`、`Command Panel`）打开期间，被遮挡的下层界面冻结，不响应任何选词手势。

2. **四类相互隔离的选区作用域**（不同作用域之间、以及同类作用域的不同承载容器之间均不跨界串连）：
   - **作用域 ①：单个可编辑输入框作用域**
     - 选区严格限制在当前聚焦的单个输入框内部。
   - **作用域 ②：连续静态文本流作用域**
     - 在当前最上层可交互界面内，除输入框、表格与播放字幕流外，同一逻辑承载面内的全部可选展示文本（含 `I-beam` 纯静态文本与 `Grab` 复合文本）归入同一连续静态文本流，按**「纵向从上到下、同一水平行内从左到右」**的视觉阅读顺序跨行、跨元素连续划选，起止位置之间夹杂的图标、按钮、进度条等不可选元素自动跳过。
     - 全应用共 **5 类独立逻辑承载面**：
       1. 主窗口当前工作台页面内容区（`Recent`、`Library`、`File`、`Search` 非表格区、`Excerpt` 非表格区）；
       2. 独立 `Settings` 窗口右侧当前分类内容区（`General`、`Play`、`Shortcuts`、`Subtitle`、`About`）；
       3. 当前最上层模态对话框或 `Task Panel` 内容区（多层对话框叠加时仅最上层生效）；
       4. 展开态 `Description Detail Popover` 浮层内部（遵循菜单模态，与下层 `Cover Summary` 隔离）；
       5. `Playback Overlay` 或 `Command Panel` 的非字幕流静态区（如 `Command Panel` 二级页顶栏标题、时间分组标题、空状态提示语与底部 `Playback Footer` 左侧状态计数）。
   - **作用域 ③：`Search` / `Excerpt` 表格普通模式作用域（`C-06` / `L-05.5`）**
     - 仅在普通模式（非 `Select Mode`）下生效；选区自包含于固定表头数据列标题（`Display Title`、`Cues`、`Time Range`、`Date Added`）与表体各行对应数据列单元格（排除首列 `#` 槽位、失效行 `?` 图标与行尾 `dots-three` 按钮），支持跨单元格、跨行及表头至表体连续划选，不与上方的 `Cover Summary` 或工具栏串连。
     - 进入批量选择模式（`Select Mode`）时立即清除表格内已有文字选区，并在 `Select Mode` 期间禁止表头与表体选词（工具栏第 1 行的已选计数与批量选择提示文案仍归属页面连续静态文本流正常可选）。
   - **作用域 ④：播放字幕流单条单逻辑行作用域（`C-13.4 Playback Cue Reel`）**
     - 仅在 `Playback Current`（`Focus Cue Reel`）、`Playback Subtitle Playlist` 与 `Command Panel Search Results`（`Cue Result Reel`）的可用台词文字（`Primary Cue` 与 `Cue Group` 各逻辑字幕行）内生效。
     - 每次拖拽选区严格限制在**单条台词的单个逻辑字幕行**内（同一逻辑行因宽度自动折行的多视觉行可连续划选；不同逻辑行之间、主台词与附加字幕之间、不同台词条目之间均不跨界连选；左侧序号/时间轴圆点与下方 `Playback Cue Metadata` 不可选）。`Playback Collage Editor` 禁止字幕选词。

---

# 3. 拖拽手势、边缘滚屏与父卡片交互共存

1. **跨不可选区/纯点击控件拖入起选与初始锚点折算**
   - 在任意不承担原生拖拽职责的空白区域或纯点击/导航元素（见 §1.4）按下鼠标左键并向外拖动时，接触目标作用域可选文本前不显示选区；一旦拖动进入或跨过可选文本使「最初按下位置」与「当前指针位置」形成非空字符区间，立即激活该作用域选词。
   - **初始按下位置投影原则**：跨界激活选词后，**选区起点始终按最初按下鼠标的位置（而非半途进入文本边界的交点）向目标作用域投影折算**——例如从左上角面包屑、封面图、工具栏按钮或表格首列 `#` 向右下斜拉穿过标题或首格时，完整从首个可选文本的第 1 个字符起连续选中，不遗漏开头字符。
   - **连续静态文本流上下边界钳制**：在连续静态文本流中，纵向高于首行可选文本顶边的坐标统一折算至首行第 1 个字符之前，纵向低于末行可选文本底边的坐标统一折算至末行最后 1 个字符之后。
   - **播放字幕流内部拖入起选**：在 `Playback Cue Reel` 内部的非台词文字区域（左侧序号、时间轴圆点、下方剧集时间元数据或行间空白）按下左键并拖入某条可用台词时，按最初按下位置向被进入的该条逻辑字幕行投影折算起点开始选词。

2. **起手控件点击取消与拖选指针锁定**
   - 一旦鼠标拖动激活任意文字划选，立即取消起手点击控件（按钮、`Filter Chip`、复选框、`Grab` 可点击文本等）的 `Pressed` 外观，并在松开左键时取消原控件的点击或勾选动作。
   - 拖选激活期间（含拖出文本或窗口边界外继续移动期间），选区持续跟随指针更新，主窗口内指针锁定为 `I-beam`，松开左键后按当前落点重新判定指针。

3. **视口边缘自动滚屏**
   - 在任意可滚动容器（工作台页面、`Settings` 分类页、对话框滚动区、`Description Detail Popover`、表格表体、`Playback Cue Reel`）内拖拽选词移至或超出滚动视口上下边缘（横向滚动表格含左右边缘）时，所属滚动容器自动连续平滑滚屏并实时扩展或收缩选区，直至指针移回视口内部、到达滚动边界或松开左键。

4. **无整卡左键点击动作的列表卡片交互共存**
   - **覆盖范围**：`File` 二/三级页面单集分组内的视频与字幕文件行（`L-04.5` / `L-04.6`）、`Task Panel` 各标签页中的任务卡片（`L-06.10`）、远程文件夹弹窗 Step 2（`L-06.4`）中的已添加（`Added`）文件夹主卡片（`Added` 徽章与卡片外独立 `>` 按钮除外）及纯视频/字幕文件卡片。
   - **`Hover` 与右侧操作按钮共存**：鼠标移入 `File` 单集文件行或 `Task` 任务卡片内的可选文字显示 `I-beam` 指针、或按住拖拽选词期间，父行/父卡片自身的 `Hover` 背景底色与右侧 `dots-three` 操作按钮保持正常显现。
   - **业务右键菜单优先**：在上述行/卡片任意位置（含已选中的文字上）点击鼠标右键时，不弹出系统文本菜单，**立即清除已有文字选区并照常弹出该行/卡片的业务右键菜单**。

---

# 4. 复制、全选快捷键、选中文字菜单与生命周期

1. **`Cmd + C` 复制与自定义快捷键优先级**
   - 全应用四类选区作用域均支持 `Cmd + C` 及系统菜单栏 `Edit -> Copy` 复制当前选中文本；除可编辑输入框外，其余三类只读选区按 `Cmd + C` / `Edit -> Copy` 时均为**静默复制**（不弹出 Toast，保留当前选区不清除）。
   - **快捷键优先级**：当当前活跃窗口最上层可交互界面存在未被遮挡的非空文字选区，或焦点位于可编辑文本输入框内时，`Cmd + C` 始终优先执行文本复制；仅当无活跃文字选区且无聚焦输入框时，才交由 `Settings -> Shortcuts` 中绑定为 `⌘C` 的自定义快捷键响应。

2. **选中文字弹出菜单（仅 `Playback Cue Reel`）**
   - 全应用仅 `Playback Current`、`Playback Subtitle Playlist` 与 `Command Panel Search Results` 的字幕流在左键拖选形成非空选区并**松开左键**时，自动在选区锚点旁弹出挂靠菜单，包含：
     1. `Copy Selected Text`（图标 `copy`）：复制选中文本，关闭菜单、清除选区并在当前界面右下角弹出复制成功 Toast；
     2. `Search Selected Text`（图标 `magnifying-glass`）：关闭菜单、清除选区，并以选中文本打开或刷新 `Command Panel` 的 `Search Results` 二级页。
   - 连续静态文本流与表格选区在松开左键或点击右键时均不弹出复制菜单。

3. **剪贴板序列化格式与截断还原**
   - **连续静态文本流**：同一水平行内左右并列的可选文本节点（如 `Folder Info` / `File Info` / `Task Info` 的「左侧属性名 + 右侧属性值」、`Rename` 的「`Current Name` 标签 + 右侧当前名」、`Export to Anki` 的「`Front` + `Back` 列标题」、工具栏同行并列统计项）同时处于选区内时以单个制表符 `\t` 连接（仅选中单侧时不拼接 `\t`）；纵向跨行或跨块之间以单个换行符 `\n` 连接。
   - **省略号截断完整还原**：连续静态文本流与表格静态单元格中因行数或宽度限制显示尾部或中间省略号 `...` 的可选文本（如超长路径、`Cover Summary` 截断描述或进度台词、任务卡片单行标题/报错、批量选择提示文案等），当选区覆盖至其可见省略末尾执行复制时，自动提取**未被截断的完整原始字符串**。
   - **`Search` / `Excerpt` 表格选区**：同时写入纯文本 **TSV**（同行跨列以 `\t` 分隔、跨行以 `\n` 分隔，单元格内多行文本保留行内换行并按标准双引号包裹转义）与富文本 **HTML `<table>`** 结构。
   - **`Playback Cue Reel` 选区**：按所选字符区间直接写入纯文本子串。

4. **`Cmd + A`（全选）全局边界**
   - `Cmd + A` 及系统菜单栏 `Edit -> Select All` **全应用严格仅对当前拥有输入焦点的可编辑文本输入组件**（`C-01.1` ~ `C-01.4` 及 `C-02.3 Hex Input`）生效；焦点不在可编辑输入框内时（含停留在工作台页面、`Settings`、详情弹窗、表格或播放浮层），`Cmd + A` 不产生任何全选动作，`Edit -> Select All` 为禁用态。

5. **选区清除时机**
   - 任意非输入框的活跃文字选区在发生以下任一事件时立即清除：
     1. 在选区外按下鼠标左键或右键，或在带业务右键菜单的行/卡片上按下右键；
     2. 在同一或另一作用域发起新的文字划选，或点击聚焦任意可编辑输入框；
     3. 打开任意弹出菜单、下拉菜单、右键菜单、`Description Detail Popover`、模态对话框、`Playback Overlay` 或 `Command Panel`（唯一例外：`Playback Cue Reel` 松手弹出的选中文字菜单在打开期间保留其挂靠选区，关闭该菜单时一并清除）；
     4. 表格进入批量选择模式（`Select Mode`），或表格搜索词/筛选/排序变更刷新结果；
     5. 切换工作台页面、顶栏或弹窗 `Tab` 标签页、`File` 目录层级、`Settings` 分类、`File Info` 配对文件，或关闭选区所属的浮层、弹窗或窗口。

---

# 5. 全界面与弹窗可选范围速查

## 5.1 工作台页面（`L-01`、`L-03` ~ `L-05`）

| 界面 / 模块 | 可选文本（及指针） | 不可选边界 |
| --- | --- | --- |
| **App Shell & 通用反馈**（`L-01.1` ~ `L-01.4`、`C-09.2`） | 各处 `Empty State` 图标下方的提示语（`I-beam`） | 主窗口顶栏（红绿灯、前后退、侧栏开关、顶栏页面标题、任务/设置入口）、左侧 `Sidebar`、`Empty State` 操作按钮、`Toast`、`Tooltip` |
| **Recent**（`L-03.1`） | 时间分组标题 `Last 7 Days` / `Last 30 Days` / `Earlier` / `Never Played`、空状态提示语（`I-beam`） | 顶栏 `Videos` / `Excerpt Lists` 标签页、全部 `C-11.5 Media Card` 封面卡片（含封面、进度、徽章、标题、集数、`dots-three`） |
| **Library 一级**（`L-04.1`） | 搜索框（输入 `I-beam`）；`xx folders` 统计文字、空状态提示语（`I-beam`） | 排序按钮、全部文件夹封面卡片 |
| **Library 二级详情**（`L-04.3`） | `Cover Summary` 主标题、`xx videos  yy subtitles`、远程文件夹路径、进度文字、空状态提示语（`I-beam`）；本地文件夹路径（`Grab`，单击在 Finder 打开） | `Cover Summary` 封面图、进度条、底部操作按钮；下方全部剧集封面卡片 |
| **File 一/二/三级**（`L-04.5` / `L-04.6`） | 顶部状态文字中 `Last Updated: -`（`I-beam`）与其余可点击状态文字（`Grab`，单击打开 `Task Info`）；一级 `All Folders` 标题；二/三级单集分组顶部 `Display Title` 标题栏、单集内视频/字幕文件行的文件名与副标题；空状态提示语（`I-beam`） | `Add Folder` / `Index All` 按钮、状态指示器左侧图标、**整条 `C-05.6 Breadcrumb` 面包屑（含上级节点、分隔符与当前目录末级节点）**、一/二级独立文件夹卡片整体、文件行左侧大图标与右侧 `dots-three` 按钮 |
| **Search**（`L-05.4` / `L-05.5`） | 搜索框（输入 `I-beam`）；工具栏 `xx results`、`Select Mode` 下 `xx / yy rows selected` 与批量选择提示文案、空状态提示语（页面流 `I-beam`）；普通模式表头数据列标题、表体 `Display Title` / `Time Range` 及失效行 `Cues` 文本（表格流 `I-beam`），有效行 `Cues` 文本（表格流 `Grab`，单击播放） | 工具栏全部按钮、`Select Mode` 下整张表格、普通模式表格首列 `#` 复选框/序号槽位、失效行 `?` 图标、行尾 `dots-three` 按钮 |
| **Excerpt 一级**（`L-05.1`） | 搜索框（输入 `I-beam`）；`xx lists  yy cues` 统计文字、空状态提示语（`I-beam`） | 排序按钮、`+ New List` 按钮、全部摘录集封面卡片 |
| **Excerpt 二级详情**（`L-05.3` ~ `L-05.5`） | `Cover Summary` 主标题、`xx excerpts  Created ...`、完整单行描述 / `No description`、进度文字（页面流 `I-beam`）；截断或含换行的描述（页面流 `Grab`，单击展开浮层）；展开态 `Description Detail Popover` 全文（独立浮层流 `I-beam`）；工具栏与表格（含 `Date Added` 列）同 `Search` | `Cover Summary` 封面图、进度条、底部按钮；工具栏按钮与表格非数据列槽位 |

## 5.2 Settings 设置窗口（`L-02.1` ~ `L-02.6`）

| 界面 / 模块 | 可选文本（及指针） | 不可选边界 |
| --- | --- | --- |
| **General / Play / Shortcuts / Subtitle** | 右侧当前分类内所有分组标题（`Group Title`）、每行左侧设置项名称或快捷键功能名称、`Shortcuts` 校验报错红字（分类页连续文本流 `I-beam`）；`Text Field` / `Text Area` / `Number Field` / `Color Well Hex Input`（输入 `I-beam`） | 设置窗口顶栏（红绿灯、前后退、顶栏分类标题）、左侧分类 `Sidebar`、开关/复选框/分段控制器/下拉按钮、颜色色块与预设面板、`C-01.5 Shortcut Field`（及内部 `Keycap`）、恢复默认图标按钮与底部 `Restore Defaults` 按钮 |
| **About**（`L-02.6`） | 应用名称、版本号、项目简介、每行左侧名称、更新状态提示文字（分类页连续文本流 `I-beam`）；`GitHub Repository` 链接文字（`Grab`，单击打开仓库） | 顶部应用图标、状态提示左侧图标、右侧更新操作按钮、`GitHub Repository` 右侧 `link-simple` 图标 |

## 5.3 模态对话框与任务面板（`L-06.1` ~ `L-06.11`）

| 对话框 / 面板 | 可选文本（及指针） | 不可选边界 |
| --- | --- | --- |
| **Edit Cover**（`L-06.1`） | 左上角标题 `Edit Cover`、封面下方 `Support Text` 说明小字（`I-beam`） | 关闭按钮、封面预览/选图遮罩与裁剪框、底部 `Cancel` / `Save` 按钮 |
| **Excerpt List Editor**（`L-06.2`） | 左上角标题、`Support Text`、`Name` / `Description` 标签、校验报错红字（`I-beam`）；`Name` / `Description` 输入框（输入 `I-beam`） | 关闭按钮、封面选图与裁剪区、底部按钮 |
| **Rename Folder / Files**（`L-06.3`） | 左上角标题、左侧 `Current Name` / `New Name` 标签、右侧当前名称全文、校验报错红字（`I-beam`）；`New Name` 输入框（输入 `I-beam`） | 关闭按钮、底部按钮 |
| **WebDAV / SMB / FTP / NFS Folder**（`L-06.4`） | **Step 1**：左上角标题、左侧 `Address` / `Port` / `Username` / `Password` 标签、底部校验报错红字（`I-beam`）；各输入框（输入 `I-beam`）<br>**Step 2**：左上角标题、已添加（`Added`）文件夹主卡片标题、纯视频/字幕文件卡片标题、空状态提示语（`I-beam`） | 关闭按钮、底部按钮；**Step 2** 整条 `Breadcrumb` 面包屑、未添加文件夹主卡片、右侧 `Added` 徽章、所有文件夹右侧独立 `>` 进入按钮、卡片左侧大图标 |
| **Export to Anki**（`L-06.5`） | 左上角标题、`Front` / `Back` 列标题、空卡片红色错误提示、底部 `File Name` / `Location` 标签与校验报错红字（`I-beam`）；`File Name` / `Location` 输入框（输入 `I-beam`） | 关闭按钮、`+` 添加按钮、白色卡片内可拖拽排序的数据胶囊（含手柄、名称与 `✕` 按钮）、右侧文件夹选择按钮、底部按钮 |
| **Filter**（`L-06.6`） | 左上角标题 `Filter`、各筛选分组名称 `Duration` / `Character` / `Language` / `Watch Status` / `Folder`（`I-beam`） | 关闭按钮、分组标题左侧图标与右侧选中数量徽章、全部 `Filter Chip`、底部 `Reset` / `Cancel` / `Show` 按钮 |
| **Confirmation Dialog**（`L-06.7`） | 标题、`Message` 说明正文（`I-beam`） | 底部 `Cancel` / `Confirm` 按钮 |
| **Folder Info / File Info**（`L-06.8`） | 左上角标题、`Folder Info` 顶部文件夹图标右侧静态名称、所有属性分组标题、每行左侧属性名（含 `#1`、`#2`... 序号标签）与右侧属性值/文件名/路径全文（`I-beam`） | 关闭按钮、`File Info` 顶部固定带 `caret-down` 的配对文件下拉触发器及展开菜单、顶部大图标 |
| **Task Panel & Task Card**（`L-06.9` / `L-06.10`） | 左上角标题 `Task`、任务卡片第 1 行标题、第 2 行进度/数量与时间副标题、`Incomplete` 第 3 行红色错误信息、空状态提示语（`I-beam`） | 顶栏 `Current` / `Completed` / `Incomplete` 标签页、关闭按钮、卡片左侧大图标、胶囊进度条、右侧 `dots-three` 按钮 |
| **Task Info**（`L-06.11`） | 左上角标题 `Task Info`、顶部任务图标右侧任务类型名称、所有属性分组标题、每行左侧属性名（含 `#1`、`#2`... 序号标签）与右侧数值/路径/文件名/进度百分比 `xx%`/红色失败原因全文（`I-beam`） | 关闭按钮、顶部任务大图标、进度条图形 |

## 5.4 播放页、Playback Overlay 与 Command Panel（`L-07` ~ `L-09`）

| 界面 / 模块 | 可选文本（及指针） | 不可选边界 |
| --- | --- | --- |
| **Player 主界面**（`L-07.1` ~ `L-07.5`） | 无 | 顶栏标题与按钮、视频画面与字幕渲染层、台词队列控制栏、底部进度条与播控栏、`Playback Feedback`、`Player Error Banner` |
| **Playback Current & Subtitle Playlist**（`L-08.1` ~ `L-08.5`） | 底部 `Playback Footer` 左侧状态计数、空状态提示语（浮层流 `I-beam`）；字幕流可用台词文字 `Primary Cue` / `Cue Group`（单条单逻辑行拖选 `I-beam`，松手弹菜单） | 顶栏标签页与按钮、字幕流左侧序号与下方 `Playback Cue Metadata`、底部右侧 `Shortcut Action Button`（含 `Keycap`） |
| **Playback Video Playlist**（`L-08.5`） | 底部 `Playback Footer` 左侧视频数、空状态提示语（浮层流 `I-beam`） | 顶栏标签页与按钮、全部剧集封面卡片、底部右侧动作按钮 |
| **Playback Collage Editor**（`L-08.6`） | 底部 `Playback Footer` 左侧已选/总条数计数、左侧或整页空状态提示语（浮层流 `I-beam`） | 顶栏标签页与按钮、左侧拼图预览区、右侧带复选框的整套字幕流、底部右侧动作按钮 |
| **Command Panel 一级**（`L-09.1`） | 顶部搜索框（输入 `I-beam`） | 选项列表（`Search Action`、`Recent Videos`、`Recent Excerpt Lists`，含右侧 `xx results`）、底部动作按钮 |
| **Command Panel 二级**（`L-09.2` / `L-09.3`） | 顶部标题（搜索词 / `Recent Videos` / `Recent Excerpt Lists`）、时间分组标题、空状态提示语、底部左侧状态计数（面板流 `I-beam`）；`Search Results` 字幕流可用台词（单条单逻辑行拖选 `I-beam`，松手弹菜单） | 返回/筛选/排序按钮、`Search Results` 左侧序号与下方 `Playback Cue Metadata`、`Recent Videos` / `Recent Excerpt Lists` 封面卡片网格、底部右侧动作按钮 |