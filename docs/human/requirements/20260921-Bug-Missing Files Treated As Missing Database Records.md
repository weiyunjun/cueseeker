# 版本

main

# 关联设计

- `docs/human/design/Data.md`（Index流程 第 7 步；永久身份与路径分离 补充说明 7）
- `docs/human/design/UI Design System.md`（Toast Motion、Player Chrome、Player Topbar Layout、Recent Watching Card Layout、Cover Summary）
- `docs/human/design/UI Application Rules.md`（界面层级）

# 需求描述

## 1. 范围

视频或字幕文件在 App 之外被改名、移走或无法读取，而数据库没有变化。数据库记录被移除的情况不在本需求内。

## 2. 原则

1. 数据库只在 Index、Add Folder、Remove Folder 与 App 内改名时变化。数据库没有变化时，由数据库决定的一切内容都不受影响。
2. 当前视频与字幕以用户选中的数据库记录为准，不以文件是否存在、播放器是否打开成功或播放状态为准。
3. 只有需要文件内容的环节读取文件：播放器、字幕渲染、拼图预览、截图、Anki 导出。它们失败时只产生加载失败的结果，不改变当前视频与字幕，不阻止任何操作。
4. 视频与字幕各自加载，互不依赖。

## 3. 现状

1. Library 视频卡片、Recent Videos、Playback Overlay 视频 Playlist、Command Panel Recent Videos 与 Library 二级页的 Resume/Play 在进入前检查文件是否存在，文件不在时变灰或不可进入。
2. 顶栏标题在部分入口（上一个/下一个视频、自动连播、Excerpt 的上一个/下一个）改为播放时读取磁盘计算，字幕文件不在时显示字幕文件名。
3. 视频打不开时，Playback Overlay、播放/暂停、Library 的上一个/下一个与视频 Playlist、More 菜单、Repeat 不可用，上一个视频继续播放。
4. 字幕要等视频打开成功才加载；字幕报错画在字幕层，App 无法控制它的位置与消失。
5. Display Title 有两套算法：Library 按视频计算，Search 与 Excerpt 按同后缀字幕文件在磁盘上的排序计算。同一视频有多条字幕或字幕后缀不同时，两者不一致。

## 4. 要求

### 4.1 入口

1. 上述入口不检查文件是否存在，鼠标、键盘与右键菜单始终可用。视频卡片没有 Disabled 状态。
2. 文件无法加载时，由播放页按加载失败处理。

### 4.2 视频加载失败

1. 不退出播放页。
2. 当前视频即该失败的视频，标题、Playback Overlay、Playlist、上一个/下一个均以它为准。
3. 停止上一个视频，舞台黑屏，进度归零。
4. 来自数据库的内容照常可用：Playback Overlay（Current、Playlist、Collage）、上一个/下一个视频、More 菜单的音轨与字幕列表、Default Audio Track 与 Default Subtitle 的保存、Save to Excerpt List、复制。
5. 作用于播放器的操作可以执行但没有效果，也不显示对应的 Playback Feedback：播放/暂停、进度、快进快退、倍速、音量、截图、Repeat、切换音轨。
6. More 菜单切换 Subtitle 改变本次播放的字幕，Current 随之显示新字幕的内容。
7. Collage 可以打开与勾选，预览因读不到视频无法生成。

### 4.3 字幕加载失败

1. 字幕文件无法读取即为加载失败，不显示该字幕。ASS 的分段缓存不作为文件缺失时的替代。
2. 视频照常播放，不影响任何操作。

### 4.4 其它播放器错误

播放器不可用，或暂停、继续、切换音轨、停止出错时，不阻止任何操作，在报错条的视频那一行显示。

### 4.5 报错条

1. 新组件，不复用 Playback Feedback 与 Toast。
2. 锚定 App 窗口，不锚定视频画面。上边距为 `--height-app-topbar` 加 `--spacing-3`，左边距 `--spacing-6`。窗口变窄使视频出现黑边时仍在顶栏之下，可落在黑边上。全屏同此规则。
3. 宽度随内容，最大为窗口宽度减两侧 `--spacing-6`，超出时换行。
4. 视频与字幕两条报错共用一个框，视频在上，字幕在下，间距 `--spacing-2`。只有一条时框内只有一行。
5. 每行为图标 `warning` 加文字，图标与文字间距 `--spacing-2`，图标与该行第一行文字垂直居中，换行时续行不进入图标所占宽度。
6. 完整绝对路径全量显示，不截断。
7. 只有视觉，不接受输入，点击穿透，不参与层级；画在 Playback Overlay 与 Command Panel 之上；不随 Player UI 隐藏。
8. 出现与消失使用 Toast Motion。
9. 新增 Token：
   - `--color-player-error-bg`：`#B42318`（不透明）
   - `--color-player-error-content`：`#FFFFFF`
   - `--radius-player-error`：`10px`
   - `--font-size-player-error`：`13px`
   - `--line-height-player-error`：`20px`
   - `--size-player-error-icon`：`16px`
   - `--padding-player-error-x`：`12px`
   - `--padding-player-error-y`：`10px`
10. 字重：`--font-weight-control`。

### 4.6 文案

1. 视频：`Couldn’t load the video file: <绝对路径>`
2. 字幕：`Couldn’t load the subtitle file: <绝对路径>`
3. 其它播放器错误：`Playback error: <播放器给出的原因>`
4. 不出现 ASS、SRT 或渲染器等内部名称。

### 4.7 生命周期

1. 每行出现满 5 秒，或对应来源被替换，任一条件满足即消失。视频那一行的来源是当前视频；字幕那一行的来源是当前字幕，切换视频也视为替换。
2. 同一行出现新的报错时替换旧的并重新计时。
3. 计时规则同 Toast：焦点、指针与窗口是否可见都不影响计时；暂停、播放、拖动进度、开关 Playback Overlay 均不影响。
4. 两行都消失时框消失。

### 4.8 Display Title

1. Display Title 属于视频，Index 第 7 步按视频计算一次：文件夹名 − 该视频在同文件夹视频中的序号。
2. 字幕、Cue 与 Excerpt 的 Display Title 取其匹配视频的 Display Title，所有显示 Display Title 的地方使用同一个值。
3. 播放时不读取磁盘计算标题。
4. 升级后已有数据自动按本规则重算，无需手动 Index。

## 5. 保持不变

1. Playback Overlay 与 Playlist 按数据库内容显示。
2. 顶栏与底部控制条的既有布局与外观。
3. Data.md 补充说明 7：播放只在正在播放的视频被移出库时停止。

# 验收

1. 在 Finder 改名某个文件夹或视频文件：Library、Recent Videos、Playback Overlay 视频 Playlist、Command Panel Recent Videos 中的卡片正常显示、可以进入，Library 二级页的 Resume/Play 可用。
2. 进入改名后的视频：不退出播放页，舞台黑屏，报错条显示视频那一行，5 秒后消失；标题为 Display Title；Playback Overlay 的 Current 与 Playlist 可以打开且内容正确；上一个/下一个与 More 菜单可用。
3. 播放中跳到下一个被改名的视频：上一个视频停止，其余同第 2 条。
4. 只改名字幕：视频照常播放，不显示字幕，报错条只有字幕那一行，标题不变。
5. 视频与字幕都改名：同一个框内两行，视频在上。
6. 5 秒内切换视频或字幕：对应那一行立即消失。
7. 报错条宽度随文案变化，长路径在最大宽度处换行；缩小窗口至出现黑边时仍在顶栏之下。
8. 同一视频有多条字幕、或字幕后缀不同的文件夹：Search、Excerpt 与播放页顶栏的 Display Title 与 Library 一致。
9. 不新增自动化失败，不为本需求新增 E2E 能力；第 1 至 8 条人工验收。