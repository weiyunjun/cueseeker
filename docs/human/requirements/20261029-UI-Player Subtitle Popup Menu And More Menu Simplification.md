# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Toast Usage Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/data/Data.md`
- `docs/human/design/playback/Playback Core.md`

# 需求描述

1. **底栏字幕按钮改为弹出菜单（`C-04.1 Menu / Player Subtitle Menu`）**：
   - 播放器底栏字幕按钮不再直接切换字幕开关，点击后在按钮上方弹出**字幕菜单**（一级菜单）。
   - 字幕按钮外观与 `More` 按钮一致：仅在字幕菜单打开期间呈现 `Open` 态高亮底色，菜单关闭后恢复透明底色（不再随字幕开启状态常驻高亮）；字幕按钮不展示 Tooltip。
   - **菜单结构**：
     - 上半部分按既有字幕排序规则列出当前视频匹配的全部字幕（名称显示最后最多 2 级后缀名，如 `.ass`、`.sc.ass`、`.srt`），该视频的默认字幕右侧显示 `Default`（简中 `默认` / 繁中 `預設`）标签；不再显示 `Current` 标签。
     - 字幕列表下方为一条菜单分隔线（`C-04.4 Menu Divider`）。
     - 最底部为关闭字幕单选项（英文 `Off` / 简中 `关闭` / 繁中 `關閉`）。
   - **勾选与点击交互**：
     - 当字幕处于开启状态时，当前正在使用的字幕项左侧显示勾选图标（`check`），底部 `Off` 项不勾选；当字幕处于关闭状态时，上方字幕项均不勾选，底部 `Off` 项左侧显示勾选图标。
     - 点击已勾选的项：仅关闭菜单，不弹出 HUD 提示。
     - 字幕开启时点击另一条字幕：切换为所选字幕并关闭菜单，画面中央弹出 1 秒 HUD（图标 `subtitles`，英文 `Subtitle Switched` / 简中 `字幕已切换` / 繁中 `字幕已切換`）。
     - 字幕开启时点击 `Off`：关闭字幕显示并关闭菜单，弹出 1 秒 HUD（英文 `Subtitles Off` / 简中 `字幕已关` / 繁中 `字幕已關`）。
     - 字幕关闭时点击某条字幕：恢复开启字幕显示并加载所选字幕、关闭菜单；若点选的是关闭前正在使用的同一条字幕则弹出 `Subtitles On`（`字幕已开` / `字幕已開`）HUD，若点选的是另一条字幕则弹出 `Subtitle Switched`（`字幕已切换` / `字幕已切換`）HUD。

2. **保留字幕快捷键开启/关闭功能**：
   - 播放页字幕快捷键（默认 `Q`）及手柄对应按键（`L3`）保持开启/关闭字幕的功能，触发时弹出 `Subtitles On` / `Subtitles Off` HUD。
   - 字幕的开启/关闭状态保持为全局持久化状态；按快捷键关闭字幕后再按快捷键重新开启时，恢复显示关闭前正在使用的字幕。

3. **播放器移除设置默认字幕/默认音轨入口与加载规则**：
   - 播放器 UI 中不再提供修改默认字幕与默认音轨的菜单入口；在播放器菜单中切换字幕或音轨仅对当次播放临时生效，不持久化修改该视频的默认字幕与默认音轨记录（底层数据库的默认字幕与默认音轨存储及读取能力保留）。
   - 每次从媒体库相关入口（Library 剧集卡片、Recent 观看记录、Command Panel 的 Recent Videos、视频播放列表的上一集/下一集与列表选集）播放视频（含重新打开正在播放的同一视频）时，始终加载该视频的默认字幕与默认音轨。
   - 从已显式指定字幕的入口（Search 搜索结果、Excerpt List 摘录列表、Deep Link 外部链接）播放视频时，加载该入口显式指定的字幕与该视频的默认音轨。

4. **精简 `More`（`...`）弹出菜单与无音轨表现**：
   - `More` 一级菜单移除 `Subtitle`、`Default Audio Track` 与 `Default Subtitle`，仅保留 `Audio Track`（简中 `音轨` / 繁中 `音軌`）一个二级菜单入口，且该一级菜单项始终处于可用可展开状态。
   - 当视频存在音轨时，展开的二级菜单列出全部音轨，当前正在播放的音轨左侧显示勾选图标，默认音轨右侧显示 `Default`（`默认` / `預設`）标签，不再显示 `Current` 标签。
   - 当视频没有音轨时，展开的二级菜单显示一行不预留左侧勾选槽位的禁用态（`Disabled`）菜单项，文案为英文 `No Audio Tracks` / 简中 `无音轨` / 繁中 `沒有音軌`。

# 验收标准

1. 点击播放器底栏字幕按钮向上弹出字幕菜单，菜单打开期间按钮显示高亮底色，关闭后恢复透明底色，悬停按钮无 Tooltip；菜单依次展示匹配的字幕列表（默认字幕带 `Default` 标签）、分隔线与底部的 `Off / 关闭 / 關閉` 选项。
2. 字幕开启时菜单勾选当前字幕，切换其它字幕后画面字幕与 Playback Overlay 台词立即更新并弹出 `Subtitle Switched / 字幕已切换 / 字幕已切換` HUD；点击 `Off` 后字幕隐藏并弹出 `Subtitles Off / 字幕已关 / 字幕已關` HUD，再次打开字幕菜单时勾选落在 `Off` 上。
3. 按快捷键 `Q` 可正常切换字幕开启与关闭并弹出对应 HUD，重新开启时恢复关闭前选中的字幕；关闭字幕后切换视频仍保持字幕关闭状态。
4. 在播放器中临时切换字幕或音轨后，再次从 Library / Recent 等入口打开该视频时恢复加载默认字幕与默认音轨；从 Search、Excerpt List、Deep Link 打开时加载对应显式指定的字幕。
5. 点击播放器底栏 `...` 按钮，一级菜单仅展示 `Audio Track / 音轨 / 音軌`；有音轨时二级菜单勾选当前音轨并为默认音轨展示 `Default` 标签（无 `Current` 标签），无音轨时二级菜单可正常展开并展示左对齐禁用态的 `No Audio Tracks / 无音轨 / 沒有音軌`。