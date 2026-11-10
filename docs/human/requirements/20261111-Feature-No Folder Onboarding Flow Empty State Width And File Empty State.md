# 版本

main

# 关联设计

- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/playback/Command Panel.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Empty State Icon Registry.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`

# 需求描述

1. **空状态组件宽度修正、去除标题与新增强调色文件夹图标**
   - **Token 增删（`UI Tokens.md`）**：
     - 移除 `--font-size-empty-state-title`（`15px`）、`--gap-empty-state-title-to-message`（`4px`）与 `--max-width-empty-state-message`（`380px`）。
     - 新增 `--max-width-file-onboarding`（`520px`）与 `--height-file-onboarding-content`（`280px`）。
   - **全界面空状态宽度与结构统一**：
     - 全应用空状态统一移除加粗标题（`Title`），仅保留双色调图标、说明文字与可选操作区。
     - 移除空状态说明文字的 `380px` 宽度上限及组件额外水平内边距；空状态容器宽度对齐所在工作台页面的默认内容区宽度（弹窗与浮层内跟随各自容器的内容区宽度），高度自适应并在可用区域内整体水平、垂直居中。
   - **新增强调色文件夹空状态图标（`folder-hint`）**：
     - 造型与尺寸（`--size-empty-state-icon`: `68px`）复用现有 `folder`，左上后盖顶签使用 `--color-card-icon-accent-folder-tab`，前盖主体使用 `--color-card-icon-accent-base`。

2. **`File` 一级界面无文件夹时的分步引导壳层、新空状态界面与生命周期**
   - 当 `File` 中无任何已入库根文件夹时，保留主窗口顶栏（标题 `File`），隐藏原顶栏下方的操作状态栏（`Add Folder`、`Index All`、`Last Updated`），按状态展示以下两个界面之一：
   - **（1）3 步分步引导界面（内容区本单留空）**：
     - 引导容器最大宽度 `--max-width-file-onboarding`（`520px`），在页面内容区水平、垂直居中：上方为高 `--height-file-onboarding-content`（`280px`）的完全空白内容区，下方间隔 `--spacing-6`（`24px`）为靠右对齐的底部按钮栏（高 `--height-control`: `36px`，按钮间距 `--spacing-4`: `16px`）：
       - **第 1 步**：仅显示 `Next` / `下一步` / `下一步`（`Primary` 按钮）。
       - **第 2 步**：左侧 `Back` / `返回` / `返回`（`Neutral` 按钮）+ 右侧 `Next` / `下一步` / `下一步`（`Primary` 按钮）。
       - **第 3 步**：左侧 `Back` / `返回` / `返回`（`Neutral` 按钮）+ 右侧 `Done` / `完成` / `完成`（`Primary` 按钮）。
   - **（2）新的 `File` 空状态界面**：
     - 主体在页面内容区水平、垂直居中，自上而下依次为：
       1. `folder-hint` 强调色图标（`--size-empty-state-icon`: `68px`）；
       2. 说明文字（间隔 `--gap-empty-state-icon-to-text`: `14px`）：
          - 英文：`Add a folder containing video and subtitle files.`
          - 简体中文：`添加包含视频与字幕文件的文件夹。`
          - 繁体中文：`加入包含影片與字幕檔案的資料夾。`
       3. 并排双 `Neutral` 按钮行（间隔 `--gap-empty-state-icon-to-text`: `14px`，按钮间距 `--spacing-4`: `16px`）：
          - 左侧：`info` 图标 + `View Tutorial` / `查看教程` / `檢視教學`；
          - 右侧：复用原有 `folder-plus` 图标 + `Add Folder` / `添加文件夹` / `加入資料夾`（点击弹出原有的 5 项协议菜单；存在进行中的库任务或数据库压缩时置灰禁用并复用原有禁用 Tooltip，期间 `View Tutorial` 保持可用）。
     - **独立一行的索引状态文字**：当处于正在索引或索引失败状态时，在双按钮行下沿外侧 `--spacing-3`（`12px`）处另起一行水平居中挂载现有的状态指示器（进行中显示 `Spinner` + `Indexing [Folder]`，失败显示 `warning` + 红色 `Index Failed: [Folder]`，支持点击打开对应任务详情；离开 `File` 页面或取消任务后清除临时失败提示），状态文字出现或消失不影响上方主体块的垂直与水平位置（零跳动）。
   - **（3）教程触发持久化、跨页记忆与索引并发规则**：
     - 本地持久化记录用户是否点击过教程第 3 步的 `Done` 按钮：
       - **从未点击过**：以 0 个文件夹状态启动应用时，进入 `File` 一级界面默认从强制引导第 1 步开始；点击第 3 步 `Done` 后记录为已点击并进入新的 `File` 空状态界面。
       - **已点击过**（含重启应用后，或运行期间移除最后一个文件夹变为 0 个文件夹时）：默认直接显示新的 `File` 空状态界面；仅在主动点击 `View Tutorial` 时从第 1 步打开教程。
     - **应用启动期间步数保持**：教程处于打开状态期间，切换到其它界面再通过侧边栏或跳转按钮返回 `File`，保持在离开前的步数。
     - **阅读中途不自动刷新**：若后台索引进行期间正处于教程界面，即使文件夹中途已完成入库，当前页面保持停留在教程界面不刷新打断；待点击第 3 步 `Done` 后，直接进入已入库的根文件夹列表界面（若点击 `Done` 时仍无已入库文件夹，则进入新的 `File` 空状态界面）。

3. **其余界面的无文件夹强引导空状态与冻结刷新衔接**
   - **触发范围与条件**（仅对以下界面生效；`Library` 二级、`Excerpt` 二级、`File` 二级/三级及 `Playback Overlay -> Playlist` 保持现状不变）：
     - **`Search` 一级、`Library` 一级**：当 `File` 无任何已入库文件夹时隐藏页内工具栏，整页展示无文件夹强引导空状态。
     - **`Excerpt` 一级**：当且仅当全局无任何摘录集且 `File` 无任何已入库文件夹时，隐藏顶部操作栏（并清空残留列表搜索词），展示无文件夹强引导空状态；已有摘录集时照常展示摘录集列表；已有文件夹但无摘录集时维持现有的新建摘录集引导空状态。
     - **工作台 `Recent` 一级（保留顶栏 `Videos` / `Excerpt Lists` 切换标签）** 与 **播放页 `Command Panel` 二级 `Recent Videos` / `Recent Excerpt Lists`**：当且仅当当前子标签无可显示记录且 `File` 无任何已入库文件夹时，展示无文件夹强引导空状态；其余情况维持现状。
   - **强引导内容与跳转一致性**：
     - 居中展示 `folder-hint` 强调色图标 + 说明文字 + 跳转按钮（`Neutral` 按钮，左侧 `folder` 图标）：
       - 说明文字：`Add a folder to get started.` / `添加文件夹以开始使用。` / `加入資料夾以開始使用。`
       - 跳转按钮：`Go to File` / `前往文件` / `前往檔案`
     - 点击跳转按钮进入 `File` 一级界面（在 `Command Panel -> Recent` 中点击时先退出播放页返回工作台再进入 `File` 一级界面），计入顶栏前进/后退历史，展示状态与直接点击侧边栏 `File` 标签完全一致。
     - 一旦首个文件夹索引成功入库，当前停留的非教程强引导界面立即切换为各自的正常默认内容。
   - **冻结页面刷新边界**：移除最后一个文件夹变为 0 个文件夹时，保留现有防打断页面冻结规则；一旦在冻结页面触发拉取最新数据的刷新操作（如在 `Search` 修改搜索词、切换排序或点击筛选，在 `Recent` 切换顶栏标签，或跨页面切换）且满足上述强引导条件，立即解除冻结并切换为无文件夹强引导空状态。

# 验收标准

1. **空状态宽度与结构统一**：`Excerpt` 二级界面等长句空状态提示在常规窗口宽度下单行完整居中显示，不再因 `380px` 限宽提前折行；全应用空状态无加粗标题，所有尺寸与间距严格对应 Token。
2. **`File` 3 步引导壳层与持久化流转**：从未点击过 `Done` 且以 0 文件夹启动应用时，`File` 默认显示第 1 步（靠右 `Next`），第 2 步显示靠右 `Back` + `Next`，第 3 步显示靠右 `Back` + `Done`；在第 2 步切换到其它标签页再通过侧边栏或 `Go to File` 回到 `File` 仍保留在第 2 步；点击第 3 步 `Done` 后进入新空状态界面，重启应用后直接显示新空状态界面而不再默认弹出教程。
3. **`File` 新空状态双按钮、防跳动状态行与教程并发**：新空状态居中展示强调色文件夹图标、说明文字及 `View Tutorial`（带 `info` 图标）与 `Add Folder` 按钮；开始添加文件夹索引后，`Add Folder` 禁用，按钮正下方另起一行居中显示可点击的索引状态文字，且上方图标、文字和按钮不发生任何水平或垂直位移跳动；索引期间点击 `View Tutorial` 可正常查看教程，阅读中途索引完成时页面保持在教程不自动跳走，点击第 3 步 `Done` 后直接显示根文件夹卡片列表。
4. **其余界面无文件夹强引导与冻结衔接**：0 文件夹时，`Search`、`Library`、0 摘录集下的 `Excerpt`、以及无记录子页下的工作台 `Recent`（保留顶栏标签）与 `Command Panel -> Recent` 均显示强调色文件夹图标、提示文字与 `Go to File` 按钮（已有摘录集时 `Excerpt` 与 `Recent -> Excerpt Lists` 照常显示摘录集）；从 `Command Panel -> Recent` 点击 `Go to File` 可退出播放页并进入工作台 `File`；移除最后一个文件夹后，冻结页面在触发刷新操作或跨页切换时正确进入无文件夹强引导空状态。