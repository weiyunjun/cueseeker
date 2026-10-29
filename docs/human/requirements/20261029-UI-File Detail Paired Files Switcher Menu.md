# 版本

main

# 关联设计

- `docs/human/design/ui/UI Index.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **文件详情（`File Info`）顶部改为配对文件下拉触发器（`L-06.8 File Detail Dialog Layout`）**：
   - **适用范围**：仅适用于视频与字幕文件的 `File Info` 弹窗；文件夹详情（`Folder Info`）与任务详情（`Task Info`）弹窗的顶部头部行保持既有静态图标与名称展示不变。
   - **顶部固定**：`File Info` 弹窗的标题行（`Header`）与顶部文件切换触发器（`File Header Row`）固定在弹窗顶部，不随下方属性分组卡片（`Property Groups`）滚动；下方属性分组区域独立垂直滚动。
   - **尺寸与视觉样式**：
     - 触发器撑满弹窗内容区宽度，圆角为 `--radius-settings-group`（`10px`），边框宽度为 `--border-width-control`（`1px`），垂直内边距为 `--spacing-3`（`12px`），水平内边距为 `--spacing-4`（`16px`）。
     - 内部从左到右依次为：`40×40px`（`--size-detail-file-icon-container`）文件类型大图标（`video` 或 `subtitles`）、文件名文本（`--font-size-body` `14px`、`--font-weight-control` `500`、行高 `--line-height-detail-file-title` `20px`、`--color-text-primary`，最多显示 2 行，超出在第二行末尾省略截断）、右侧下拉箭头 `caret-down`（`--size-card-chevron` `16px`，`--color-text-secondary`），元素水平间距均为 `--spacing-4`（`16px`）。
     - 状态反馈（纳入按下态白名单）：
       - **Default**：背景 `--color-table-bg`，边框 `--color-border-control`。
       - **Hover / Open**：背景 `--color-bg-hover`，边框 `--color-border-control-hover`。
       - **Pressed**：背景 `--color-bg-pressed`，边框 `--color-border-control-hover`。

2. **配对文件下拉菜单与切换交互（`C-04.1 Menu / Dropdown Menu`）**：
   - **弹出与尺寸**：从某个视频或字幕点击 `Get Info` 打开弹窗时，默认展示该所点击文件的详情；点击顶部触发器后，在其正下方（间距 `--spacing-1` `4px`）弹出与触发器等宽的下拉菜单（最大高度遵守 `C-04.1 Menu` 规则：自然高度、`--max-height-menu` `480px` 与可用空间三者取小）。
   - **菜单内容与顺序**：完整列出当前单集配对关系中的全部文件（包含当前正在查看的文件），排列顺序与 File 界面单集分组卡片一致（视频文件在最上方，配对字幕文件按既有顺序依次排在下方）。
   - **菜单项样式**：复用 `C-04.3 Menu Item / Action Menu Item`，不显示勾选标记；左侧为 `18px`（`--size-menu-item-symbol-font-size-macos`）单色描边图标（`video` 或 `subtitles`，对齐首行文字），右侧（间距 `--spacing-2` `8px`）为完整文件名（`--font-size-control` `14px` Regular，超出宽度时多行自然折行完整展示，不截断；多行时上下内边距为 `--padding-settings-row-y` `6px`）。
   - **选择与模态交互**：遵守全局菜单模态与键盘导航规则（鼠标悬停或方向键上下移动高亮为 `--color-bg-hover`，回车或左键点击选择，Esc 或外部点击收起菜单）；选择另一个配对文件后，菜单收起，顶部触发器与下方属性分组立即切换为所选文件的详情，且下方滚动区域自动回到顶部（下方各属性分组内容维持现状）。

3. **弹窗打开期间的数据快照冻结**：
   - 打开 `File Info` 弹窗时，一次性读取并冻结当前配对关系中全部文件的列表及各自详情数据。
   - 弹窗打开期间，若后台任务导致数据库内容发生变化，当前展示的详情以及在下拉菜单中切换任意配对文件所展示的详情均保持打开时的冻结快照不变。

# 验收标准

1. 从 File 界面任意视频或字幕的 `...` -> `Get Info` 打开 `File Info` 弹窗，默认展示所点选文件的详情；顶部图标与名称包裹在带边框与右侧 `caret-down` 箭头的圆角触发器内，并与弹窗标题一起固定在顶部不随下方属性卡片滚动；`Folder Info` 与 `Task Info` 弹窗保持原样。
2. 顶部触发器的默认、悬停（`Hover`）、按下（`Pressed`）与菜单展开（`Open`）状态配色符合规范，触发器内文件名最多展示 2 行（超出尾部省略）。
3. 点击顶部触发器，在正下方弹出等宽下拉菜单，按「视频在上、配对字幕在下」的顺序列出包含当前文件在内的全部配对文件；每个菜单项不带勾选标记，左侧显示 18px 视频/字幕小图标，右侧完整展示文件名（超长时自然换行不截断）。
4. 通过鼠标点击或键盘上下方向键 + 回车选择菜单中的任意配对文件后，菜单关闭，顶部触发器与下方属性卡片立即切换为所选视频或字幕的对应详情，且下方滚动条回到顶部。
5. `File Info` 弹窗打开期间数据库内容发生变化时，弹窗内当前文件及下拉切换的其余配对文件详情均保持打开时的快照不变。