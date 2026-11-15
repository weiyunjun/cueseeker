# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Text Selection Rules.md`
- `docs/human/design/ui/UI Accessibility Rules.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/workbench/Settings and Localization.md`

# 需求描述

1. **入口与导航（Menu Bar 与 `Settings` 侧边栏）**：
   - **Menu Bar 应用菜单入口**：在应用菜单最顶部（`Settings…` 上方并以菜单分隔线隔开）新增关于入口（简：`关于字幕求索`；繁：`關於字幕求索`；英：`About CueSeeker`），点击后打开或前置独立的 `Settings` 窗口并直接定位至 `About` 分类（纳入设置窗口分类前进/后退历史）；通过常规入口（主界面设置图标或 `⌘,`）首次打开 `Settings` 仍默认选中 `General`，后续在本次运行期间再次打开保持上次停留分类。
   - **`Settings` 左侧导航栏**：在现有 4 个分类末尾新增第 5 个分类 `About`（简：`关于`；繁：`關於`；英：`About`），图标使用 `info`（`Regular`，尺寸复用 `--size-app-sidebar-item-icon: 23px`）；切换应用语言后，Menu Bar、`Settings` 顶栏/侧边栏及 `About` 页面全部文案立即实时刷新。

2. **`Settings -> About` 页面布局与 Token 规范（禁止硬编码与私自特殊实现）**：
   - **Token 增改约束**：仅新增 1 个尺寸 Token `--size-about-app-icon: 80px`，不修改任何已有 Token，其余全部复用既有设计 Token 与通用组件。
   - **页面容器**：完全复用 `L-02.3 Settings Category Layout` 内容区容器规格（内边距、右侧恒定滚动条预留通道、区块纵向间距 `--spacing-6: 24px`，超出窗口高度时纵向滚动）。
   - **顶部项目信息区**：顶部内边距 `--spacing-4`（`16px`），内部上下两部分间距 `--spacing-4`（`16px`）：
     - **居中头部块**：水平居中纵向排布——应用内置图标原图（宽高 `--size-about-app-icon: 80px`，直接展示原图，不额外叠加圆角裁切或描边）→ 间距 `--spacing-3`（`12px`）→ 应用名称（简/繁：`字幕求索`；英：`CueSeeker`，字号 `--font-size-page-title: 20px`、字重 `--font-weight-page-title: 600`、颜色 `--color-text-primary`）→ 间距 `--spacing-1`（`4px`）→ 当前版本号（简/繁：`版本 X.Y.Z`；英：`Version X.Y.Z`，字号 `--font-size-caption: 12px`、颜色 `--color-text-muted`）。
     - **项目简介段落**：容器宽度与下方设置卡片一致（`100%`），左右内边距 `--spacing-4`（`16px`），与下方设置卡片内左右内容边界严格对齐；文本左对齐、自然多行折行不截断，字号 `--font-size-body`（`14px`）、行高 `--line-height-cover-summary-description`（`20px`）、颜色 `--color-text-secondary`：
       - 简体中文：`字幕求索是一个以搜索字幕、摘录字幕和队列播放字幕为核心的语言学习工具，兼具导出 Anki 卡片、Deep Link、长截图等诸多实用功能。`
       - 繁体中文：`字幕求索是一個以搜尋字幕、摘錄字幕和佇列播放字幕為核心的語言學習工具，兼具匯出 Anki 卡片、Deep Link、長截圖等諸多實用功能。`
       - 英文：`CueSeeker is a language learning tool centered around subtitle search, excerpt, and queue playback, complemented by practical features such as Anki card export, deep links, and collage.`
   - **下方无标题设置卡片**：圆角、背景、描边、行高、内边距与行间分隔线完全复用 `L-02.3 Settings Category Layout` 规格，仅包含以下 2 行：
     - **第 1 行（简/繁：`版本更新`；英：`Software Update`）**：右侧由可选状态提示（复用 `C-08.5 Workbench Status Indicator`）与操作按钮（复用 `C-03.1 Button` 与 `C-09.4 Spinner`）水平排布组成，二者间距 `--spacing-3`（`12px`）。
     - **第 2 行（简：`开源仓库`；繁：`開源儲存庫`；英：`Repository`）**：右侧外部链接项由文字（简：`GitHub 仓库`；繁：`GitHub 儲存庫`；英：`GitHub Repository`，字号 `--font-size-control: 14px`、字重 `--font-weight-control: 500`、颜色 `--color-text-secondary`）与右侧 `link-simple` 图标（尺寸 `--size-button-icon: 18px`，颜色 `--color-text-secondary`）组成，图文间距 `--spacing-2`（`8px`）。**交互与指针规则**：文字与右侧图标整体作为点击与悬停热区——鼠标悬停在文字或图标上时，统一显示手型指针（`Grab`）且**仅在文字下方**显示同色下划线（粗细 `--width-interactive-text-underline: 1px`，偏移 `--offset-interactive-text-underline: 2px`，无背景色块、图文不变色）；单击文字或图标任意位置均通过系统默认浏览器打开 `https://github.com/weiyunjun/cueseeker`。

3. **手动检查 GitHub Release 更新规则与状态生命周期**：
   - **触发方式与生命周期**：应用启动或打开 `About` 页时不自动联网检查，仅在用户手动点击「检查更新」时查询仓库最新正式版 Release（自动忽略草稿 `Draft` 与预发布 `Pre-release`）。**检查状态与结果仅在 App 本次运行期间保留（切换设置分类或关闭再打开设置窗口均保持当前进行中的请求或已查出的结果，不持久化落盘；退出并重启 App 后恢复为初始态）**。
   - **五种状态表现**：
     - **初始态**：不显示状态提示，右侧显示可用 `Button / Neutral`（前置 `arrow-clockwise` 图标，简：`检查更新`；繁：`檢查更新`；英：`Check for Updates`）。
     - **检查中**：隐藏旧状态提示，右侧切换为禁用态 `Button / Neutral`，前置图标替换为 `16px` `Spinner`，文案切换为 `正在检查…` / `正在檢查…` / `Checking…`。
     - **已是最新版本（含仓库尚无正式 Release 返回 `404`、或远端正式版语义化版本号不高于本地版本）**：左侧显示 `check-circle` 图标 + `--color-text-secondary` 文案（简：`当前已是最新版本`；繁：`目前已是最新版本`；英：`CueSeeker is up to date`），右侧恢复可用 `Button / Neutral`（`检查更新` / `檢查更新` / `Check for Updates`）。
     - **发现新版本（远端正式版语义化版本号剥离可选 `v`/`V` 前缀后高于本地版本）**：左侧显示无图标的 `--color-text-active` 文案（简：`发现新版本 vX.Y.Z`；繁：`發現新版本 vX.Y.Z`；英：`New version vX.Y.Z available`），右侧切换为前置 `link-simple` 图标的 `Button / Primary`（简：`前往下载 vX.Y.Z`；繁：`前往下載 vX.Y.Z`；英：`Download vX.Y.Z`），点击在默认浏览器打开对应 GitHub Release 页面。
     - **检查失败（断网、超时或响应异常）**：左侧显示 `warning` 图标 + `--color-danger-text` 文案（简：`检查更新失败，请稍后重试`；繁：`檢查更新失敗，請稍後重試`；英：`Failed to check for updates`），右侧恢复可用 `Button / Neutral` 供重试。

4. **文本选择、全局 Hover 抑制与无障碍一致性**：
   - **静态文本划选**：`About` 右侧内容区作为连续静态文本流接入 `UI Text Selection Rules.md`——应用名称、版本号、项目简介、卡片行标题与当前可见的更新状态文字均支持 `I-beam` 自由跨段拖选复制；`GitHub 仓库` 文字支持复合模式（单击跳转、按住拖拽时转为 `I-beam` 选词复制且松手不误触打开网页），图标与按钮不可选。
   - **全局 Hover 抑制**：打开设置窗口或切换分类进入 `About` 页时遵守全局 `Hover` 抑制规则，鼠标实际移动前静止落点处的按钮与 `GitHub 仓库` 均不激活悬停底色、下划线或 `Grab` 手型指针。
   - **无障碍焦点遍历**：`Settings` 左侧导航栏焦点顺序扩展为 `General -> Play -> Shortcuts -> Subtitle -> About`；`About` 右侧内容区依次遍历「版本更新操作按钮（含 `Checking…` 禁用态；触发检查进入禁用态期间外圈无障碍光圈保留在按钮上不丢失）」与「`GitHub 仓库` 链接整体触发区（外圈光圈圆角 `--radius-field: 6px`，偏移 `2px`）」，按激活键可执行对应操作。

5. **设计文档同步安排**：
   - 关联 UI 与设置设计文档（含新增 Token、`About` 布局、设置窗口 `GitHub 仓库` 的 `Grab` 指针与复合文本登记、图标与无障碍规则）待验收完成后再统一提交更新。

# 验收标准

1. **入口、导航与多语言实时切换验收**：Menu Bar 应用菜单顶部显示 `关于字幕求索` / `關於字幕求索` / `About CueSeeker` 及分隔线，点击可打开或前置 `Settings` 窗口并定位至 `About`（顶栏后退/前进按钮可正常回退历史）；`Settings` 左侧导航栏第 5 项显示 `info` 图标与 `关于` / `關於` / `About`；通过 `⌘,` 或主界面设置图标首次打开默认落在 `General`，后续重开保持上次停留分类；切换简、繁、英后，Menu Bar 与 `About` 页面全部文案（含已显示的状态文字）立即按新语言刷新。
2. **视觉排版与「GitHub 仓库」交互验收**：`Light Mode` 与 `Dark Mode` 下，顶部 `80px` 应用原图图标、名称、版本号、左对齐项目简介及下方两行卡片完全符合 Token 规范，项目简介左右内容边界与卡片内左右内容边界对齐；鼠标悬停在 `GitHub 仓库` 文字或右侧链接图标上时，均呈 `Grab` 手型且仅文字下方显示同色下划线，单击文字或图标任一位置均在默认浏览器打开开源仓库主页。
3. **检查更新状态与运行期生命周期验收**：启动应用或打开 `About` 页不自动发起网络请求；手动点击「检查更新」期间显示禁用态转圈按钮；当前仓库尚无正式 Release（`404`）时显示 `当前已是最新版本`；存在更高正式版时显示新版本号与主色下载按钮并能打开对应 Release 页面；断网时显示红色失败提示并可重试；查出结果后切换至其他设置分类再切回、或关闭设置窗口再打开，结果状态保持不丢失，退出重启应用后恢复为初始态。
4. **文本选择、Hover 抑制与无障碍验收**：`About` 页静态文本支持跨段拖选与 `⌘C` 干净复制，按住拖拽 `GitHub 仓库` 文字可复制且松手不误打开网页；刚打开窗口或切入 `About` 页鼠标未移动前不提前显示悬停态、下划线或手型指针；键盘与手柄无障碍可按顺序遍历左侧 5 个分类与右侧更新按钮（含检查中禁用态保留光圈）、开源仓库链接项并正常激活。