# 版本

main

# 关联设计

- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/playback/Playback Edge Cases.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/Icon Registry.md`

# 需求描述

1. **首次初始化启动默认显示 `File` 一级界面**
   - 应用首次初始化启动（本地尚无历史停留页面记录，或本次启动时本地数据库为全新初始化创建）时，主窗口默认打开 `File` 一级界面（而非 `Search` 界面），并将当前停留一级界面记录为 `File`。
   - 后续启动维持既有记忆规则，恢复上次退出前停留的一级界面。

2. **移除 `File` 分步引导教程与 `View Tutorial` 入口，简化 `File` 一级空状态**
   - 移除 `File` 一级无根文件夹时的 3 步分步引导界面（含底部 `Back`、`Next`、`Done` 按钮）及全部配套生命周期规则（完成状态本地持久化、启动期间跨页面步数记忆、阅读教程中途后台索引完成暂缓刷新页面）。
   - 移除 `File` 一级空状态中的 `View Tutorial` 按钮及相关多语言文案与图标说明，移除空状态组件并排双按钮规格。
   - 当 `File` 无任何已入库根文件夹时，保留主窗口顶栏（标题 `File`），隐藏顶栏下方的操作状态栏（`Add Folder`、`Index All`、`Last Updated`），直接居中展示空状态：
     1. `folder-hint` 强调色图标（`--size-empty-state-icon`: `68px`）；
     2. 说明文字（间隔 `--gap-empty-state-icon-to-text`: `14px`）：
        - 英文：`Add a folder containing video and subtitle files.`
        - 简体中文：`添加包含视频与字幕文件的文件夹。`
        - 繁体中文：`加入包含影片與字幕檔案的資料夾。`
     3. 单个居中的 `Add Folder`（`Neutral`）按钮（间隔 `--gap-empty-state-icon-to-text`: `14px`，复用 `folder-plus` 图标，点击弹出原有的 5 项协议菜单；存在进行中的库任务或数据库压缩时置灰禁用并复用原有禁用 Tooltip）；
     4. 处于正在索引或索引失败状态时，仍在按钮正下方 `--spacing-3`（`12px`）处另起一行水平居中挂载可点击的状态指示器，出现或消失不影响上方主体位置（零跳动）；首个文件夹入库完成后立即切换为根文件夹列表界面。
   - 其余界面的无文件夹 `Go to File` 引导空状态、跨界面冻结与刷新衔接，以及全应用空状态去除标题与取消 `380px` 限宽维持不变。

# 验收标准

1. **首次初始化启动默认落位**：全新初始化启动（无历史停留页面记录或本地数据库全新创建）时，应用默认打开 `File` 一级界面；切换到 `Search`、`Excerpt` 等其它一级界面后退出重开，正常恢复上次退出前停留的一级界面。
2. **`File` 一级空状态简化与零跳动**：无任何已入库根文件夹时，`File` 一级界面不再出现分步引导界面或 `View Tutorial` 按钮，直接居中展示强调色文件夹图标、说明文字与单个 `Add Folder` 按钮；开始添加文件夹索引或索引失败时，按钮正下方独立一行居中显示可点击状态文字，上方图标、文字和按钮不发生位移跳动；首个文件夹入库完成后立即展示根文件夹卡片列表。
3. **其余界面无文件夹强引导保持一致**：0 个文件夹时切换到 `Search`、`Library`、无摘录集下的 `Excerpt`、以及无记录子页下的工作台 `Recent` 与播放页 `Command Panel -> Recent`，仍正常展示带 `Go to File` 按钮的无文件夹引导空状态，点击后跳转进入 `File` 一级空状态界面。