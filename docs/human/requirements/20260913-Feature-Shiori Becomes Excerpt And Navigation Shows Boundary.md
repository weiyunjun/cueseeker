# 版本

main

# 关联设计

- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/Data.md`
- `docs/human/design/Icon Registry.md`
- `docs/human/design/Toast Usage Registry.md`
- `docs/human/design/Command Panel.md`
- `docs/human/design/Cue Parsing.md`

# 需求描述

## 1. 目标

Shiori 更名为 Excerpt（摘录），Shiori List 更名为 Excerpt List（摘录集），界面文案、代码与数据库命名统一。播放时向上一个或下一个跳转不能跳转时，改为提示已经到头。

## 2. 要求

### 2.1 命名

1. 英文：Shiori 为 Excerpt，Shiori List 为 Excerpt List；集合的操作沿用 List（New List、Edit List、Delete List、List Name）。
2. 简体：Shiori 为摘录，Shiori List 为摘录集。繁体：摘錄、摘錄集，用词优先遵循繁体习惯，含义以简体为准。
3. 代码与数据库中的 Shiori 命名统一改为 Excerpt，ShioriID 改为 ExcerptID，Toast Scenario ID 由 `shiori.*` 改为 `excerpt.*`。

### 2.2 文案

| 位置 | English | 简体 | 繁體 |
| --- | --- | --- | --- |
| Sidebar、页面标题、播放来源名 | Excerpt | 摘录 | 摘錄 |
| Recent 标签、Command Panel 选项与标题 | Recent Excerpt Lists | 最近摘录集 | 最近摘錄集 |
| Recent 该标签为空 | No recent excerpt lists yet. | 还没有最近的摘录集。 | 尚無最近的摘錄集。 |
| Search 表格行菜单、Playback Footer 按钮、快捷键功能名 | Save to Excerpt List | 保存到摘录集 | 儲存到摘錄集 |
| 摘录表格行菜单、移除确认框标题 | Remove Excerpt | 移除摘录 | 移除摘錄 |
| 移除确认框正文 | This cue will be removed from this list. The original cue will not be deleted. | 该台词将从当前摘录集中移除。原始台词不会被删除。 | 此台詞將從目前的摘錄集中移除。原始台詞不會被刪除。 |
| 摘录表格为空 | Save cues from search results or playback to collect excerpts. | 从搜索结果中或在播放时保存台词，即可收集摘录。 | 從搜尋結果中或在播放時儲存台詞，即可收集摘錄。 |
| 摘录页统计行 | {n} Lists · {m} Cues | {n} 个摘录集 · {m} 条台词 | {n} 個摘錄集 · {m} 條台詞 |
| 新建按钮、保存目标子菜单末项、新建框标题 | New List | 新建摘录集 | 新增摘錄集 |
| 卡片右键菜单、编辑框标题 | Edit List | 编辑摘录集 | 編輯摘錄集 |
| 卡片右键菜单、删除确认框标题 | Delete List | 删除摘录集 | 刪除摘錄集 |
| 删除确认框正文 | The list “{List Name}” and its excerpts will be deleted. The original cues will not be deleted. | 摘录集“{List Name}”及其中的摘录将被删除。原始台词不会被删除。 | 摘錄集「{List Name}」及其中的摘錄將被刪除。原始台詞不會被刪除。 |
| 编辑框名称字段 | List Name | 摘录集名称 | 摘錄集名稱 |
| 名称输入提示 | Enter a list name | 输入摘录集名称 | 輸入摘錄集名稱 |
| 校验：名称为空 | Enter a list name. | 请输入摘录集名称。 | 請輸入摘錄集名稱。 |
| 校验：名称过长 | List name must be 30 characters or fewer. | 摘录集名称不能超过 30 个字符。 | 摘錄集名稱不能超過 30 個字元。 |
| 校验：重名 | A list with this name already exists. | 已存在同名摘录集。 | 已有同名的摘錄集。 |
| Toast：移动失败 | Couldn’t move the excerpt. | 移动摘录出错。 | 移動摘錄時發生錯誤。 |
| Toast：复制失败 | Couldn’t duplicate the excerpt. | 复制摘录出错。 | 複製摘錄時發生錯誤。 |
| Toast：保存失败 | Couldn’t save to “{List Name}”. | 保存到“{List Name}”出错。 | 儲存至「{List Name}」時發生錯誤。 |
| Toast：目标已存在 | This excerpt already exists in “{List Name}” | “{List Name}”中已存在该摘录 | 「{List Name}」中已有此摘錄 |
| 播放反馈：移除后 | Excerpt Removed | 已移除摘录 | 已移除摘錄 |
| 播放反馈：跳到上一条摘录 | Previous Excerpt | 上一条摘录 | 上一條摘錄 |
| 播放反馈：跳到下一条摘录 | Next Excerpt | 下一条摘录 | 下一條摘錄 |

### 2.3 英文计数区分单复数

数量为 1 时用单数，其余（含 0）用复数：

| 位置 | 单数 | 复数 |
| --- | --- | --- |
| Playback Footer：台词数 | 1 cue | {n} cues |
| Playback Footer：视频数 | 1 video | {n} videos |
| Playback Footer：结果数 | 1 result | {n} results |
| Playback Footer：摘录集数 | 1 excerpt list | {n} excerpt lists |
| 摘录卡片：台词数 | 1 Cue | {n} Cues |
| 摘录页统计行 | 1 List、1 Cue | {n} Lists、{m} Cues |

### 2.4 到头提示

向上一个或下一个跳转而不能跳转时，按方向显示下表，取代原来的"没有结果""没有媒体库视频""没有书签"。只有一条、由 URL Scheme 播放、加载失败等不能跳转的情况，同样按方向显示。

| 播放来源 | 方向 | English | 简体 | 繁體 |
| --- | --- | --- | --- | --- |
| 摘录 | 上一个 | Already at First Excerpt | 已经是第一条摘录 | 已經是第一條摘錄 |
| 摘录 | 下一个 | Already at Last Excerpt | 已经是最后一条摘录 | 已經是最後一條摘錄 |
| 视频 | 上一个 | Already at First Video | 已经是第一个视频 | 已經是第一部影片 |
| 视频 | 下一个 | Already at Last Video | 已经是最后一个视频 | 已經是最後一部影片 |
| 搜索结果、URL Scheme | 上一个 | Already at First Result | 已经是第一个结果 | 已經是第一筆結果 |
| 搜索结果、URL Scheme | 下一个 | Already at Last Result | 已经是最后一个结果 | 已經是最後一筆結果 |

### 2.5 升级

1. 已有的摘录、摘录集与封面完整保留；已有封面文件不搬移。
2. 每个摘录集的筛选条件与最近保存到的摘录集，升级后回到默认一次。

## 3. 不变的部分

1. 界面外观与交互不变，书签图标保留。
2. 视频与搜索结果成功跳转时的提示不变。
3. Move to ...、Duplicate to ... 保留省略号。
4. 默认摘录集名称 Default 不变。
5. Deep Link 格式不变，已导出的 Anki 卡片链接照常可用。
6. Windows 版与 HTML 原型不在本次范围。

# 验收

1. 英文界面不再出现 Shiori 与 Bookmark；简体与繁体界面不再出现 Shiori、书签、書籤，摘录集相关处不再出现"列表"。
2. 三种语言的文案与 2.2、2.3、2.4 逐条一致。
3. 各播放来源在第一条与最后一条处按方向显示到头提示；只有一条时，两个方向分别显示第一个与最后一个。
4. 用升级前的数据库启动后，摘录、摘录集、封面与 Deep Link 播放均正常。
5. 现有自动化端到端与单元用例全部通过。