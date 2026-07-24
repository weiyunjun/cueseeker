# 版本
main

# 需求描述

## 本次结论

本需求约束 CueSeeker 整体数据库的数据稳定性，字幕 Cue 身份和 Shiori 生命周期只是其中一部分。

数据库必须将永久逻辑身份、磁盘路径、派生 Index 和用户持久数据分开处理。任何文件移动、缺失、替换、扫描失败或身份歧义，都不能导致用户数据丢失、错误继承或当前有效 Index 被污染。

## 数据库整体稳定性约束

1. Library、Folder、Video、Subtitle、Cue 和 Shiori 使用独立永久 ID；路径、文件名、字幕序号和 Index 位置不构成永久身份。
2. 永久 ID 不修改、不复用。系统能够取得平台文件唯一身份时，只有唯一身份一致或其他已确认的唯一证据才能保留原 ID；文件身份不可得时，按照“文件身份不可得时的降级规则”处理。
3. 系统能够取得平台文件唯一身份，并确认原路径已经出现另一个资源时，新资源必须使用新的永久 ID，不能继承旧对象的进度、封面、Shiori、Recent 或其他用户数据。

### 文件身份不可得时的降级规则

- 数据库保存的旧平台文件身份或本次读取的当前平台文件身份中，任意一侧无法取得时，进入降级规则。
- 进入降级规则后，使用标准化路径作为 Library、Folder、Video 或 Subtitle 的降级绑定依据。
- 同一路径继续使用原永久 ID。
- CueSeeker 的永久 ID 保持不变，但数据库保存的平台文件身份必须更新为本次读取结果。
- 本次无法取得平台文件身份时，清除数据库中保存的旧平台文件身份，不得继续使用旧平台文件身份作为当前资源或后续资源的身份凭据。
- 平台文件身份以后重新可得时，将本次取得的平台文件身份保存为当前身份；由于此前保存的身份为空，同路径资源仍按照降级规则继续使用原永久 ID。
- 文件大小或修改日期发生变化时，重新读取内容，并将变化视为原对象被编辑。
- 文件大小和修改日期均未变化时，允许直接视为内容未变化，不读取完整文件，也不计算内容哈希。
- 极端情况下，新资源与旧资源具有相同路径、相同大小和相同修改日期所造成的错误继承，由用户承担。
- 只有数据库保存的旧平台文件身份和本次读取的当前平台文件身份都存在时，才比较两者；两者一致时保留原永久 ID，两者不一致时按新资源处理。
4. Library 离线、权限不足、扫描失败、整文件解析失败或扫描不完整时，不得产生删除结论，也不得使用空结果覆盖上一成功 Index。

### SRT 单条无效时间范围

- SRT 字幕块的开始时间和结束时间能够正确解析，但结束时间早于开始时间时，该字幕块视为单条无效数据，不视为整个字幕文件解析失败。
- 单条无效数据只忽略当前字幕块。
- 同一字幕文件中的其他正常字幕块继续参与 Index，本次成功结果可以正常发布。
- 被忽略的字幕块不保留在当前 Index 中。
- 如果被忽略字幕块的 Cue 被 Shiori 引用，则按照 Cue 不存在处理。
5. Index 属于可重建数据。字幕主索引只能在完整成功后整体发布；字幕主索引失败、取消或中断时继续使用上一成功结果。

### 主索引与附属任务边界

- 字幕主索引包括 Library 扫描、字幕读取、字幕解析、Cue 对齐、永久身份绑定和 Search Index 发布。
- 视频时长读取、自动封面生成和 Library 展示数据刷新属于字幕主索引发布后的附属任务。
- 附属任务失败不得回退已经成功发布的字幕主索引，也不得将字幕主索引状态改为失败。
- 字幕主索引成功但附属任务失败时，Index 显示成功，同时单独提示对应附属任务失败。

#### 自动封面生成失败

- 自动封面生成失败不影响字幕主索引、Search、Library、Shiori 或其他已经成功发布的数据。
- 自动封面生成失败后不自动重试。
- 用户可以手动选择或更换封面。

#### 视频时长读取失败

- 视频时长读取失败不影响字幕主索引、Search、Library 或 Shiori。
- 存在上一有效视频时长时继续保留上一有效值；不存在上一有效值时保持未知。
- 视频时长读取失败后记录待重试状态。
- 下一次执行 Index 时必须重新读取失败的视频时长，即使视频和字幕内容没有变化。
- 读取成功后清除待重试状态。

#### Library 展示数据刷新失败

- Library 展示数据包括 Library 页面使用的视频与文件夹行、显示标题、Cue 数量、所属文件夹、排序和封面引用等可重新生成的数据。
- Library 展示数据刷新失败不影响已经发布的字幕主索引。
- 刷新失败后继续保留上一成功的 Library 展示数据，并记录待重试状态。
- 下一次执行 Index 时必须重新刷新失败的 Library 展示数据，即使该 Library 的视频和字幕内容没有变化。
- 刷新成功后清除待重试状态。
6. Index 不得删除观看进度、播放历史、自定义封面、Shiori、Tag、Recent、Resume 或其他用户持久数据。
7. 用户持久数据只能引用永久 ID，不能引用路径、文件名、字幕序号或某次 Index 产生的临时位置。
8. 目标暂时不可用时保留其用户持久数据；重新确认原对象后，原永久 ID 和用户数据继续生效。
9. 只有被 Shiori 或其他用户持久数据引用的 Cue，才长期保留 Tombstone；无持久引用的 Cue 不保证无限期恢复原 CueID。
10. 文件缺失、从 CueSeeker 移除 Library 和永久清除数据是三种不同操作。永久清除必须由用户明确执行，不能作为 Index 的隐含行为。
11. 同一个 Library 同一时间只能有一个 Index 结果获得发布权；较早完成的 Index 不能覆盖较新的有效结果。
12. Schema Migration 必须保留全部永久 ID 和用户持久数据；迁移失败时不得留下部分新结构或不可用数据库。
13. Identity Conflict 和多候选不能自动恢复 Binding；用户确认重新绑定后，更新 Binding，原永久 ID 和用户数据继续生效。

## ASS Cue 的身份与索引

一个 ASS Dialogue 的身份比较分为四部分：

- `T`：时间戳（开始与结束时间）；
- `X`：文字内容；
- `S`：该 Event 引用的 Style；
- `R`：其余 Dialogue 字段，例如 Layer、Name、Margins、Effect 等。

### 处理流程

1. 先对旧、新版本做四部分完全匹配。
2. 完全匹配的 Cue 立即锁定并复用原 CueID；`Event Index` 与 `Display Order` 禁止参与身份判断或歧义消解。
3. 对剩余 Cue，再处理无歧义的局部变化。
4. 无法唯一判定时，不自动继承 CueID。

### 不可跨越的 Style 边界

Style 是硬边界。只要 Style 发生变化，新 Event 不继承原 CueID，即使时间、文字和其余字段都相同。旧 Cue 进入失效/历史状态，新 Event 使用新 CueID。

这避免了例如 CN Style 与 JP Style 被错误地视为同一字幕的情况。

### 可接受的局部修改

在 Style 不变的前提下，时间戳、文字内容、其余字段中的单项局部变化可作为身份继承候选；若多项核心信息同时变化，或出现大面积变化，则不承担“猜回原字幕”的职责。

系统的目标是处理局部、可解释的编辑，不是从错误视频、低质量字幕或整份字幕替换中重建语义对应关系。

### 完全重复 Event

若多条 ASS Event 的四部分完全相同：

- 渲染层仍保留原始多条 Event；
- 数据库、搜索、收藏和 Playback Overlay 层将其折叠为一个逻辑 Cue；
- 因而只存在一个 CueID，不产生多对多身份问题。

只要文字、Style、Layer 或其他字段不同，即应保留为不同 Cue；这些 Cue 可组成 Cue Group。

### 无法避免的内容互换

极端情况下，两条同时间、其余字段相同但 Style 与文字不同的 ASS Event，可能只交换文字而保持 Style 不变。例如原先的 `JP + 日文` 与 `CN + 中文`，变成 `JP + 中文` 与 `CN + 日文`。

最终文件无法区分“用户分别改词”与“用户交换内容”。按既定规则，Style 不变而文字变化会继承 CueID，因此收藏内容可能改变。系统不猜测语义意图；这类变化由前端提示给用户。

## SRT 的身份与渲染

SRT 可视为简化字幕：主要只有时间戳与文字内容，序号不参与身份判断、播放排序或 CueID。

### SRT 到 ASS / libass 的渲染原则

- SRT 播放管线固定为：解析原始 SRT → 将每个字幕块转换为 ASS Dialogue，并生成默认 ASS Style → 将完整 ASS 字幕轨提交给 libass 进行布局、碰撞处理和渲染。
- 第一版 SRT 前端渲染使用本需求确认的 IINA Text Subtitles 参考设置作为默认值：
  - Font：`sans-serif`
  - Size：`55`
  - Bold：Off
  - Italic：Off
  - Text Color：White
  - Background：Transparent
  - Border Size：`3`
  - Border Color：Black
  - Shadow Offset：`0`
  - Blur：`0`
  - Font Spacing：`0`
  - Horizontal Align：Center
  - Vertical Align：Bottom
  - Margin X：`25`
  - Margin Y：`22`
  - Vertical Position：`100%`
  - Display Subtitles in Letterboxes While in Full Screen：On
  - Scale Subtitles with Window Size：On
- 以上设置只用于 SRT 转换后生成的默认 ASS Style，不覆盖 ASS 文件自身定义的 Style。
- 多条同时间字幕应同时提交给渲染器；默认碰撞策略下可纵向堆叠。
- 数据库层仍可将时间戳与文字完全相同的多个块折叠成一个逻辑 Cue。

mpv/IINA 的文本字幕管线会保留同时间的多条字幕并交给 libass 布局；VLC 同样会显示多条，但上下顺序不应作为跨播放器保证。

### SRT 的歧义边界

若多条 Cue 时间戳完全相同，且多条文字同时被改写，SRT 没有 Style 或其他字段用于建立一一对应。渲染画面也不能提供历史身份。

- 新旧文字集合完全相同：按时间戳与文字完全匹配，保留原 CueID；顺序不参与判断。
- 只有一条文字变化，其他条目先被完全匹配锁定：剩余一对一变化可继承。
- 多条文字同时变化，且完全匹配后仍存在多个旧、新候选时，无法唯一确认对应关系；剩余新 Cue 全部使用新的 CueID，旧 CueID 不被自动继承。

这种限制来自格式信息不足，不是实现缺陷。

## 收藏（Shiori）的失效与变更提示

只对有收藏或其他用户持久引用的 Cue 保留失效占位和最小快照。只有被 Shiori 或其他用户持久数据引用的 Cue，才长期保留 Tombstone。

### 状态一：不可用

收藏所指向的对象无法访问时，收藏仍显示，但处于不可用状态。它不能播放、进入详情或编辑。

应保留最后已知的 Primary Cue 文字、可复制的 Cue Group Snapshot、Time Range 及必要摘要，并通过悬停提示说明当前最重要的不可用原因。

每个 Shiori 同一时间只显示一个不可用原因，优先级从高到低为：

`Cue 不存在 > 字幕文件不存在或未能重新关联 > 视频文件不存在`

- Cue 已删除或无法确认继承时，无论字幕或视频是否同时缺失，都按照 Cue 不存在处理；
- 不存在 Cue 缺失状态，但字幕文件缺失或未能重新关联时，无论视频是否同时缺失，都按照字幕文件不存在处理；
- Cue 和字幕文件均可用，但视频文件缺失时，按照视频文件不存在处理；
- 不再使用独立的“视频和字幕同时缺失”状态；
- 每次 Index 或资源重新关联后，都必须根据当前真实状态重新计算不可用原因，不能根据上一次发生的事件直接覆盖状态；
- Library 临时离线、权限不足或扫描失败时，不修改 Shiori 的当前可用状态，只在 Indexing 状态中显示 Library 不可用；
- 用户主动从 CueSeeker 移除 Library 不属于临时离线，相关 Shiori 继续使用现有的 Library Unavailable 规则。

不可用收藏仍允许：

- `Copy Cue Text`；
- `Copy Cue Group Text`；
- `Copy Time Range`；
- `Remove Shiori`；
- 当字幕文件仍可访问时，`Open Subtitle Folder`。

不可用收藏禁止 `Move to ...` 和 `Duplicate to ...`，避免将已经失效或身份无法确认的引用迁移或复制到其他 Shiori List。

不需要在 Library 中长期显示“失效视频”；确认缺失的视频从 Library、Search 和 Recent 的当前展示结果中隐藏，但不删除 Recent 持久记录。失效原因只在仍被用户收藏的内容上明确呈现。

### 状态二：内容已变更

Cue 仍可访问、可播放，但本次索引继承原 CueID 且文字相对上一成功版本发生变化时，显示“内容已变更”标记。该标记不代表不可用，也不应将对象置灰。

悬停时展示：

- 上一次文本；
- 当前文本。

系统不判断这究竟是用户修正字幕、误收藏还是极端内容互换，只如实呈现变化。只保存上一成功版本；后续索引未再变化时移除该提示，避免无限历史负担。

文件夹或显示标题的改名不属于 Cue 内容变更，不需要此提示。

## 与文件身份规则的衔接

CueID 对齐的前提是字幕文件先被绑定到正确的逻辑 `SubtitleID`。

- 同卷改名、移动或文件夹改名：若 Bookmark / 平台稳定文件标识仍能确认原对象，更新 Binding 与路径，永久 ID 不变。
- 复制后删除原件：系统文件身份会改变；若旧文件缺失且只有一个完整内容相同、无副本歧义的候选，可重新绑定；否则需要用户确认。
- 内容编辑同时发生时，内容哈希不能单独证明文件身份；仍需系统级强证据或用户确认。
- NAS 或资料库根目录不可访问、扫描失败时，索引不发布，不能将空结果解释为删除。

## Index
- Index 只能处理新增、修改、移动、删除及其必要关联数据。允许扫描目录和读取轻量元数据以发现变化；未变化资源不得重新解析字幕、遍历 Cue、重建全局 FTS 或 Presentation、读取视频媒体元数据或刷新封面。
# UI文档改动

### 1. 增加状态图标

修改前

```markdown
- Hide Column: `eye-off`
- Remove Shiori: `bookmark.slash`; fallback `bookmark`
- Back: `chevron.left`
```

修改后

```markdown
- Hide Column: `eye-off`
- Cue Content Changed: `clock.arrow.circlepath`
- Cue Unavailable: `questionmark.circle`
- Remove Shiori: `bookmark.slash`; fallback `bookmark`
- Back: `chevron.left`
```

### 2. 增加 Cue State Indicator 与 Hover Tip

修改前

```markdown
### 3.5 展示与状态

#### Chip / Tag
```

修改后

```markdown
### 3.5 展示与状态

#### Cue State Indicator

- 用途：在 Workbench Shiori Table 中显示被持久引用 Cue 的当前状态。
- 状态：Content Changed、Unavailable。
- Content Changed 使用 Cue Content Changed Icon。
- Unavailable 使用 Cue Unavailable Icon。
- Normal 不显示 Cue State Indicator。
- Icon 使用 `--size-control-icon` 和 `--color-icon-muted`。
- Indicator 使用透明背景和无边框外观，不响应普通左键动作。
- Indicator 不属于 Cue 文字选择和复制内容。
- Pointer Hover Indicator 时显示 Cue State Tip。
- Pointer 离开 Indicator 时关闭 Cue State Tip。
- 右键 Indicator 时继续打开所属 Table Row 的 Row Action Menu。

#### Cue State Tip

- 用途：解释 Content Changed 或 Unavailable 的具体状态。
- 背景、边框、圆角和阴影使用 `--color-bg-popover`、`--color-border-muted`、`--radius-control` 和 `--shadow-popover`。
- Tip 固定锚定 Cue State Indicator。
- 默认显示在 Indicator 右侧。
- 右侧可见区域不足以完整显示 Tip 时，改为显示在 Indicator 左侧。
- Tip 与 Indicator 垂直居中。
- Tip 与 Indicator 的间距使用 `--spacing-2`。
- Title 使用 `--color-text-primary` 和 semibold。
- `Previous`、`Current` Label 使用 `--color-text-muted`。
- Message、Previous Value、Current Value 和 Unavailable Reason 使用 `--color-text-secondary`。
- Tip 内文字允许自然换行。

- Content Changed：
  - Title：`Content Changed`
  - Message：`This cue changed after reindexing.`
  - 按顺序显示 `Previous`、Previous Value、`Current`、Current Value
  - Previous Value 显示上一次成功索引保存的文字
  - Current Value 显示当前文字

- Unavailable：
  - Title：`Unavailable`
  - 同一时间只显示一条 Reason
  - Cue、字幕和视频状态同时不可用时，按照 `Cue 不存在 > 字幕文件不存在或未能重新关联 > 视频文件不存在` 的优先级选择 Reason
  - Cue 不存在：`This cue could not be found in the current subtitle file.`
  - 字幕文件不存在或未能重新关联：`The subtitle file is missing or could not be reconnected.`
  - 视频文件不存在但字幕仍可访问：`The video file is missing. The subtitle file is still available.`
  - 用户主动从 CueSeeker 移除 Library：`The library source is currently unavailable.`
  - Library 临时离线、权限不足或扫描失败不在 Shiori 中显示 Unavailable Reason
  - 不再显示：`The video and subtitle files are missing.`

#### Chip / Tag
```

### 3. 定义 Unavailable 行的文字颜色

修改前

```markdown
- Primary Cue 使用 `--font-size-table`、`--line-height-table-cue-primary`、`--color-text-secondary`。
- Extra Cues 使用 `--font-size-caption`、`--line-height-table-cue-secondary`、`--color-text-muted`。
- Primary Cue 和 Extra Cues 的文字字形分别在各自的 line-height 行框内垂直视觉居中。
```

修改后

```markdown
- Primary Cue 使用 `--font-size-table`、`--line-height-table-cue-primary`、`--color-text-secondary`。
- Extra Cues 使用 `--font-size-caption`、`--line-height-table-cue-secondary`、`--color-text-muted`。
- Normal 和 Content Changed Shiori Row 保持各列原有文字颜色。
- Unavailable Shiori Row 的 Display Title、Primary Cue、Extra Cues、Tag 文字、Time Range 和 Date Added 统一使用 `--color-text-muted`。
- Unavailable 不属于 Disabled，不使用 `--color-bg-disabled`，不增加整行背景或透明度。
- Primary Cue 和 Extra Cues 的文字字形分别在各自的 line-height 行框内垂直视觉居中。
```

### 4. 修改 Cue 的左键交互

修改前

```markdown
#### Interactive Text Cell

- 用途：为 Cue 文字提供文字选择和表格正文中唯一的普通文字左键动作。
- Token：`--color-bg-hover`、`--radius-table-cell-hover`、`--padding-table-cell-hover-x`、`--padding-table-cell-hover-y`。
- 下划线使用 `--width-interactive-text-underline`、`--offset-interactive-text-underline` 和当前文字色。
- Hover Region 覆盖当前完整显示的 Cue 内容。
- Show Cue Group 开启时，所有显示的 Cue 共用一个 Hover Region。
- Hover 使用一个圆角矩形，不为每一行文字分别绘制背景。
- Hover 时所有显示的 Cue 文字显示下划线。
- 无拖拽的普通单击从 Primary Cue 播放。
- 从 Cue 文字开始拖拽时进入文字选择并抑制播放。
- Display Title、Tags 中的文字、Time Range 和 Date Added 不使用 Interactive Text Cell。
- 右键交给所属行的 Row Action Menu。
```

修改后

```markdown
#### Interactive Text Cell

- 用途：为可播放 Cue 文字提供文字选择和表格正文中唯一的普通文字左键动作。
- Token：`--color-bg-hover`、`--radius-table-cell-hover`、`--padding-table-cell-hover-x`、`--padding-table-cell-hover-y`。
- 下划线使用 `--width-interactive-text-underline`、`--offset-interactive-text-underline` 和当前文字色。
- Normal 和 Content Changed Cue 使用完整 Interactive Text Cell 交互。
- Hover Region 覆盖当前完整显示的 Cue 内容，但不包含 Cue State Indicator。
- Show Cue Group 开启时，所有显示的 Cue 共用一个 Hover Region。
- Hover 使用一个圆角矩形，不为每一行文字分别绘制背景。
- Hover 时所有显示的 Cue 文字显示下划线。
- 无拖拽的普通单击从 Primary Cue 播放。
- 从 Cue 文字开始拖拽时进入文字选择并抑制播放。
- Unavailable Cue 不显示 Hover 背景或下划线，不响应普通左键播放，也不使用 `pointer` Cursor。
- Unavailable Cue 文字仍然允许选择和复制。
- Cue State Indicator 是独立 Hover Target，不属于 Interactive Text Cell。
- Display Title、Tags 中的文字、Time Range 和 Date Added 不使用 Interactive Text Cell。
- 右键交给所属行的 Row Action Menu。
```

### 5. 定义 Indicator 在 Cues Cell 中的位置

修改前

```markdown
- Cues / Extra Cues：
  - Show Cue Group 开启时显示
  - 位于 Primary Cue 上方
  - `--color-text-muted`
  - `--font-size-caption`
  - `--line-height-table-cue-secondary`
  - Font Weight `400`

- Display Title：
```

修改后

```markdown
- Cues / Extra Cues：
  - Show Cue Group 开启时显示
  - 位于 Primary Cue 上方
  - `--color-text-muted`
  - `--font-size-caption`
  - `--line-height-table-cue-secondary`
  - Font Weight `400`

- Cues / Cue State Indicator：
  - 仅用于 Shiori
  - Normal 不显示
  - Content Changed 显示 Content Changed Indicator
  - Unavailable 显示 Unavailable Indicator
  - 同时满足 Content Changed 和 Unavailable 时，只显示 Unavailable Indicator
  - Indicator 以内联方式位于 Primary Cue 最后一个可见字符之后
  - Primary Cue 自动换行时，Indicator 跟随最后一条视觉行
  - Indicator 与 Primary Cue 的间距使用 `--spacing-2`
  - Indicator 不创建独立 Status Column

- Display Title：
```

### 6. 修改正文 Hover 和 Tags Cell 交互

修改前

```markdown
- 正文左键：
  - Cues 使用 Interactive Text Cell。
  - Shiori Tags Cell 是显式控件，整个 Cell 均可点击，包括没有 Tag 的空白区域。
  - 无拖拽单击 Shiori Tags Cell，打开 Shiori Tag Popover。
  - 从 Shiori Tags Cell 内的文字开始拖拽时只进行文字选择，不打开 Popover。
  - Display Title、Time Range 和 Date Added 文字只负责选择和复制。
  - Checkbox 只改变批量选择。
  - 除 Shiori Tags Cell 外，其他普通空白区域无动作。
  - 文字拖选可以从非标题栏且非顶栏的任意非交互区域开始（非交互区域 = 点击没有效果的区域）。手势进入表格后才建立新选区。
  - 选区内容始终只有表格文字。

- 正文 Hover：
  - 不显示 Full-row Hover 或 Full-row Selected。
  - Cue Hover 使用 Interactive Text Cell。
  - Display Title、Time Range 和 Date Added 不显示可点击 Hover。
  - Pointer Cursor 只出现在 Cue 的直接点击区域和 Shiori Tags Cell。
```

修改后

```markdown
- 正文左键：
  - Normal 和 Content Changed Cues 使用 Interactive Text Cell。
  - Unavailable Cues 只允许文字选择和复制，不响应播放。
  - Normal 和 Content Changed Shiori Tags Cell 是显式控件，整个 Cell 均可点击，包括没有 Tag 的空白区域。
  - Unavailable Shiori Tags Cell 为 Read-only，不打开 Shiori Tag Popover。
  - 无拖拽单击可用的 Shiori Tags Cell，打开 Shiori Tag Popover。
  - 从 Shiori Tags Cell 内的文字开始拖拽时只进行文字选择，不打开 Popover。
  - Display Title、Time Range 和 Date Added 文字只负责选择和复制。
  - Checkbox 只改变批量选择。
  - Cue State Indicator 不响应普通左键动作。
  - 除可用的 Shiori Tags Cell 外，其他普通空白区域无动作。
  - 文字拖选可以从非标题栏且非顶栏的任意非交互区域开始（非交互区域 = 点击没有效果的区域）。手势进入表格后才建立新选区。
  - 选区内容始终只有表格文字。

- 正文 Hover：
  - 不显示 Full-row Hover 或 Full-row Selected。
  - Normal 和 Content Changed Cue Hover 使用 Interactive Text Cell。
  - Unavailable Cue 不显示 Interactive Text Cell Hover。
  - Cue State Indicator Hover 显示 Cue State Tip。
  - Display Title、Time Range 和 Date Added 不显示可点击 Hover。
  - Pointer Cursor 只出现在可播放 Cue 的直接点击区域和可编辑的 Shiori Tags Cell。
```

### 7. 定义 Unavailable 行的菜单可用性

修改前

```markdown
- Shiori Row Action Menu 的 Action 顺序：

  1. `Play`
  2. `Open Subtitle Folder`
  3. `Context`
  4. `Copy Cue Text`
  5. `Copy Cue Group Text`，仅 `Show Cue Group = On` 时显示
  6. `Copy Time Range`
  7. `Move to ...`
  8. `Duplicate to ...`
  9. `Remove Shiori`

- Divider：
```

修改后

```markdown
- Shiori Row Action Menu 的 Action 顺序：

  1. `Play`
  2. `Open Subtitle Folder`
  3. `Context`
  4. `Copy Cue Text`
  5. `Copy Cue Group Text`，仅 `Show Cue Group = On` 时显示
  6. `Copy Time Range`
  7. `Move to ...`
  8. `Duplicate to ...`
  9. `Remove Shiori`

- Normal 和 Content Changed Shiori Row 使用现有 Action 可用性。

- Unavailable Shiori Row：
  - `Play` 为 Disabled
  - `Open Subtitle Folder` 仅在当前 Subtitle File 仍可访问时可用，否则为 Disabled
  - `Context` 为 Disabled
  - `Copy Cue Text` 可用，复制最后保存的 Cue Snapshot
  - `Copy Cue Group Text` 在显示时可用，复制最后保存的 Cue Group Snapshot
  - `Copy Time Range` 可用，复制当前行显示的 Time Range
  - `Move to ...` 为 Disabled
  - `Duplicate to ...` 为 Disabled
  - `Remove Shiori` 可用

- Divider：
```

### 8. 明确 Shiori 数量包含 Unavailable 项

修改前

```markdown
  - 左侧显示 `N Lists · M Cues`
  - `M Cues` 按 CueID 去重
```

修改后

```markdown
  - 左侧显示 `N Lists · M Cues`
  - `M Cues` 包含 Normal、Content Changed 和 Unavailable Shiori
  - `M Cues` 按 CueID 去重
```

修改前

```markdown
- Library Cover Badge 位于封面右下角，格式为 `{count} Cues`。
```

修改后

```markdown
- Library Cover Badge 位于封面右下角，格式为 `{count} Cues`。
- `{count}` 包含当前 Shiori List 中的 Normal、Content Changed 和 Unavailable Shiori。
```

### 9. Playback Shiori 排除 Unavailable 项

修改前

```markdown
- Shiori：
  - 使用 Playback Cue Result Reel
  - 只显示字幕内容
  - 不显示 Search Box、Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - Playback Shiori 不启用临时空 Filter，也不清空 Search Filter
  - 本次 Session 首次进入 Shiori 时默认选择第一条 Result
```

修改后

```markdown
- Shiori：
  - 使用 Playback Cue Result Reel
  - 只显示字幕内容
  - 只将 Normal 和 Content Changed Shiori 加入 Playback Cue Result Reel
  - Unavailable Shiori 不进入 Playback Cue Result Reel，也不参与结果顺序和默认选择
  - 不显示 Search Box、Filter、Utility Bar、Table Header、Checkbox、Display Title、Tags、Time Range、Date Added 或其他 Metadata
  - Playback Shiori 不启用临时空 Filter，也不清空 Search Filter
  - 本次 Session 首次进入 Shiori 时默认选择第一条 Result
```
