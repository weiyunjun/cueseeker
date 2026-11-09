# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`

# 需求描述

1. **Cover Summary 标题与两行副文案垂直间距及行高调整（`UI Tokens.md` & `C-11.2 Cover Summary`）**：
   - 保持 `Cover Summary` 内容区高度 `180px` 不变，调大顶部标题与两行副文案之间的垂直间距：
     - `--gap-cover-summary-title-meta`（标题与第 1 行副文案间距）：`8px` -> `12px`。
     - `--gap-cover-summary-meta-lines`（第 1 行与第 2 行副文案间距）：`6px` -> `10px`。
   - 新增 `--line-height-cover-summary-description: 20px`，用于 `Cover Summary` 副文案及展开后的描述详情文本行高。

2. **Excerpt 二级界面两行副文案顺序互换（`L-05.3 Excerpt List Detail Layout`）**：
   - 将标题下方的两行副文案位置互换：
     - 第 1 行：有效台词总数量与创建时间（`xx excerpts  Created yyyy-MM-dd`，中间以 2 个英文空格分隔）。
     - 第 2 行：摘录列表描述（预留单行高度，超出单行或含换行时单行尾部以 `...` 截断；未填写时显示占位文案 `No description`）。

3. **Library 二级界面文件夹地址点击打开交互（`L-04.3 Library Folder Detail Layout` & `UI Interaction Rules.md`）**：
   - **本地文件夹**：第 2 行文件夹路径文本支持点击交互。鼠标移至可见路径文字区域时，文字颜色保持不变，底部显示与当前文字同色的下划线（粗细 `--width-interactive-text-underline: 1px`、偏移 `--offset-interactive-text-underline: 2px`），指针切换为 `Grab` 手型；原地按下并松开左键在访达（Finder）中打开该文件夹，按住左键拖动（或从外部非交互区域拖入）则执行单行文字划选，松手不触发打开文件夹。
   - **远程文件夹（WebDAV / SMB / FTP / NFS）**：第 2 行文件夹路径不提供点击打开交互，Hover 无下划线，指针为 `I-beam`，保持作为普通静态可选文本。

4. **Excerpt 二级界面截断描述的原地详情浮层与文字选中交互（`UI Tokens.md`、`C-07.1`、`C-11.2`、`L-05.3` & `UI Interaction Rules.md`）**：
   - **触发条件与点击/拖选分流**：
     - 仅当第 2 行描述文本未完整显示（单行发生宽度溢出截断，或原始描述包含回车换行）时，鼠标移至可见描述文字区域显示与当前文字同色的下划线，指针切换为 `Grab` 手型；原地按下并松开左键展开描述详情容器（同时清除界面上已有的文字选区），按住左键拖动则执行单行文字划选，松手不展开详情容器。
     - 当描述文本已在单行内完整显示或为未填写的占位文案（`No description`）时，Hover 无下划线，不可点击展开，指针为 `I-beam`，保持作为普通静态可选文本。
   - **详情容器几何定位（首行文字原地不动，容器外框向外包覆）**：
     - 新增水平内边距 `--padding-cover-summary-description-popover-x: 12px` 与垂直内边距 `--padding-cover-summary-description-popover-y: 8px`。
     - 展开后，容器内第 1 行文字的左上角起点及折行宽度与展开前第 2 行单行描述的区域完全重合（`0px` 零偏移），容器外框围绕文字区域向左右各外扩 `--padding-cover-summary-description-popover-x`（`12px`）、向上下各外扩 `--padding-cover-summary-description-popover-y`（`8px`）；容器高度随文本内容自适应，容器下外框最高延伸至最下方操作按钮（`Action Row`）的下外沿为止。
   - **详情容器外观与随形态适配样式**：
     - 圆角统一为 `--radius-control`（`8px`），外层独立描边宽度为 `--border-width-control`（`1px`，不占用内部文字排版空间）。
     - **宽窗分栏模式（`Split Form`）**：容器背景为 `--color-bg-popover`（Light `#FFFFFF` / Dark `#36363B`），边框颜色为 `--color-border-control`（Light `#E5E7EB` / Dark `#4A4A52`），阴影为 `--shadow-popover`，文字颜色维持 `--color-text-secondary`，垂直滚动条滑块使用 `--color-scrollbar-thumb-default` / `--color-scrollbar-thumb-interactive`。
     - **窄窗背景大图模式（`Backdrop Form`）**：容器背景为新增的不透明纯实色 `--color-cover-summary-description-popover-backdrop-bg`（Light `#4C4C54` / Dark `#4C4C54`），边框颜色复用 `--color-cover-summary-text` 配合 `--opacity-cover-summary-button-border`（`35%`），阴影为 `--shadow-player-overlay`，文字颜色维持 `--color-cover-summary-text` 配合 `--opacity-cover-summary-description`（`76%`），垂直滚动条滑块使用 `--color-player-scrollbar-thumb-default` / `--color-player-scrollbar-thumb-interactive`。
     - 容器内部文字字号为 `--font-size-body`（`14px`）、行高为 `--line-height-cover-summary-description`（`20px`），保留用户输入的回车换行并自动折行；当文本高度超出容器最大高度时，在容器右侧以 `Overlay` 方式悬浮展示自定义垂直滚动条（`C-07.1 Scrollbar / Vertical`，不缩减内部文字排版宽度）。
   - **容器内文字选中与容器外关闭（类菜单模态）**：
     - **容器内部**：指针在文字区显示为 `I-beam`，完整支持左键拖拽划选（含从容器内边距空白处按下拖入文字起选，以及起选后拖出容器边界持续跟随选区至松手）、双击选词、三击全选与 `Cmd + C` 复制；在容器内部单击、双击、拖拽选词或滚动均保持容器打开，不触发收起。
     - **容器外部与模态屏蔽**：详情容器打开期间，下层界面悬停状态冻结、整窗口禁止滚动；在容器边界之外按下鼠标左键或右键、按 `Esc` 键或切换界面时，容器立即收起并清除容器内的文字选区，恢复为点击前的单行状态（左键在容器外部按下仅用于收起容器，不穿透触发下层控件）。

# 验收标准

1. **间距与副文案顺序**：Library 与 Excerpt 二级界面顶部 `Cover Summary` 的标题到第 1 行间距为 `12px`、第 1 行到第 2 行间距为 `10px`；Excerpt 二级界面第 1 行显示 `xx excerpts  Created yyyy-MM-dd`，第 2 行显示描述。
2. **Library 文件夹路径交互**：本地文件夹路径在 Hover 时显示同色下划线与 `Grab` 指针，单击打开对应本地文件夹，拖拽则划选路径文字且不打开文件夹；WebDAV / SMB / FTP / NFS 远程文件夹路径 Hover 无下划线、指针为 `I-beam`，点击不触发打开操作。
3. **Excerpt 描述详情容器位置与形态样式**：当描述在单行内已完整显示或为 `No description` 时无下划线且点击不展开；当描述被截断或含多行换行时，Hover 显示同色下划线与 `Grab` 指针，单击展开详情容器，首行文字位置与点击前完全重合无跳动，外框向左右外扩 `12px`、上下外扩 `8px`，下外框最高覆盖至底部按钮下边缘；宽窗下为工作台气泡表面，窄窗下为 `#4C4C54` 不透明实底配 `35%` 半透明白边，文字颜色与展开前完全一致，超出最大高度时右侧悬浮显示垂直滚动条。
4. **详情容器内选词与外部关闭**：在展开的详情容器内可正常拖拽划选、双击、三击选中文字并按 `Cmd + C` 复制，容器内点击或拖拽不会导致容器关闭；点击容器外部任意位置或按 `Esc` 键时容器立即收起（外部左键点击不穿透触发下层按钮或列表），并清除选区。