# 版本
main

# 需求描述
1. 从产品逻辑上，Playback的Search，Recent，Library和Shiori应该被视为Workbench的几个界面的子集或精简版，大部分操作为不改变数据的操作，少部分操作为简单的非批量的改变数据的操作（例如收藏字幕）。确切地说：Playback是Workbench Feature的“能力受限宿主”，不是另一套功能实现。
2. 基于这个产品逻辑，复杂的批量操作(指表格中需要勾选checkbox处理的操作)，导出内容，添加文件夹，查看上下文，筛选搜索结果，复制表格等，还是只有Workbench界面可以处理。
3. Workbench和Playback界面，应该共享大部分前端和后端代码，而不是分别维护不同的代码。

# Playback界面允许的操作
1. Current界面：移动焦点（键盘上下键，鼠标滚轮，拖拽滚动条），从焦点字幕播放，收藏字幕，复制焦点字幕内容。
2. Playlist界面：移动焦点（键盘上下键，鼠标滚轮，拖拽滚动条），从焦点字幕播放，收藏字幕，复制焦点字幕内容。
3. Search界面：搜索相关（输入关键词，删除关键词，复制剪切粘贴等搜索框操作），移动焦点（键盘上下键，鼠标滚轮，拖拽滚动条），从焦点字幕播放。
4. Recent界面：移动焦点（键盘方向键），滚动界面（键盘方向键，鼠标滚轮，拖拽滚动条），鼠标右键菜单（不包括Context），鼠标左键点击播放。
5. Library界面：移动焦点（键盘方向键），滚动界面（键盘方向键，鼠标滚轮，拖拽滚动条），鼠标右键菜单（不包括Context），鼠标左键进入二级界面，鼠标左键点击播放视频。
6. Shiori界面：移动焦点（键盘上下键，鼠标滚轮，拖拽滚动条），从焦点字幕播放，收藏字幕（逻辑上会提示已收藏，但操作本身允许），复制焦点字幕内容。

# 细节说明
1. 在Playback界面，初始化隐藏鼠标指针。鼠标指针只有通过移动才会恢复显示（滚动滚轮不会恢复显示）。任何键盘按键也都会隐藏鼠标指针。
2. Recent界面和Library界面，默认选中第一个视频卡片。
3. Recent界面和Library界面。鼠标指针显示时，hover到某个非选中的视频卡片，也会让该视频卡片被选中。
4. 鼠标离开卡片或移到空白区域 → 不清空 Selected。
5. 右键菜单打开后，应锁定当前卡片作为操作目标。
6. 不可用卡片不允许被选中。
7. 已选卡片因数据刷新消失后，恢复默认选中，即选中第一个视频卡片。

# 状态机
1. Workbench和Playback应该共享一套状态机的规则和实现，两端都能触发状态变化，但Playback没有筛选、批量、导出、Context等事件权限。
2. Playback Search会启用临时空筛选条件。播放来自Playback Search得到的结果后会正式清空筛选条件，避免生命周期冲突。只是执行Playback Search而不播放搜索结果，不会正式清空筛选条件。Playback Shiori由于无法搜索，因此不需要清空筛选条件。

# 生命周期
1. 退出视频界面前是处于什么状态，那就退到什么界面。退出前播放搜索结果列表的内容，那就退出到搜索界面且显示对应的搜索关键词。退出前播放Shiori的结果，那么退出到Shiori界面。退出前从Recent播放某个视频，那么退出到Recent界面。退出前从Library点进播放某个视频，那么退出到该视频的Library二级界面。
2. 每次打开综合菜单界面创建Overlay Session，关闭综合菜单界面销毁Overlay Session。
3. 对于第1点，整个Playback页面期间保留Playback Return Context，关闭视频时使用。

# 约束边界
1. 之前还有旧的综合菜单界面，替换了新的实现后需要删除旧的实现。
2. 以Workbench作为单一数据源。
3. 采用最简方案、减少无意义代码。

# UI文档改动

## 1. Library Card Context Menu

修改前

```md
#### Library Card Context Menu

- 用途：为 Recent、Library Folder 和 Library Episode 卡片提供 Context Menu。
- Menu 使用 `--color-bg-popover`、`--color-border-muted`、`--radius-menu`、`--shadow-popover`、`--spacing-1`。
- Menu Item Hover 使用 `--color-bg-hover`。
- Recent 和 Library Folder 在卡片交互区域触发。
- Library Episode 只在 Cover Region 触发。
- 菜单锚定右键位置并限制在可见区域内。
- 点击菜单外关闭。
- 不显示系统 Popover Arrow。
```

修改后

```md
#### Library Card Context Menu

- 用途：为 Recent、Library Folder 和 Library Episode 卡片提供 Context Menu。
- Menu 使用 `--color-bg-popover`、`--color-border-muted`、`--radius-menu`、`--shadow-popover`、`--spacing-1`。
- Menu Item Hover 使用 `--color-bg-hover`。
- Recent 和 Library Folder 在卡片交互区域触发。
- Library Episode 只在 Cover Region 触发。
- Workbench 中的 Menu Item 由所属 Card Layout 定义。
- Playback 复用所属 Card Layout 定义的 Menu Item 和动作，但不显示 `Context` Menu Item。
- Playback 中打开 Menu 后，锁定右键所在卡片为动作目标，直到 Menu 关闭。
- 菜单锚定右键位置并限制在可见区域内。
- 点击菜单外关闭。
- 不显示系统 Popover Arrow。
```

## 2. Playback Pointer Visibility

修改前

```md
- Pointer Exit：
  - 非 Drag 状态隐藏 Preview、Thumb 和 Time Capsule

#### Playback Multi-Module Overlay Layout
```

修改后

```md
- Pointer Exit：
  - 非 Drag 状态隐藏 Preview、Thumb 和 Time Capsule

#### Playback Pointer Visibility

- Playback Page 初始化时隐藏 Pointer。
- 只有 Pointer Move 恢复 Pointer 显示。
- Wheel 不恢复 Pointer 显示。
- 任意键盘按键隐藏 Pointer。
- Pointer 隐藏时不允许 Pointer 命中目标改变 Playback Media Selection。
- Pointer 恢复显示后，各组件定义的 Hover 和 Cursor 规则继续生效。
- Pointer 显示时，内容滚动导致 Pointer 命中的卡片变化，属于有效的 Hover 目标变化。

#### Playback Multi-Module Overlay Layout
```

## 3. Feature Host 与 Playback Return Context

修改前

```md
- Overlay 显示时隐藏 Player Topbar、Bottom Chrome 和 Progress Bar。
- Playback Feedback Overlay 继续显示在最上层且不参与 Hit Testing。
- Overlay 显示期间 Playback 保持暂停，直到执行播放动作或退出 Overlay。

- 基本结构：
```

修改后

```md
- Overlay 显示时隐藏 Player Topbar、Bottom Chrome 和 Progress Bar。
- Playback Feedback Overlay 继续显示在最上层且不参与 Hit Testing。
- Overlay 显示期间 Playback 保持暂停，直到执行播放动作或退出 Overlay。

- Feature Host：
  - Playback 中的 Search、Recent、Library 和 Shiori 是对应 Workbench Feature 的能力受限宿主
  - Workbench 与 Playback 共享对应 Feature 的可见状态和操作结果
  - 任一端完成的正式 Feature 状态变化在另一端可见
  - Playback 不提供 Checkbox 批量操作、导出、添加文件夹、Context、Filter 控件或复制表格入口
  - Playback 只提供各 Module 在本 Layout 中明确列出的操作

- Playback Return Context：
  - 生命周期覆盖整个 Playback Page，并跨越同一 Playback Page 内的多次 Overlay Session
  - 只有 Search、Shiori、Recent 和 Library 四种返回目标
  - 打开 Playback Page 时，以进入 Playback 前的 Workbench Feature 初始化
  - 从 Playback Search 成功播放 Result 时更新为 Search
  - 从 Playback Shiori 成功播放 Result 时更新为 Shiori
  - 从 Playback Recent 成功播放视频时更新为 Recent
  - 从 Playback Library Folder Detail 成功播放视频时更新为对应的 Library Folder Detail
  - 后一次成功播放更新并替换前一次 Playback Return Context
  - 只切换 Module、编辑 Search Query、浏览结果或通过 Escape 关闭 Overlay，不更新 Playback Return Context
  - 关闭 Playback Page 时，根据当前 Playback Return Context 返回 Workbench
  - Playback Return Context 只决定返回目标，不保存、删除或回滚其他 Feature 状态
  - 返回 Search 时显示 Search Feature 当前 Query，而不是 Playback Return Context 创建时的 Query 快照
  - 完成返回后销毁 Playback Return Context

- 基本结构：
```

## 4. Player Close

修改前

```md
- Close 返回播放来源页面。
```

修改后

```md
- Close 关闭 Playback Page，并按 Playback Return Context 返回对应 Workbench Feature。
```

## 5. Overlay Session 生命周期

修改前

```md
- Session：
  - Current、Playlist、Search、Recent、Library 和 Shiori 的切换属于同一次 Overlay Session
  - 模块切换期间保留本次 Session 内的模块状态
  - Escape、播放动作、关闭 Playback Page 或其他关闭 Overlay 的路径结束当前 Session
  - Session 结束后不保留当前模块、搜索词、搜索结果、选择位置、滚动位置或临时显示内容
  - 再次打开时重新进入 Current，并按照各模块默认状态重新初始化
  - Session 销毁不删除 Shiori、Recent、Library、Playlist、Playback History 或持久设置
  - Session 生命周期以 Overlay 的产品级打开和关闭为边界，不以单个 Module View 的出现或消失为边界
```

修改后

```md
- Session：
  - 每次打开综合菜单界面创建一个新的 Overlay Session
  - Current、Playlist、Search、Recent、Library 和 Shiori 的切换属于同一次 Overlay Session
  - 模块切换期间保留本次 Session 内的模块、层级、选择和滚动状态
  - Escape、播放动作、关闭 Playback Page 或其他关闭 Overlay 的路径结束并销毁当前 Overlay Session
  - Session 结束后不保留当前模块、搜索结果、选择位置、滚动位置、Library 层级或临时显示内容
  - Search Query 属于 Search Feature 状态，不属于 Overlay Session；Session 销毁不清空 Search Query
  - 再次打开综合菜单时创建新的 Overlay Session，默认进入 Current，并重新初始化各 Module 的局部状态
  - 再次进入 Search 时显示 Search Feature 当前 Query
  - Session 销毁不删除 Search Query、Shiori、Recent、Library、Playlist、Playback History 或持久设置
  - Session 生命周期以综合菜单界面的打开和关闭为边界，不以单个 Module View 的出现或消失为边界
```

## 6. Playback Media Selection

修改前

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

修改后

```md
- Playback Media Selection：
  - 适用于 Recent、Library 一级界面和 Library 二级界面
  - Workbench 中这些卡片只使用所属 Layout 定义的 Hover，不建立持久 Selected Item
  - Playback 的 Selected Item 完整复用所属 Workbench Card Layout 的 Hover Region 和 Hover 视觉
  - Selected Item 不显示额外 Focus Ring、边框或独立 Selected 背景
  - Recent Watching Card 和 Library Folder Card 的 Selected 视觉作用于完整卡片
  - Library Episode 的 Selected 视觉只作用于 Cover Region
  - 方向键选择对应视觉方向上最近的可用 Item
  - Pointer 显示时，Hover 到可用的非 Selected Item 会将其设为 Selected Item
  - Pointer 显示时，滚动内容使静止 Pointer 下的 Hover 目标发生变化，也按新的 Hover 目标更新 Selected Item
  - Pointer 离开卡片或移到空白区域时不清空 Selected Item
  - 不可用 Item 不允许成为 Selected Item，方向键和 Hover 均跳过
  - Selected Item 始终滚动到可见区域
  - Selected Item 因数据刷新消失后，选择当前层级的第一个可用 Item
  - Enter 执行 Selected Item 在原 Layout 中定义的左键主操作
  - 鼠标左键和右键动作继续由所属 Card Layout 定义
  - 没有可用 Item 时不存在 Selected Item，Enter 无动作
  - Module 切换后再次返回时，恢复本次 Session 内的层级、选择和滚动位置
```

## 7. Playback Search

修改前

```md
- Search：
  - 顶部显示 Playback Search Box
  - Search Box 下方显示纵向 Playback Cue Result 列表
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range 或其他 Metadata
  - 打开 Search 时自动聚焦 Search Box
  - 输入 Query 后，在最后一次输入变化的 `100ms` 后自动更新结果
  - Search 不要求 Return 提交
  - Query 为空时不显示 Cue Result
  - 首屏结果出来后默认选择第一条 Result，且除非用户操作不修改选中 Result
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

修改后

```md
- Search：
  - 顶部显示 Playback Search Box
  - Search Box 下方显示纵向 Playback Cue Result 列表
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range 或其他 Metadata
  - Playback Search Box 显示 Search Feature 当前 Query
  - 在 Playback Search Box 中编辑或清空 Query，会更新 Search Feature 当前 Query
  - Search Query 在 Overlay Session 结束后继续保留，也不因最终 Playback Return Context 指向其他 Feature 而清空
  - Playback Search 始终使用临时空 Filter 显示结果，不继承 Workbench 当前 Filter
  - 进入 Playback Search、编辑 Query、查看结果、切换 Module 或未播放 Result 就关闭 Overlay，均不正式改变 Search Filter
  - 打开 Search 时自动聚焦 Search Box
  - 输入 Query 后，在最后一次输入变化的 `100ms` 后自动更新结果
  - Search 不要求 Return 提交
  - Query 为空时不显示 Cue Result
  - 首屏结果出来后默认选择第一条 Result，且除非用户操作不修改选中 Result
  - Search Box 保持输入焦点
  - Search Box 保持输入焦点时，Up 和 Down 由 Playback Cue Result Reel 响应，不用于移动 Caret
  - Result 选择变化不移除 Search Box 的输入焦点
  - 有输入内容时显示 Inline Clear Button
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - Search 输入优先于字母快捷键
  - S 和 C 作为普通查询输入
  - Search 的模块级字幕动作只响应 Enter
  - 存在已经 Settled 的 Selected Result 时，Enter 从其 Primary Cue Start Time 播放，正式清空 Search Filter，并将 Playback Return Context 更新为 Search
  - 不存在 Selected Result 时，Enter 无动作
```

## 8. Recent、Library 与 Shiori

修改前

```md
- Recent：
  - 复用 Recent Watching Card Layout
  - 不显示 Workbench App Sidebar 或 App Topbar
  - 本次 Session 首次进入 Recent 时默认选择第一项
  - 使用 Playback Media Selection
  - Enter 和鼠标播放动作沿用 Recent Watching Card Layout

- Library：
  - Library 一级界面复用 Library Folder Card Layout
  - Library 二级界面复用 Library Episode Grid and Card Layout
  - 不显示 Workbench App Sidebar 或 App Topbar
  - 本次 Session 首次进入 Library 一级界面时默认选择第一项
  - 每次进入 Library 二级界面时默认选择第一项
  - 使用 Playback Media Selection
  - Library 一级界面的 Enter 进入 Selected Library Folder
  - Library 二级界面的 Enter 播放 Selected Episode
  - Library Folder Detail 的 Back Button 只返回 Library 一级界面，不切换 Overlay Module
  - 返回 Library 一级界面时恢复此前的选择和滚动位置
  - 鼠标动作沿用对应 Library Layout

- Shiori：
  - 使用 Playback Cue Result Reel
  - 只显示字幕内容
  - 不显示 Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - 本次 Session 首次进入 Shiori 时默认选择第一条 Result
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue
```

修改后

```md
- Recent：
  - 复用 Recent Watching Card Layout
  - 不显示 Workbench App Sidebar 或 App Topbar
  - 本次 Session 首次进入 Recent 时默认选择第一个可用 Item
  - 使用 Playback Media Selection
  - Enter 和鼠标左键播放动作沿用 Recent Watching Card Layout
  - 右键复用 Library Card Context Menu，但不显示 `Context` Menu Item
  - 成功播放视频后，将 Playback Return Context 更新为 Recent

- Library：
  - Library 一级界面复用 Library Folder Card Layout
  - Library 二级界面复用 Library Episode Grid and Card Layout
  - 不显示 Workbench App Sidebar 或 App Topbar
  - 本次 Session 首次进入 Library 一级界面时默认选择第一个可用 Item
  - 每次进入 Library 二级界面时默认选择第一个可用 Item
  - 使用 Playback Media Selection
  - Library 一级界面的 Enter 进入 Selected Library Folder
  - Library 二级界面的 Enter 播放 Selected Episode
  - Library Folder Detail 的 Back Button 只返回 Library 一级界面，不切换 Overlay Module
  - 返回 Library 一级界面时恢复此前的选择和滚动位置
  - 鼠标动作沿用对应 Library Layout
  - 右键复用 Library Card Context Menu，但不显示 `Context` Menu Item
  - 从 Library Folder Detail 成功播放 Episode 后，将 Playback Return Context 更新为对应的 Library Folder Detail

- Shiori：
  - 使用 Playback Cue Result Reel
  - 只显示字幕内容
  - 不显示 Search Box、Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - Playback Shiori 不启用临时空 Filter，也不清空 Search Filter
  - 本次 Session 首次进入 Shiori 时默认选择第一条 Result
  - Show Cue Group 为 Off 时只显示 Primary Cue
  - Show Cue Group 为 On 时显示 Primary Cue 所属 Cue Group
  - S、C 和 Enter 的动作目标均为 Selected Result 的 Primary Cue
  - 成功播放 Result 后，将 Playback Return Context 更新为 Shiori
```
