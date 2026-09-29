# 版本

main

# 关联设计

- `docs/human/design/Data.md`
- `docs/human/design/UI Application Rules.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/Toast Usage Registry.md`
- `docs/human/requirements/20260927-Feature-Search View Preserves Results Across Library Tasks.md`

# 需求描述

## 1. 总原则

1. 除 File 一级界面外，Index、Add Folder 与 Remove Folder 完成后，不刷新当前显示的界面。
2. 失效：条目对应的 Cue 已不在资料库中。

## 2. Search 与 Playlist 保持一致

1. 点击任一 Search 结果进入播放时重建 Playlist，Search 结果、总数与 Filter 计数同步剔除失效项。
2. 剔除只去掉失效项：不重新搜索，不加入新命中，不更新字幕文字，顺序不变。
3. 播放期间任务完成、Playlist 剔除失效项时，Search 同步剔除。
4. 进入播放时搜索尚未完成：之后到达的全量结果同样剔除失效项，包括返回 Search 界面后才到达的。
5. 未进入播放时，Search 结果与 Filter 不变，后退、前进与切换标签页均不改变。

## 3. Excerpt 任务期间可用，再次出现时刷新

1. Index、Add Folder 与 Remove Folder 执行期间，Excerpt 一级与二级界面照常显示、可操作，不清空。
2. 任务完成后不立即刷新；界面再次出现时读取最新数据，显示失效与内容已变更状态。
3. 再次出现：切换标签页后返回、后退与前进、Excerpt 一级与二级界面之间切换或切换 List、从播放页返回。关闭对话框或菜单、开关 Command Panel、切换 App 不算。
4. Recent 界面的 Recent Excerpt Lists 同样在再次出现时更新。
5. 刷新后保留滚动位置与 Filter 勾选。

## 4. 未显示失效状态的失效条目

1. 点击 Excerpt 条目播放：与 Search 一致，进入播放页保持黑屏，显示报错横幅 `This item is no longer in the library`；Playlist 不含失效项。
2. Search 与 Excerpt 的 Selection Action Overlay 中，Export to Anki、Copy Deep Links、Copy Table 在执行时检测所选条目：
   1. 全部失效：拦截并弹出 toast。选中 1 条为 `Cue Not in Library`，多条为 `Cues Not in Library`，中文文案与单数相同。
   2. 部分失效：只处理有效条目，界面勾选不变。
3. Excerpt 行菜单的 `Move to List` 与 `Duplicate to List`：拦截并弹出 `Cue Not in Library`。

## 5. 保持不变

1. Filter 文件夹勾选规则不变。
2. 已显示失效状态的条目交互不变。
3. Excerpt 界面内的移动、复制与删除照常即时生效。

# 验收

1. 延迟模拟下，任务执行期间进入或停留在 Excerpt 一级、二级界面：内容不清空，可正常操作。
2. 任务完成后停留在 Search 或 Excerpt 界面：无刷新、无闪烁。
3. Excerpt 条目失效后，后退再前进、切换标签页后返回或从播放页返回：显示失效标志。
4. Search 结果失效后未播放：后退再前进，结果与 Filter 不变；点击任一结果进入播放再返回：失效项已剔除，总数与 Filter 计数同步，与 Playlist 一致。
5. 批量与单行拦截：全部失效时按单复数弹出 toast；部分失效时只处理有效条目。
6. 以 `の` 搜索，点击结果到进入播放的耗时，改动前后无明显回退。
7. 单元测试与集成测试全部通过。