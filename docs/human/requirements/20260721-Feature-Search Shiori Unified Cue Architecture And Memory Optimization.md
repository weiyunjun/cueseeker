# 版本
main

# 需求描述

## 架构改动
修改当前的数据架构
```txt
Cue 数据
└── CueID → Cue Content

Search Result
└── 有序的 CueID 列表

Shiori Result
└── 有序的 Shiori Relation 列表
    ├── ShioriID
    ├── CueID
    ├── 所属 Shiori 列表
    ├── Date Added
    └── Tags
```
Search 输出有序的 CueID 列表。Shiori 输出有序的 Shiori 关系列表，每条关系同时包含 ShioriID 和 CueID。两者都通过 CueID 读取同一份 Cue 内容；Shiori 关系操作通过 ShioriID 定位。

## 架构内容
1. CueID 唯一标识 Cue 内容。Search Result 直接引用 CueID；每条 Shiori 关系也必须引用一个有效 CueID。Search 和 Shiori 通过 CueID 使用同一份 Cue 内容。  
2. ShioriID 唯一标识一条 Shiori 关系。每条关系属于一个 Shiori 列表。同一个 Cue 在同一个列表内最多建立一条关系，但可以在不同列表中分别建立不同的 Shiori 关系。
3. CueID负责字幕内容身份；ShioriID只负责收藏关系、Date Added和Tags。
4. Workbench Shiori、Playback Shiori 以及从任何界面触发的 Shiori 操作，都通过 CueID 读取同一份 Cue 内容。Shiori 关系只提供收藏身份、所属列表、Date Added 和 Tags，不另外提供字幕正文、时间、路径、语言、Cue Group 或视频信息。
5. Search数据和Shiori数据共用Cue内容、Cue Group、标题、语言、时间、播放、复制、Context和导出逻辑。各界面共享基于 CueID 定位内容和执行操作的底层逻辑；具体界面是否提供某项操作，仍遵守该界面的功能边界。
6. Search数据和Shiori数据差异。1. 结果来源。Search：满足查询条件的 Cue。Shiori：与当前 Shiori 列表建立关系的 Cue。2. 结果顺序。Search：搜索规则产生的顺序。Shiori：收藏时间、用户排序或未来列表规则产生的顺序。3. 关系信息。Search 结果本身只需要 Cue。Shiori 结果还包含 ShioriID、所属列表、Date Added 和 Tags。4. 更新原因。Search 在查询、筛选或排序改变时更新。Shiori 在列表成员、标签、Date Added、当前列表或排序改变时更新。
7. Search 与 Shiori 分别保存各自的搜索条件、筛选条件、排序、列状态、选择状态及滚动位置。切换界面后返回，在结果集未变化时，应恢复到原先显示的 Cue 及其视口位置。例如离开前显示第 100 条，返回后仍显示该 Cue，而不是回到顶部。如果原Cue已经不存在，优先恢复原Cue之前的锚点。
8. 保存、取消保存、加入列表、移出列表和修改 Tags 都是对 Shiori 关系的操作；这些操作可以从 Search、Shiori、Playback 或其他具备相应能力的界面触发。
9. Workbench 与 Playback 共同使用唯一的长期 Cue 内容来源；Search、Shiori 和 Playback 不得分别长期保存同一 Cue 的独立内容副本。
10. 表格保持现有虚拟渲染和动态行高行为。全部逻辑数据可以驻留内存，但字体排版、文本换行、Tags 布局、Hover、原生行视图等展示资源，只允许由当前可见区域及表格现有的滚动预处理范围持有。离开该范围的行不得长期保留重复的 Cue 内容、Tags 内容或完整行展示对象。为维持滚动条位置而保存的轻量行高数据不受此限制。
11. 如果Cue内容发生变化，Shiori显示新内容。

## 注意事项
1. Tags不应因为为所有行建立重复展示对象而产生大幅固定内存增长。
2. 当前数据库没有缺少 CueID 的 Shiori，本次改动不保留历史字幕快照、路径时间猜测或无 CueID 展示兜底。工程实施前必须确认现有 Playback 等正常调用已经全部使用 CueID。
3. Shiori 初始化完成后，全部 Cue 基础数据和 Shiori 关系数据应驻留内存；任意滚动位置不得依赖临时数据库查询。
4. 页面切换不得重新构造完整Cue数据。

## 验收要求
1. 任意拖动滚动条后必须立即显示目标行，不允许临时空白或数据库等待。
2. 表格的各种交互操作符合预期。
3. 数据展示符合预期。
4. 本次只完成 Shiori 多列表所需的数据架构改动，不实现多列表的界面、列表管理、切换及具体交互功能；多列表功能由后续需求实现。