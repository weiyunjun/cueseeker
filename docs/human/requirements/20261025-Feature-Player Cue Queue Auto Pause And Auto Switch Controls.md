# 版本

main

# 关联设计

- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Interaction Rules.md`
- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Playback.md`
- `docs/human/design/ui/Icon Registry.md`
- `docs/human/design/ui/Tooltip Usage Registry.md`
- `docs/human/design/playback/Playback Core.md`
- `docs/human/design/workbench/Settings and Localization.md`

# 需求描述

1. **出现条件与位置布局**：
   - 仅在**台词队列播放**（如从 Search、Excerpt、Command Panel 搜索结果或最近摘录集、Deep Link 搜索进入播放）时显示；从 Library、Recent Videos、File 页面等入口进入的视频列表播放不显示。
   - 位于播放页底部进度条区域的上方左侧，左边缘与下方左侧播放按钮左边缘对齐（距窗口左缘 `24px`）；进度条悬浮时间胶囊的层级高于该控制栏。
   - 切换上/下一条台词或跨视频加载过渡期间，该控制栏及内部控件位置与尺寸保持稳定，不发生闪烁或位移抖动。

2. **圆角矩形底托与 3 个平行控件**：
   - 外层采用标准播放深色半透明圆角矩形底托（`55%` 不透明度深色底 + `1px` 细描边），内部水平平行排列 3 个控件：
     1. **Auto Pause 按钮**（`自动暂停` / `Auto Pause` / `自動暫停`）：带左侧状态圆点与文字标签；开启时显示常驻浅白高亮底色与绿色状态圆点，关闭时为透明底色与暗色圆点。
     2. **Auto Switch 按钮**（`自动切换` / `Auto Switch` / `自動切換`）：视觉与状态规则同 Auto Pause 按钮；当 Auto Pause 关闭时，Auto Switch 自动关闭并进入禁用状态。
     3. **Gap 时长步进框**：由左侧 `-` 按钮、中间只读等宽时长显示（如 `500 ms`，固定宽度容纳 `10000 ms` 不抖动，禁止键盘输入与聚焦）、右侧 `+` 按钮组成；点击 `-` / `+` 按 `100ms` 步长在 `0 ~ 10000 ms` 范围内调节。当 Auto Switch 未开启时整个步进框进入禁用状态；开启时在 `0 ms` 下限禁用 `-` 按钮，在 `10000 ms` 上限禁用 `+` 按钮。

3. **数据同步与生效规则**：
   - 3 个控件与 `Settings -> Play` 中的对应设置项实时双向同步并立即持久化，生效时机与在设置界面中修改完全一致。
   - 操作这 3 个控件时不弹出屏幕中央的 Toast / Playback Feedback 提示。

4. **播放器 UI 归属与 Tooltip 提示**：
   - 整块圆角矩形底托区域属于播放器 UI（Player UI），随顶栏和底栏同步显隐；鼠标停留在圆角矩形区域内任意位置（含按钮、只读时长文字、禁用控件及内部间隙）时，不触发 3 秒无操作自动隐藏鼠标指针和播放器 UI；点击圆角矩形区域内任意位置不穿透触发视频画面的播放/暂停，右侧之外的视频画面点击不受影响。
   - 各控件（含正常态与禁用态）支持悬停 `1秒` 后的 Tooltip 提示。

# 验收标准

1. 从 Search 或 Excerpt 进入台词队列播放时，进度条左上方出现与下方播放按钮左对齐的圆角矩形控制栏；从 Library 或 Recent Videos 进入播放时不出现。
2. 点击 `Auto Pause`、`Auto Switch` 与 `- / +` 步进按钮时，状态与 `Settings -> Play` 实时双向同步，生效规则与设置界面修改一致，且屏幕中央不弹出 Toast 提示。
3. 关闭 `Auto Pause` 时，`Auto Switch` 与 Gap 步进框同步变灰禁用；仅关闭 `Auto Switch` 时，Gap 步进框变灰禁用；开启 `Auto Switch` 时，点击 `- / +` 以 `100ms` 步长在 `0 ~ 10000 ms` 间增减，位数变化或切换台词时界面与按钮位置无抖动，且数值区域不可输入文字。
4. 鼠标停留在圆角矩形控制栏内任意位置满 3 秒，鼠标指针与播放器 UI 保持显示不隐藏；点击底托内部空白或只读区域不触发视频暂停/播放；鼠标悬停在进度条最左侧时，时间胶囊正常浮于该控制栏上方；悬停各按钮满 1 秒正常显示对应 Tooltip。