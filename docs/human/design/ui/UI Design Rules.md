# 说明

1. 本文档由人类维护，规定 CueSeeker 全局通用的视觉约束、状态视觉公理、光学对齐与度量基准、明暗模式配色法则以及布局边距体系。
2. 本文档优先级高于具体组件与布局的局部推演；除非具体组件文档显式声明例外，**所有 UI 组件与布局均必须无条件遵守本文档规定的全局约束**。

---

# 1. 交互状态视觉约束（State Visual Invariants）

## 1.1 全局无按下视觉效果（No Pressed Effect）
- **核心铁律**：按住鼠标左键期间，**不改变任何可交互控件或元素的外观**（包括但不限于按钮 `C-03.1`、图标按钮 `C-03.2`、快捷动作按钮 `C-03.3`、卡片 `C-11.5`/`L-04.6`/`L-06.10`、菜单项 `C-04.3`、Sidebar 项 `C-05.3`、标签 `C-05.5`、面包屑节点 `C-05.6`、筛选筹码 `C-02.5`、表头与表格行 `C-06.2`/`C-06.3`、播放控制按钮 `C-12.1` 等）。
- **保持既有状态**：按住期间元素保持按下前已有的 `Default`、`Hover`、`Selected`、`Highlighted`、`Open` 或 `Focused` 外观，**严禁出现变暗、变色、半透明衰减或缩放等按下态（Pressed / Active）效果**。
- **触发时机**：点击动作统一在鼠标松开（Mouse Up）时发生。

## 1.2 选中态（Selected）组件白名单
- **白名单原则**：只有具备「持久状态或当前位置指示」语义的组件才拥有 `Selected`（或 `Checked`）视觉状态。
- **允许拥有选中态的组件白名单**：
  1. **选择控件**：`C-02.1 Checkbox`（`Checked` / `Indeterminate`）、`C-02.2 Switch`、`C-02.4 Segmented Control`、`C-02.5 Filter Chip`。
  2. **导航与单选菜单**：`C-04.3 Menu Item / Radio Menu Item`、`C-05.3 Sidebar Item`、`C-05.5 Tab`、`C-05.6 Breadcrumb`（仅当前所在层级末节点为激活样式，前置祖先节点无选中态）。
  3. **列表、卡片与台词流**：`C-06.3 Table Row`（批量选择勾选行）、`C-11.5 Media Card`（卡片列表中的当前高亮/选中项）、`C-13.1 Playback Cue Metadata`、`C-13.2 Subtitle Focus Cue`、`C-13.3 Playback Cue Result`。
- **非白名单组件禁令**：除上述白名单外，其余动作触发型组件（如 `C-03.1 Button`、`C-03.2 Icon Button`、`C-03.3 Shortcut Action Button`、`C-04.3 Action Menu Item` 等）**严禁定义或渲染 `Selected` 态**；当按钮所挂靠的菜单、弹窗或所控模式处于打开状态时，统一使用 `Open` 状态（外观等同于对应表面的 `Hover` 态）。

## 1.3 输入框聚焦与报错预留约束
- **仅边框变色，无外发光环**：所有输入框（`C-01.1` ~ `C-01.5`）聚焦时仅将容器边框颜色切换为 `--color-border-focus`，**不显示外发光焦点环（Focus Ring）**。
- **几何零偏移**：聚焦前后输入框的宽高、圆角、内边距以及单行文本/占位符的绘制起点必须完全一致（含内容溢出时），严禁因聚焦导致文字抖动或偏移。
- **报错优先级**：报错状态边框（`--color-danger-text`）优先级高于聚焦边框（`Focused Error` 仍显示 `--color-danger-text`）。
- **红字报错（`Validation Message`）预留规则**：
  - **Dialog 对话框内**：需要校验的输入框下方（间距 `--spacing-1: 4px`）恒定预留 `1` 行红字高度（左边缘与所属输入框左边缘对齐），确保报错出现或消失时对话框高度不发生跳动（`WebDav Folder`、`SMB Folder` 与 `FTP Folder` 对话框仅在最下方 `Password` 输入框下预留 1 行，`NFS Folder` 对话框在 `Address` 输入框下预留 1 行）。
  - **Settings 设置页内**：输入框平时不预留红字高度（`Reserved Lines: 0`），仅在存在报错提示时动态展开行高。

---

# 2. 光学度量与视觉边界基准（Optical Alignment & Visual Inset）

## 2.1 Dialog 四边等距与 Cap 顶测量法则
- **四边视觉等距**：所有 Dialog（`C-10.1`）容器的四边视觉内边距均为 `--inset-dialog`（`24px`），且四边相等。
- **量到看得见的边（Visual Bounds Rule）**：`--inset-dialog` 的测量基准不是排版行框（Line Box）或透明热区（Hit Area），而是**元素的可见墨迹/像素边缘**：
  1. **文字**：水平方向取文本框左/右边缘；顶部方向取首行文字的 **Cap 顶（Cap Height Top）**。
  2. **带边框或背景的控件**（如输入框、普通按钮、分组卡片）：取容器的可见边框或背景外沿。
  3. **无背景纯图标按钮**（如右上角 `Dialog Close` 关闭按钮、`Export to Anki` 中 `Location` 右侧的文件夹选择按钮）：取**图标字形的实际墨迹边缘（Glyph Ink Bounds）**，而非按钮透明热区边框。
- **对齐覆盖范围**：标题与正文的左缘、正文的折行右边界、Footer 最右侧按钮的右缘、Footer 最下方按钮的下缘、右上角关闭按钮字形的右缘与顶缘，均严格贴齐 `--inset-dialog` 视觉边界框。

## 2.2 双行卡片基准锁定与多行向下延展法则
- 适用于 `L-04.6 File Card Layout` 与 `L-06.10 Task Card Layout`：
  - **基准态（标准双行文本）**：卡片基准高度为 `68px`，内边距 `--spacing-4`（`16px`）。左侧图标底容器（`36×36px`）与文本列顶部对齐（距卡片顶边 `16px`）；右侧操作按钮区（高 `32px`）垂直居中（距顶、距底各 `18px`，距右 `16px`）。
  - **展开态（文本折行或出现第 3 行进度条/报错）**：当中间列高度增加撑开卡片时，**左侧图标底容器（距顶 `16px`）与右侧操作按钮（距顶 `18px`）保持基准位置绝对锁定**，不随卡片变高而重新居中；卡片仅向下延伸并维持底部 `16px` 边距。

---

# 3. 颜色与明暗模式法则（Light & Dark Mode Polarity）

## 3.1 Dark Mode 表面海拔亮度阶梯
- **越上层越亮原则**：在 Dark Mode 下，界面层级的纵深关系通过表面背景亮度递增表达，而非加重阴影：
  - **工作台层级**：`Sidebar`（`#111113`） < `页面 Surface / Topbar / Dialog`（`#1C1C1F`） < `设置分组卡片`（`#242429`） < `表格与列表卡片`（`#2E2E34`） < `菜单 Popover`（`#36363B`）。
  - **播放页层级**：`视频舞台`（`#000000`） < `Playback Overlay`（`#242426`） < `Command Panel` < `菜单 Popover`（`#36363B`）。
  - **菜单最亮铁律**：菜单（`--color-bg-popover`）在任何层级下始终最亮，包括在对话框与 Command Panel 内部打开的菜单。
- **半透明白色叠加法则**：控件底色（`--color-bg-control`）、Hover（`--color-bg-hover`）、Disabled 底色（`--color-bg-disabled`）、分隔线（`--color-border-divider`）、Disabled 边框（`--color-border-disabled`）与 Keycap 在 Dark Mode 下均为不同透明度的半透明白色（`rgba(255,255,255, α)`），确保落在任何表面上都比该表面自身更亮。

## 3.2 阴影与边框分工
- **容器级单次投射**：阴影仅由最外层浮层/弹窗容器形状投射，容器内部子元素不各自投射阴影。
- **明暗分层差异**：Light Mode 下依靠容器阴影与浅色边框共同区分层级；Dark Mode 下阴影几乎不可见，浮层与下层页面的分离主要由容器边框（如 `--color-border-muted`、Dialog 的外侧 1 物理像素 `--color-dialog-outline` 与内侧 `1px` `--color-dialog-edge-highlight`）及表面提亮承担。

## 3.3 固定深色表面（Mode-Invariant Dark Surfaces）
- 以下表面在 Light Mode 与 Dark Mode 下使用同一套深色视觉规则，不随系统明暗模式反色：
  1. **播放页舞台与播控组件（Player Chrome）**：视频背景、顶底栏渐变、底栏播控控件、进度条、播放菜单、Playback Feedback 与 Player Error Banner。  - **Dialog 对话框内**：需要校验的输入框下方（间距 `--spacing-1: 4px`）恒定预留 `1` 行红字高度（左边缘与所属输入框左边缘对齐），确保报错出现或消失时对话框高度不发生跳动（`WebDav Folder` 对话框仅在最下方 `Password` 输入框下预留 1 行）。
  2. **Cover Summary 的 Backdrop Form**：背景大图铺满叠加从左向右衰减的黑色 Scrim（`--color-cover-summary-scrim`）与白色文字（`--color-cover-summary-text`）。（注：`Cover Summary` 的 `Split Form` 则分别适配 Light Mode 与 Dark Mode。）

---

# 4. 页面布局边距与滚动条预留法则（Layout Margins & Scrollbar Channel）

## 4.1 页面滚动条恒定预留通道
- 自定义滚动条（`C-07.1 Scrollbar`）本身为 Overlay 渲染（不占布局流），但为防止页面级垂直滚动条遮挡右侧内容，Workbench 页面在右侧 Trailing Padding 之外**恒定预留 `--width-page-scrollbar-channel`（`16px`）的专属通道**：
  - **Workbench 标准页面（`L-01.3`、`L-04.3`、`L-05.3`）**：内容区 Leading 边距为 `--spacing-8`（`32px`），Trailing 边距为 `--spacing-8`（`32px`）+ `--width-page-scrollbar-channel`（`16px`）= `48px`；顶部内边距 `--spacing-1`（`4px`），底部内边距 `--spacing-6`（`24px`）。
  - **Settings 分类内容页（`L-02.3`）**：Leading `--spacing-6`（`24px`），Trailing `--spacing-6` + `--width-page-scrollbar-channel` = `40px`，Bottom `--spacing-6`（`24px`）。
  - **顶栏右侧边距（`L-01.2`、`L-07.1`、`L-08.2`）**：统一使用 `--padding-app-topbar-trailing`（`--spacing-6` + `--width-page-scrollbar-channel` = `40px`）。

## 4.2 媒体卡片网格（Media Card Grid）水平对齐补偿法则
- `C-11.5 Media Card` 包含 `--padding-library-media-card-hover`（`12px`）的四周交互外扩内边距。
- 为使**未 Hover 时卡片内封面图（`C-11.1 Cover`）的可见左右边缘**与页面上方采用 `--spacing-8`（`32px`）边距的标题行、操作栏或 `Cover Summary` 严格左、右齐平：
  - 所有媒体卡片网格（`Recent`、`Library Overview`、`Library Episode Grid`、`Excerpt Overview`）统一使用 `--padding-workbench-media-card-grid-inline`：
    - **Leading**：`--spacing-5`（`20px`），加上卡片自身左侧 `12px` 交互内边距，封面左缘恰好落在 `32px`（`--spacing-8`）。
    - **Trailing**：`--spacing-5` + `--width-page-scrollbar-channel`（`36px`），加上卡片自身右侧 `12px` 交互内边距，封面右缘恰好与右侧留出滚动条通道后的 `48px` 边界齐平。

## 4.3 水平双列表单对齐法则
- 对话框内的水平双列表单（`Rename`、`WebDav Folder`、`SMB Folder`、`FTP Folder`、`NFS Folder`、`Export to Anki` 底部的 `File Name` 与 `Location`）：
  - 左侧 Label 列固定宽度 `--width-form-label`（`72px`），左对齐；
  - Label 列与右侧输入框/内容列水平间距为 `--spacing-3`（`12px`），表单行间距为 `--spacing-3`（`12px`）；
  - 右侧输入框或尾部图标字形的可见右缘与 Footer 最右侧按钮的右缘严格对齐。

---

# 5. 封面加载与防闪烁规则（Cover Loading & Anti-Flicker）

1. **120ms 防闪烁阈值**：封面图在异步加载或解码耗时超过 `120ms`（`--delay-cover-anti-flicker`）时才展示微光骨架屏（Shimmer）；在 `120ms` 内完成加载（如内存缓存命中）直接展示图片，不展示骨架屏以避免视觉频闪。
2. **平滑淡入**：触发骨架屏后，图片就绪时以 `0.20s`（`--duration-cover-crossfade`）平滑淡入真实封面。
3. **默认封面直出**：未设置自定义封面的项（如默认 Excerpt 列表）直接呈现静态默认封面（占位底色 `--color-library-cover-placeholder-bg` 与默认图标），不触发骨架屏。
4. **严禁破坏原图比例**：封面统一采用原比例 `Aspect Fill` 与 `Center Crop`，严禁拉伸、补边、扩图、镜像、重绘或修改封面源文件。
