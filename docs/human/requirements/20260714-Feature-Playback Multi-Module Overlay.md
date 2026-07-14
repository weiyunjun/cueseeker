# 版本
main

# 需求描述
1. 视频播放时按下Enter键弹出的字幕焦点窗口，升级为综合菜单界面。
2. 在界面左侧新增边栏，从上到下分别是：Current，Playlist（如果有），Search，Recent，Library，Shiori。边栏保留图标和文字，Current用时钟图标，Playlist用列表图标。选中后使用焦点色。边栏不可以收起，视觉上更加一体化。可以通过Tab键可以切换下一个标签页，也可以鼠标点击标签页切换。
3. Current的内容维持现状，交互改变，下面会说。
4. Playlist展示播放列表的字幕内容，如果开启Show Cue Group，那么也需要展示出来。除此之外，还要在字幕左侧显示序列号，该序列号为播放列表内部的序号。
5. Search在顶部显示一个搜索框（没有特别的选中效果了，输入内容后出现的删除按钮还保留），逻辑类似spotlight或raycast。下面显示内容，默认选中第一个结果，但是可以一直输入在搜索框输入。和Current类似，搜索结果只需要显示字幕内容就行了。这里如果Show Cue Group开启，那么Cue Group也要在这里展示出来。
6. 视频内的Search和工作台的Search，交互改动，不再按下Enter键才搜索，而是即时输入搜索。这里注意要增加100ms的防抖设置。这里存在一个核心交互冲突，就是不应该按下回车后才开始搜索。因此，如果要做，那么需要把播放器外的搜索逻辑也改了，改成只要输入内容后就开始搜索。
7. Recent，这个版本先基本照搬视频界面外的布局吧。默认选中第一个。
8. Library，这个版本先基本照搬视频界面外的布局吧，一级界面和二级界面都是默认选中第一个结果。
9. Shiori界面，只需要展示字幕内容（不需要包含其它UI了），如果开启Show Cue Group，那么也需要展示出来。
10. 边栏，这里只有2种颜色，参考现在字幕聚焦界面的选中色和非选中色就可以了。另外边栏不可以收起，视觉上更加一体化。边栏之间通过Tab键可以切换，也可以鼠标点击切换。
11. Current，Playlist，Shiori共用一套快捷键逻辑：S键收藏，C键复制内容，Enter键播放。Search界面由于优先输入，因此只响应Enter键。后续我会想办法处理这里。
12. 生命周期：综合菜单界面每次打开时创建一个独立的临时会话。Current、Playlist、Search、Recent、Library、Shiori 之间的切换属于会话内部，不触发销毁。通过 Escape、Enter 播放、关闭 Playback Page 或其他方式退出综合菜单时，立即销毁本次会话；清除当前模块、搜索词、搜索结果、选择位置、滚动位置及临时加载数据，并取消未完成的异步任务。再次打开时从 Current 和各模块默认状态重新创建。
13. 抽取并复用 Current 现有虚拟 Reel 机制。Playlist、Search、Shiori 共用同一套可见区加载、动态高度测量、Placement、滚动与回收逻辑。三者只替换数据源、Item Identity、Playback Cue Result 渲染和高度计算。禁止分别实现全量列表或三套独立虚拟化。Search 结果更新时重置或协调虚拟窗口；Session 销毁时释放缓存和未完成任务。
14. UI改动见# UI文档改动1，# UI文档改动2。

# UI文档改动1

## 1. Subtitle Focus 颜色 Token

修改前

```md
#### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#242426`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `rgba(255,255,255,0.94)`; Dark `rgba(255,255,255,0.94)`
- `--color-subtitle-focus-cue-unselected`: Light `rgba(255,255,255,0.34)`; Dark `rgba(255,255,255,0.34)`
```

修改后

```md
#### Subtitle Focus

- `--color-subtitle-focus-overlay-bg`: Light `#242426`; Dark `#242426`
- `--color-subtitle-focus-cue-selected`: Light `rgba(255,255,255,0.94)`; Dark `rgba(255,255,255,0.94)`
- `--color-subtitle-focus-cue-group-selected`: Light `rgba(255,255,255,0.62)`; Dark `rgba(255,255,255,0.62)`
- `--color-subtitle-focus-cue-unselected`: Light `rgba(255,255,255,0.34)`; Dark `rgba(255,255,255,0.34)`
```

## 2. 字幕 Typography Token

修改前

```md
- `--font-size-subtitle-focus-cue`: `40px`
- `--line-height-subtitle-focus-cue`: `52px`
- `--font-weight-subtitle-focus-cue`: `600`
```

修改后

```md
- `--font-size-subtitle-focus-cue`: `40px`
- `--line-height-subtitle-focus-cue`: `52px`
- `--font-weight-subtitle-focus-cue`: `600`
- `--font-size-subtitle-focus-cue-group`: `28px`
- `--line-height-subtitle-focus-cue-group`: `38px`
- `--font-weight-subtitle-focus-cue-group`: `500`
```

## 3. Size 与 Spacing Token

修改前

```md
- `--width-subtitle-focus-content-max`: `960px`
```

修改后

```md
- `--width-subtitle-focus-content-max`: `960px`
- `--width-playback-playlist-sequence`: `48px`
```

修改前

```md
- `--spacing-8`: `32px`
- `--gap-subtitle-focus-cue`: `8px`
- `--gap-app-topbar-title-after-toggle`: `12px`
```

修改后

```md
- `--spacing-8`: `32px`
- `--gap-subtitle-focus-cue`: `8px`
- `--gap-subtitle-focus-internal-line`: `5px`
- `--gap-app-topbar-title-after-toggle`: `12px`
```

其中：

- `--gap-subtitle-focus-internal-line` 控制同一结果内部任意两个相邻 Visual Line 的 typographic 间距。
- `--gap-subtitle-focus-cue` 继续控制两个独立结果容器之间的额外间距。
- Cue Group 内部不再使用此前讨论的 16px Cue Item Gap。

## 4. Icon Assets

修改前

```md
#### System Symbols

- Search: `magnifyingglass`
- Inline Clear: `xmark`, bold
- Filter: existing filter symbol
- Select Indicator: `chevrons-up-down`
- Sort Unsorted: `chevrons-up-down`
- Sort Ascending: `arrow-up`
- Sort Descending: `arrow-down`
- Inline Add: `plus`, medium
- Row Action: `ellipsis`
- Play: `play.fill`
- Copy: `copy`
- Context: `doc.text`
- Folder: `folder`
- Hide Column: `eye-off`
- Remove Shiori: `bookmark.slash`; fallback `bookmark`
- Back: `chevron.left`
- Settings: `gearshape`
- App Sidebar Toggle: macOS native sidebar toggle symbol
```

修改后

```md
#### System Symbols

- Current: `clock`
- Playlist: `list.bullet`
- Search: `magnifyingglass`
- Inline Clear: `xmark`, bold
- Filter: existing filter symbol
- Select Indicator: `chevrons-up-down`
- Sort Unsorted: `chevrons-up-down`
- Sort Ascending: `arrow-up`
- Sort Descending: `arrow-down`
- Inline Add: `plus`, medium
- Row Action: `ellipsis`
- Play: `play.fill`
- Copy: `copy`
- Context: `doc.text`
- Folder: `folder`
- Hide Column: `eye-off`
- Remove Shiori: `bookmark.slash`; fallback `bookmark`
- Back: `chevron.left`
- Settings: `gearshape`
- App Sidebar Toggle: macOS native sidebar toggle symbol
```

## 5. Focus 规则与 Playback Search Box

修改前

```md
- Search Box 和 Value Input Field 通过点击或键盘获得焦点时都显示 Focused 状态。
- Caret 只在可编辑输入区域获得焦点时出现。
```

修改后

```md
- Search Box 和 Value Input Field 通过点击或键盘获得焦点时都显示 Focused 状态。
- Playback Search Box 获得输入焦点时不显示额外 Focus Ring、边框色或背景变化，只显示 Caret。
- Caret 只在可编辑输入区域获得焦点时出现。
```

在 `#### Search Box` 后新增：

修改前

```md
不存在该 Block。
```

修改后

```md
#### Playback Search Box

- 用途：在 Playback Multi-Module Overlay 的 Search 中输入查询词。
- 复用 Search Box 的高度、圆角、水平内边距、文字、Placeholder、Search 图标和 Inline Clear Button。
- 使用固定 Dark Appearance。
- 状态：Empty、Typing、Filled、Clear Button Hover。
- Empty、Typing 和 Filled 的容器外观保持一致。
- 获得输入焦点时不增加 Focus Ring、焦点边框或焦点背景。
- 获得输入焦点时显示 Caret。
- 有内容时显示 Inline Clear Button。
- 点击 Inline Clear Button 清除查询词并更新 Search 结果。
- 输入区支持原生文字选择、`Cmd+A`、`Cmd+C`。
```

## 6. Playback 边栏 Component

在 `#### App Sidebar Settings Item` 后新增：

修改前

```md
不存在该 Block。
```

修改后

```md
#### Playback Module Sidebar Item

- 用途：在 Playback Multi-Module Overlay 的 Current、Playlist、Search、Recent、Library 和 Shiori 之间导航。
- 尺寸复用 `--height-app-sidebar-item`、`--padding-app-sidebar-item-x`、`--size-app-sidebar-item-icon` 和 `--spacing-3`。
- 文字使用 `--font-family-base` 和 `--font-size-app-sidebar-item`。
- Selected 的文字和图标使用 `--color-subtitle-focus-cue-selected`。
- Unselected 的文字和图标使用 `--color-subtitle-focus-cue-unselected`。
- 背景始终透明。
- 不显示选中背景、边框、Focus Ring 或其他颜色。
- 状态仅包括 Unselected 和 Selected。
- 同一时刻只有当前模块处于 Selected。
- 点击 Unselected Item 切换到对应模块。
- 点击当前 Selected Item 不重复导航。
- Playlist 不存在时不显示对应 Item，不显示 Disabled 状态。
```

## 7. Subtitle Focus Cue 与 Playback Cue Result

修改前

```md
### 3.9 Subtitle Focus

#### Subtitle Focus Cue

- 用途：显示一个完整 Cue，并表达当前键盘动作目标。
- Token：`--padding-subtitle-focus-cue-y`、`--font-family-base`、`--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue`、`--font-weight-subtitle-focus-cue`。
- Selected 使用 `--color-subtitle-focus-cue-selected`。
- Unselected 使用 `--color-subtitle-focus-cue-unselected`。
- 状态仅包括 Unselected 和 Selected。
- 保留源行序和源换行，并按可用宽度自动换行。
- Natural Height：

  `Visual Line Count × --line-height-subtitle-focus-cue + 2 × --padding-subtitle-focus-cue-y`

- Resolved Height 不超过 Cue Reel Viewport Height。
- Oversized Cue 从第一视觉行开始显示，只裁掉底部超出内容。
- 不显示省略号。
- 完整 Cue 原文继续作为 S、C 和 Space 的动作值。
- Cue 本身没有 Hover 或点击动作。
- 点击不得改变选择，也不得穿透到底层 Video。
- Wheel Event 交给所属 Cue Reel。
```

修改后

```md
### 3.9 Playback Multi-Module Overlay

#### Subtitle Focus Cue

- 用途：在 Current 中显示一个完整 Cue，并表达当前键盘动作目标。
- Token：`--padding-subtitle-focus-cue-y`、`--font-family-base`、`--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue`、`--font-weight-subtitle-focus-cue`。
- Selected 使用 `--color-subtitle-focus-cue-selected`。
- Unselected 使用 `--color-subtitle-focus-cue-unselected`。
- 状态仅包括 Unselected 和 Selected。
- 保留源行序和源换行，并按可用宽度自动换行。
- 字形的 typographic bounds 在固定 Visual Line Slot 中垂直居中。
- 同一 Cue 内任意两个相邻 Visual Line 的 typographic 间距使用 `--gap-subtitle-focus-internal-line`。
- Natural Height：

  `Visual Line Count × --line-height-subtitle-focus-cue + 2 × --padding-subtitle-focus-cue-y`

- Resolved Height 不超过 Cue Reel Viewport Height。
- Oversized Cue 从第一视觉行开始显示，只裁掉底部超出内容。
- 不显示省略号。
- 完整 Cue 原文继续作为 S、C 和 Enter 的动作值。
- Cue 本身没有 Hover 或点击动作。
- 点击不得改变选择，也不得穿透到底层 Video。
- Wheel Event 交给所属 Cue Reel。

#### Playback Cue Result

- 用途：在 Playlist、Search 和 Shiori 中显示一个 Primary Cue，以及可选的 Cue Group。
- Result 使用 `--padding-subtitle-focus-cue-y`。
- Primary Cue 使用 `--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue` 和 `--font-weight-subtitle-focus-cue`。
- Cue Group 使用 `--font-size-subtitle-focus-cue-group`、`--line-height-subtitle-focus-cue-group` 和 `--font-weight-subtitle-focus-cue-group`。
- Show Cue Group 为 On 时，在 Primary Cue 上方显示全部 Additional Cues。
- Show Cue Group 为 Off 时，只显示 Primary Cue。
- Primary Cue Identity 不因 Show Cue Group 改变。
- Selected：
  - Primary Cue 使用 `--color-subtitle-focus-cue-selected`
  - Cue Group 使用 `--color-subtitle-focus-cue-group-selected`
- Unselected：
  - Primary Cue 和 Cue Group 均使用 `--color-subtitle-focus-cue-unselected`
- 状态仅包括 Unselected 和 Selected。
- 所有 Cue 保留源行序和源换行，并按可用宽度自动换行。
- 每个 Visual Line 的字形 typographic bounds 在对应固定 Line Slot 中垂直居中。
- 同一 Result 内任意两个相邻 Visual Line 的 typographic 间距始终使用 `--gap-subtitle-focus-internal-line`。
- 上述间距同样适用于：
  - 同一个 Cue 的源换行
  - 同一个 Cue 的自动换行
  - 两个 Additional Cue 的交界
  - Additional Cue 与 Primary Cue 的交界
- Cue 边界不增加额外 Padding、Paragraph Spacing 或 Cue Item Gap。
- Result Natural Height：

  `Σ(Primary Visual Line Slot Heights) + Σ(Cue Group Visual Line Slot Heights) + 2 × --padding-subtitle-focus-cue-y`

- 两个独立 Result 之间使用 `--gap-subtitle-focus-cue`。
- Playlist 可以显示 Sequence Number：
  - 位于 Result 左侧
  - 宽度使用 `--width-playback-playlist-sequence`
  - 使用 `--font-size-body`
  - 使用 `--color-subtitle-focus-cue-unselected`
  - 右对齐
  - 与 Primary Cue 第一视觉行对齐
  - 数值表示 Playlist 内部序号
- 所有默认动作继续以 Primary Cue 为目标。
- S 只保存 Primary Cue。
- C 只复制 Primary Cue，不复制完整 Cue Group。
- Enter 从 Primary Cue Start Time 播放。
```

## 8. Workbench Search 改为即时搜索

修改前

```md
- 输入 Query 只更新当前输入内容。
- 提交后更新结果。
- Filter Trigger 负责打开、关闭和清除筛选。
```

修改后

```md
- 输入 Query 后，在最后一次输入变化的 `100ms` 后自动更新结果。
- Query 后续发生变化时，以最新输入内容更新结果。
- Return 不用于提交 Search。
- Filter Trigger 负责打开、关闭和清除筛选。
```

## 9. Show Cue Group 适用范围

修改前

```md
- Show Cue Group：
  - 设置位置：Settings / Search，紧接 Search Scope
  - Control：macOS native switch
  - Label：`Show Cue Group`
  - Default：Off
  - 跨 App 启动保留
  - 适用于 Search、Shiori 和 Context
  - Off：只显示 Primary Cue
  - On：在 Primary Cue 上方显示全部 Additional Cues
  - Primary Cue Identity 不变
  - 所有默认动作继续以 Primary Cue 为目标
  - 所有显示的 Cue 共用一个 Hover 和点击区域
  - Primary Cue 与 Extra Cues 只通过字体和颜色区分
```

修改后

```md
- Show Cue Group：
  - 设置位置：Settings / Search，紧接 Search Scope
  - Control：macOS native switch
  - Label：`Show Cue Group`
  - Default：Off
  - 跨 App 启动保留
  - 适用于 Workbench Search、Workbench Shiori 和 Context
  - 同一设置同时适用于 Playback Multi-Module Overlay 的 Playlist、Search 和 Shiori
  - Off：只显示 Primary Cue
  - On：在 Primary Cue 上方显示全部 Additional Cues
  - Primary Cue Identity 不变
  - 所有默认动作继续以 Primary Cue 为目标
  - Workbench Table 中所有显示的 Cue 共用一个 Hover 和点击区域
  - Workbench Table 中 Primary Cue 与 Extra Cues 只通过字体和颜色区分
  - Playback Multi-Module Overlay 中的显示规则使用 Playback Cue Result
```

## 10. Playback Overlay Layout

建议用下面的新 Block **完整替换**现有 `Playback Subtitle Focus Overlay Layout`。

修改前

```md
#### Playback Subtitle Focus Overlay Layout

- 覆盖完整 Playback Stage。
- 不是独立原生窗口。
- 位于 Video 和 Playback Chrome 之上。
- 位于现有 Playback Feedback Overlay 之下。
- 背景使用 `--color-subtitle-focus-overlay-bg`。
- Light 和 Dark Appearance 均使用固定 Dark Appearance。
- 内容内边距使用 `--spacing-8`。
- Overlay 显示时隐藏 Player Topbar、Bottom Chrome 和 Progress Bar。
- Playback Feedback Overlay 继续显示在最上层且不参与 Hit Testing。

- Subtitle Focus Cue Reel：
  - 在 Overlay 内居中
  - 最大宽度使用 `--width-subtitle-focus-content-max`
  - 纵向排列 Subtitle Focus Cue
  - Cue Gap 使用 `--gap-subtitle-focus-cue`
  - 允许顶部和底部出现部分可见的相邻 Cue
  - 不显示卡片、边框、背景或可见 Focus Marker

- Focus Anchor：
  - 是不可见的 Screen-space Anchor
  - 固定在 Cue Reel Viewport 垂直中心
  - Fit Cue 的完整中心与 Focus Anchor 对齐
  - Oversized Cue 的顶边与 Viewport 顶边对齐
  - 第一和最后一个 Fit Cue 也可以使用相同 Anchor
  - 窗口宽度变化后保留当前 Cue，并恢复对应 Placement

- Cue Geometry：
  - Visual Line Count 同时计算源换行和自动换行
  - Natural Height：

    `52 × Visual Line Count + 24px`

  - Resolved Height：

    `min(Natural Height, Cue Reel Viewport Height)`

  - 一行 Cue Natural Height：`76px`
  - 两行 Cue Natural Height：`128px`
  - 三行 Cue Natural Height：`180px`
  - Fit Cue 显示全部内容
  - Oversized Cue 从第一视觉行开始，只裁剪底部超出内容
  - Oversized Cue 不保留内部阅读 Offset

- Subtitle Focus Scrollbar：
  - 位于 Overlay Trailing Edge
  - 使用纵向 Table Scrollbar
  - 存在 Cue 时持续可见
  - 完整 Cue 集合可用前可以显示为不可交互状态
  - Position 映射到 Fractional Cue Ordinal
  - 长 Cue 和短 Cue 占用相同的 Ordinal 比例
  - Drag 时在相邻 Cue Placement 之间连续预览
  - Release 时选择最近的稳定 Cue
  - Thumb 不短于 `--scrollbar-min-thumb-length`

- 打开：
  - Playback Page 活跃时按 Enter
  - 立即暂停 Playback
  - 初始 Cue 准备期间保留暂停的视频画面
  - 不显示 Loading Spinner 或 Progress Bar
  - 初始 Cue 准备完成后显示 Overlay

- Default Cue：
  - Timestamp 位于 Cue Group 内时，选择该组稳定显示顺序中物理位置最靠下的 Cue
  - Timestamp 不位于 Cue 内时，选择最近的 Previous Cue
  - 没有 Previous Cue 时选择第一个 Cue

- Cue Navigation：
  - Up 选择 Previous Cue
  - Down 选择 Next Cue
  - 到达边界时无动作
  - Discrete Wheel 在允许方向上至少移动一个 Cue
  - Precise Scroll 和 Momentum 在相邻 Placement 之间连续移动
  - Scroll 结束后 Fit Cue Center 回到 Focus Anchor
  - Scroll 结束后 Oversized Cue 回到 Top Placement
  - Wheel、Trackpad 和 Scrollbar Navigation 不执行 Seek

- Cue Pointer：
  - Cue 不显示 Hover
  - Cue 不响应左键动作
  - 点击不改变 Selected Cue
  - 点击不打开 Menu
  - 点击不穿透到底层 Video
  - Wheel 和 Scrollbar 仍可使用
  - Cursor 使用 `default`

- Keyboard Actions：
  - 所有动作以已经 Settled 的 Selected Cue 为目标
  - Cue 正在移动时接受的动作，在当前目标 Settled 后执行一次

- `S`：
  - 保存 Selected Cue
  - 已保存时不删除、不重复创建
  - 新保存显示 `Shiori Saved`
  - 已存在显示 `Shiori Already Saved`
  - Overlay 保持显示
  - Playback 保持暂停
  - Cue 位置不变

- `C`：
  - 复制 Selected Cue 的完整多行文字
  - 保留源行序和换行
  - 显示 `Subtitle Copied`
  - Overlay 保持显示
  - Playback 保持暂停
  - Cue 位置不变

- `Space`：
  - Seek 至 Selected Cue Start Time
  - 关闭 Overlay
  - 从该位置连续播放
  - 显示 `Play`

- `Enter`：
  - 被消费但无动作
  - 不打开 Menu
  - 不关闭 Overlay
  - 不恢复播放
  - 不改变 Selected Cue

- Escape：
  - 关闭 Overlay
  - 恢复打开前的 Playback State
  - 不执行隐式 Seek

- Motion：
  - Duration 使用 `--duration-subtitle-focus-scroll`
  - Easing 使用 `--easing-subtitle-focus-scroll`
  - 动画距离由当前 Cue 和目标 Cue 的 Resolved Height 决定
  - Reduce Motion 下立即到达最终 Placement
```

修改后

```md
#### Playback Multi-Module Overlay Layout

- 覆盖完整 Playback Stage。
- 不是独立原生窗口。
- 位于 Video 和 Playback Chrome 之上。
- 位于现有 Playback Feedback Overlay 之下。
- 背景使用 `--color-subtitle-focus-overlay-bg`。
- Light 和 Dark Appearance 均使用固定 Dark Appearance。
- Overlay 显示时隐藏 Player Topbar、Bottom Chrome 和 Progress Bar。
- Playback Feedback Overlay 继续显示在最上层且不参与 Hit Testing。
- Overlay 显示期间 Playback 保持暂停，直到执行播放动作或退出 Overlay。

- 基本结构：
  1. Playback Module Sidebar
  2. Module Content Region

- Playback Module Sidebar：
  - 固定在 Overlay 左侧
  - 宽度使用 `--width-app-sidebar`
  - 高度占满 Overlay
  - 背景使用 `--color-subtitle-focus-overlay-bg`
  - 与 Module Content Region 之间不显示独立背景、边框或 Divider
  - 水平内边距使用 `--padding-app-sidebar-x`
  - 垂直内边距使用 `--padding-app-sidebar-y`
  - Item 间距使用 `--spacing-1`
  - 使用 Playback Module Sidebar Item
  - 从上到下依次包括：
    1. Current / `clock`
    2. Playlist / `list.bullet`，仅存在 Playlist 时显示
    3. Search / `magnifyingglass`
    4. Recent / 当前项目资源
    5. Library / 当前项目资源
    6. Shiori / 当前项目资源
  - Sidebar 始终显示，不允许折叠
  - 当前模块使用 Selected 状态
  - 点击 Item 切换对应模块
  - Tab 切换到下一个当前可用模块
  - Shiori 后再次按 Tab 返回 Current
  - Playlist 不存在时 Tab 顺序跳过 Playlist
  - 不提供其他模块切换按钮或模块切换快捷键

- Module Content Region：
  - 占据 Sidebar 以外的剩余区域
  - 内容内边距使用 `--spacing-8`
  - Current、Playlist、Search、Recent、Library 和 Shiori 共享同一 Content Region
  - 模块切换只替换 Content Region 内容
  - 模块切换不关闭 Overlay

- 打开：
  - Playback Page 活跃时按 Enter
  - 每次打开创建一个新的临时 Overlay Session
  - 立即暂停 Playback
  - 默认模块为 Current
  - 初始 Cue 准备期间保留暂停的视频画面
  - 不显示 Loading Spinner 或 Progress Bar
  - 初始 Cue 准备完成后显示 Overlay

- Session：
  - Current、Playlist、Search、Recent、Library 和 Shiori 的切换属于同一次 Overlay Session
  - 模块切换期间保留本次 Session 内的模块状态
  - Escape、播放动作、关闭 Playback Page 或其他关闭 Overlay 的路径结束当前 Session
  - Session 结束后不保留当前模块、搜索词、搜索结果、选择位置、滚动位置或临时显示内容
  - 再次打开时重新进入 Current，并按照各模块默认状态重新初始化
  - Session 销毁不删除 Shiori、Recent、Library、Playlist、Playback History 或持久设置
  - Session 生命周期以 Overlay 的产品级打开和关闭为边界，不以单个 Module View 的出现或消失为边界

- Current：
  - 内容维持现有 Subtitle Focus Cue Reel
  - Cue Reel 在 Module Content Region 内居中
  - 最大宽度使用 `--width-subtitle-focus-content-max`
  - 纵向排列 Subtitle Focus Cue
  - Cue Gap 使用 `--gap-subtitle-focus-cue`
  - 允许顶部和底部出现部分可见的相邻 Cue
  - 不显示卡片、边框、背景或可见 Focus Marker

- Current / Focus Anchor：
  - 是不可见的 Screen-space Anchor
  - 固定在 Cue Reel Viewport 垂直中心
  - Fit Cue 的完整中心与 Focus Anchor 对齐
  - Oversized Cue 的顶边与 Viewport 顶边对齐
  - 第一和最后一个 Fit Cue 也可以使用相同 Anchor
  - 窗口宽度变化后保留当前 Cue，并恢复对应 Placement

- Current / Cue Geometry：
  - Visual Line Count 同时计算源换行和自动换行
  - 同一 Cue 内任意两个相邻 Visual Line 的 typographic 间距使用 `--gap-subtitle-focus-internal-line`
  - 字形在固定 Visual Line Slot 中垂直居中
  - Natural Height：

    `52 × Visual Line Count + 24px`

  - Resolved Height：

    `min(Natural Height, Cue Reel Viewport Height)`

  - 一行 Cue Natural Height：`76px`
  - 两行 Cue Natural Height：`128px`
  - 三行 Cue Natural Height：`180px`
  - Fit Cue 显示全部内容
  - Oversized Cue 从第一视觉行开始，只裁剪底部超出内容
  - Oversized Cue 不保留内部阅读 Offset

- Current / Scrollbar：
  - 位于 Module Content Region Trailing Edge
  - 使用纵向 Table Scrollbar
  - 存在 Cue 时持续可见
  - 完整 Cue 集合可用前可以显示为不可交互状态
  - Position 映射到 Fractional Cue Ordinal
  - 长 Cue 和短 Cue 占用相同的 Ordinal 比例
  - Drag 时在相邻 Cue Placement 之间连续预览
  - Release 时选择最近的稳定 Cue
  - Thumb 不短于 `--scrollbar-min-thumb-length`

- Current / Default Cue：
  - Timestamp 位于 Cue Group 内时，选择该组稳定显示顺序中物理位置最靠下的 Cue
  - Timestamp 不位于 Cue 内时，选择最近的 Previous Cue
  - 没有 Previous Cue 时选择第一个 Cue

- Current / Cue Navigation：
  - Up 选择 Previous Cue
  - Down 选择 Next Cue
  - 到达边界时无动作
  - Discrete Wheel 在允许方向上至少移动一个 Cue
  - Precise Scroll 和 Momentum 在相邻 Placement 之间连续移动
  - Scroll 结束后 Fit Cue Center 回到 Focus Anchor
  - Scroll 结束后 Oversized Cue 回到 Top Placement
  - Wheel、Trackpad 和 Scrollbar Navigation 不执行 Seek

- Current / Cue Pointer：
  - Cue 不显示 Hover
  - Cue 不响应左键动作
  - 点击不改变 Selected Cue
  - 点击不穿透到底层 Video
  - Wheel 和 Scrollbar 仍可使用
  - Cursor 使用 `default`

- Playlist：
  - 使用纵向 Playback Cue Result 列表
  - 按 Playlist 内部顺序显示
  - 每个 Result 左侧显示 Playlist Sequence Number
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue

- Search：
  - 顶部显示 Playback Search Box
  - Search Box 下方显示纵向 Playback Cue Result 列表
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range 或其他 Metadata
  - 打开 Search 时自动聚焦 Search Box
  - 输入 Query 后，在最后一次输入变化的 `100ms` 后自动更新结果
  - Search 不要求 Return 提交
  - Query 为空时不显示 Cue Result
  - 每次结果更新后默认选择第一条结果
  - 结果选择变化不移除 Search Box 的输入焦点
  - 有输入内容时显示 Inline Clear Button
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - Search 输入优先于字母快捷键
  - S 和 C 作为普通查询输入
  - Search 的模块级字幕动作只响应 Enter
  - Enter 从 Selected Result 的 Primary Cue Start Time 播放

- Recent：
  - 复用 Recent Watching Card Layout
  - 不显示 Workbench App Sidebar 或 App Topbar
  - 进入 Recent 时默认选择第一项
  - 播放动作沿用 Recent Watching Card Layout

- Library：
  - Library 一级界面复用 Library Folder Card Layout
  - Library 二级界面复用 Library Episode Grid and Card Layout
  - 不显示 Workbench App Sidebar 或 App Topbar
  - 进入 Library 一级界面时默认选择第一项
  - 进入 Library 二级界面时默认选择第一项
  - Library Folder Detail 的 Back Button 只返回 Library 一级界面，不切换 Overlay Module
  - 播放动作沿用对应 Library Layout

- Shiori：
  - 使用纵向 Playback Cue Result 列表
  - 只显示字幕内容
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue

- Current、Playlist 和 Shiori Keyboard Actions：
  - 所有动作以已经 Settled 的 Selected Primary Cue 为目标
  - Cue 正在移动时接受的动作，在当前目标 Settled 后执行一次

- `S`：
  - 保存 Selected Primary Cue
  - 已保存时不删除、不重复创建
  - 新保存显示 `Shiori Saved`
  - 已存在显示 `Shiori Already Saved`
  - Overlay 保持显示
  - Playback 保持暂停
  - 当前选择和位置不变

- `C`：
  - 复制 Selected Primary Cue 的完整多行文字
  - 不复制完整 Cue Group
  - 保留源行序和换行
  - 显示 `Subtitle Copied`
  - Overlay 保持显示
  - Playback 保持暂停
  - 当前选择和位置不变

- `Enter`：
  - Seek 至 Selected Primary Cue Start Time
  - 关闭 Overlay
  - 销毁当前 Overlay Session
  - 从该位置连续播放
  - 显示 `Play`

- Escape：
  - 关闭 Overlay
  - 销毁当前 Overlay Session
  - 恢复打开前的 Playback State
  - 不执行隐式 Seek

- Motion：
  - Current Cue Reel Duration 使用 `--duration-subtitle-focus-scroll`
  - Current Cue Reel Easing 使用 `--easing-subtitle-focus-scroll`
  - 动画距离由当前 Cue 和目标 Cue 的 Resolved Height 决定
  - Reduce Motion 下立即到达最终 Placement
```

# UI文档改动2

## 1. 修正严格 5px 行距算法

### Subtitle Focus Cue

修改前

```md
- Token：`--padding-subtitle-focus-cue-y`、`--font-family-base`、`--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue`、`--font-weight-subtitle-focus-cue`。
- Selected 使用 `--color-subtitle-focus-cue-selected`。
- Unselected 使用 `--color-subtitle-focus-cue-unselected`。
- 状态仅包括 Unselected 和 Selected。
- 保留源行序和源换行，并按可用宽度自动换行。
- 字形的 typographic bounds 在固定 Visual Line Slot 中垂直居中。
- 同一 Cue 内任意两个相邻 Visual Line 的 typographic 间距使用 `--gap-subtitle-focus-internal-line`。
- Natural Height：

  `Visual Line Count × --line-height-subtitle-focus-cue + 2 × --padding-subtitle-focus-cue-y`
```

修改后

```md
- Token：`--padding-subtitle-focus-cue-y`、`--font-family-base`、`--font-size-subtitle-focus-cue`、`--line-height-subtitle-focus-cue`、`--font-weight-subtitle-focus-cue`、`--gap-subtitle-focus-internal-line`。
- Selected 使用 `--color-subtitle-focus-cue-selected`。
- Unselected 使用 `--color-subtitle-focus-cue-unselected`。
- 状态仅包括 Unselected 和 Selected。
- 保留源行序和源换行，并按可用宽度自动换行。
- 将源换行和自动换行展开为一个按显示顺序排列的 Visual Line Stack。
- 每个 Visual Line 的 typographic bounds 使用实际解析后的 Font Runs 的 Ascender 和 Descender 计算，不使用随具体字形变化的 Ink Bounds。
- 从第二个 Visual Line 开始，按下式排列：

  `Next Visual Line Top = Previous Visual Line Bottom + --gap-subtitle-focus-internal-line`

- 不将每个 Visual Line 分别居中到固定 Line Slot。
- Resolved Content Height：

  `max(Visual Line Count × --line-height-subtitle-focus-cue, Visual Line Stack Height)`

- Visual Line Stack 在 Resolved Content Region 内整体垂直居中。
- Natural Height：

  `Resolved Content Height + 2 × --padding-subtitle-focus-cue-y`
```

### Playback Cue Result

修改前

```md
- 所有 Cue 保留源行序和源换行，并按可用宽度自动换行。
- 每个 Visual Line 的字形 typographic bounds 在对应固定 Line Slot 中垂直居中。
- 同一 Result 内任意两个相邻 Visual Line 的 typographic 间距始终使用 `--gap-subtitle-focus-internal-line`。
- 上述间距同样适用于：
  - 同一个 Cue 的源换行
  - 同一个 Cue 的自动换行
  - 两个 Additional Cue 的交界
  - Additional Cue 与 Primary Cue 的交界
- Cue 边界不增加额外 Padding、Paragraph Spacing 或 Cue Item Gap。
- Result Natural Height：

  `Σ(Primary Visual Line Slot Heights) + Σ(Cue Group Visual Line Slot Heights) + 2 × --padding-subtitle-focus-cue-y`
```

修改后

```md
- 所有 Cue 保留源行序和源换行，并按可用宽度自动换行。
- 将全部 Additional Cues 和 Primary Cue 展开为一个按显示顺序排列的 Visual Line Stack。
- 每个 Visual Line 的 typographic bounds 使用实际解析后的 Font Runs 的 Ascender 和 Descender 计算，不使用随具体字形变化的 Ink Bounds。
- 从第二个 Visual Line 开始，按下式排列：

  `Next Visual Line Top = Previous Visual Line Bottom + --gap-subtitle-focus-internal-line`

- 上述间距同样适用于：
  - 同一个 Cue 的源换行
  - 同一个 Cue 的自动换行
  - 两个 Additional Cue 的交界
  - Additional Cue 与 Primary Cue 的交界
- Cue 边界不增加额外 Padding、Paragraph Spacing 或 Cue Item Gap。
- Nominal Content Height：

  `Primary Visual Line Count × --line-height-subtitle-focus-cue + Cue Group Visual Line Count × --line-height-subtitle-focus-cue-group`

- Resolved Content Height：

  `max(Nominal Content Height, Visual Line Stack Height)`

- Visual Line Stack 在 Resolved Content Region 内整体垂直居中。
- Result Natural Height：

  `Resolved Content Height + 2 × --padding-subtitle-focus-cue-y`
```

## 2. 消除 Playback Cue Result 的快捷键冲突

修改前

```md
- 所有默认动作继续以 Primary Cue 为目标。
- S 只保存 Primary Cue。
- C 只复制 Primary Cue，不复制完整 Cue Group。
- Enter 从 Primary Cue Start Time 播放。
```

修改后

```md
- Playback Cue Result 本身不绑定键盘快捷键。
- 所属 Module 提供的字幕动作均以 Primary Cue 为目标。
- 具体快捷键和播放行为由所属 Module Layout 定义。
```

这样 Search 就不会同时出现“S/C 保存复制”和“S/C 输入文字”两套规则。

## 3. 修正 Current 的 Geometry 公式

修改前

```md
- Current / Cue Geometry：
  - Visual Line Count 同时计算源换行和自动换行
  - 同一 Cue 内任意两个相邻 Visual Line 的 typographic 间距使用 `--gap-subtitle-focus-internal-line`
  - 字形在固定 Visual Line Slot 中垂直居中
  - Natural Height：

    `52 × Visual Line Count + 24px`

  - Resolved Height：

    `min(Natural Height, Cue Reel Viewport Height)`

  - 一行 Cue Natural Height：`76px`
  - 两行 Cue Natural Height：`128px`
  - 三行 Cue Natural Height：`180px`
```

修改后

```md
- Current / Cue Geometry：
  - Visual Line Count 同时计算源换行和自动换行
  - Visual Line 的测量和排列遵循 Subtitle Focus Cue
  - Nominal Content Height：

    `52 × Visual Line Count`

  - Natural Height：

    `max(Nominal Content Height, Visual Line Stack Height) + 24px`

  - Resolved Height：

    `min(Natural Height, Cue Reel Viewport Height)`

  - 当前字体度量下，一行 Cue Natural Height：`76px`
  - 当前字体度量下，两行 Cue Natural Height：`128px`
  - 当前字体度量下，三行 Cue Natural Height：`180px`
```

这能同时满足：**常规 Current 尺寸保持不变，并由算法严格保证所有内部行距相等。**

## 4. 明确 Tab 始终切换模块

修改前

```md
  - Tab 切换到下一个当前可用模块
  - Shiori 后再次按 Tab 返回 Current
  - Playlist 不存在时 Tab 顺序跳过 Playlist
  - 不提供其他模块切换按钮或模块切换快捷键
```

修改后

```md
  - Overlay 在任何 Module 和输入焦点状态下消费无修饰 Tab
  - 无修饰 Tab 只切换到下一个当前可用模块，不执行原生焦点遍历
  - Shiori 后再次按 Tab 返回 Current
  - Playlist 不存在时 Tab 顺序跳过 Playlist
  - 不提供其他模块切换按钮或模块切换快捷键
```

## 5. 补充字幕结果的选择闭环

建议在 `Current / Cue Pointer` 后新增。

修改前

```md
不存在该 Block。
```

修改后

```md
- Playback Cue Result Reel：
  - 适用于 Playlist、Search 和 Shiori
  - 使用 Playback Cue Result 作为纵向排列单元
  - Focus Anchor、Scrollbar、Up、Down、Wheel、Trackpad、Scrollbar Drag 和 Settle 语义复用 Current Cue Reel
  - Result Natural Height 代替 Current Cue Natural Height 参与 Placement 计算
  - Playlist 和 Shiori 在本次 Session 首次初始化时默认选择第一条 Result
  - Search 每次结果更新后默认选择第一条 Result
  - 到达列表边界时继续导航无动作
  - Result 不显示 Hover
  - Result 不响应左键动作
  - 点击不改变选择，也不执行播放
  - 没有 Result 时不存在 Selected Result
  - 不存在 Selected Result 时，所有字幕动作均无动作
  - 切换 Module 后再次返回时，恢复本次 Session 内的选择和滚动位置
```

### Playlist

修改前

```md
- Playlist：
  - 使用纵向 Playback Cue Result 列表
  - 按 Playlist 内部顺序显示
  - 每个 Result 左侧显示 Playlist Sequence Number
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue
```

修改后

```md
- Playlist：
  - 使用 Playback Cue Result Reel
  - 按 Playlist 内部顺序显示
  - 每个 Result 左侧显示 Playlist Sequence Number
  - 本次 Session 首次进入 Playlist 时默认选择第一条 Result
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue
```

### Search

修改前

```md
  - 每次结果更新后默认选择第一条结果
  - 结果选择变化不移除 Search Box 的输入焦点
  - 有输入内容时显示 Inline Clear Button
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - Search 输入优先于字母快捷键
  - S 和 C 作为普通查询输入
  - Search 的模块级字幕动作只响应 Enter
  - Enter 从 Selected Result 的 Primary Cue Start Time 播放
```

修改后

```md
  - 每次结果更新后默认选择第一条 Result
  - Search Box 保持输入焦点
  - Search Box 保持输入焦点时，Up 和 Down 由 Playback Cue Result Reel 响应，不用于移动 Caret
  - Result 选择变化不移除 Search Box 的输入焦点
  - 有输入内容时显示 Inline Clear Button
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - Search 输入优先于字母快捷键
  - S 和 C 作为普通查询输入
  - Search 的模块级字幕动作只响应 Enter
  - 存在已经 Settled 的 Selected Result 时，Enter 从其 Primary Cue Start Time 播放
  - 不存在 Selected Result 时，Enter 无动作
```

### Shiori

修改前

```md
- Shiori：
  - 使用纵向 Playback Cue Result 列表
  - 只显示字幕内容
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue
```

修改后

```md
- Shiori：
  - 使用 Playback Cue Result Reel
  - 只显示字幕内容
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - 本次 Session 首次进入 Shiori 时默认选择第一条 Result
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue
```

## 6. 补充 Recent 和 Library 的选择规则

建议在 `Playback Cue Result Reel` 后新增。

修改前

```md
不存在该 Block。
```

修改后

```md
- Playback Media Selection：
  - 适用于 Recent、Library 一级界面和 Library 二级界面
  - Selected Item 使用现有 Focus Ring Token，不新增颜色 Token
  - 方向键选择对应视觉方向上最近的可用 Item
  - Selected Item 始终滚动到可见区域
  - Enter 执行 Selected Item 在原 Layout 中定义的左键主操作
  - 原有鼠标 Hover、左键和右键行为保持不变
  - 没有可用 Item 时不存在 Selected Item，Enter 无动作
  - Module 切换后再次返回时，恢复本次 Session 内的层级、选择和滚动位置
```

### Recent

修改前

```md
  - 进入 Recent 时默认选择第一项
  - 播放动作沿用 Recent Watching Card Layout
```

修改后

```md
  - 本次 Session 首次进入 Recent 时默认选择第一项
  - 使用 Playback Media Selection
  - Enter 和鼠标播放动作沿用 Recent Watching Card Layout
```

### Library

修改前

```md
  - 进入 Library 一级界面时默认选择第一项
  - 进入 Library 二级界面时默认选择第一项
  - Library Folder Detail 的 Back Button 只返回 Library 一级界面，不切换 Overlay Module
  - 播放动作沿用对应 Library Layout
```

修改后

```md
  - 本次 Session 首次进入 Library 一级界面时默认选择第一项
  - 每次进入 Library 二级界面时默认选择第一项
  - 使用 Playback Media Selection
  - Library 一级界面的 Enter 进入 Selected Library Folder
  - Library 二级界面的 Enter 播放 Selected Episode
  - Library Folder Detail 的 Back Button 只返回 Library 一级界面，不切换 Overlay Module
  - 返回 Library 一级界面时恢复此前的选择和滚动位置
  - 鼠标动作沿用对应 Library Layout
```
