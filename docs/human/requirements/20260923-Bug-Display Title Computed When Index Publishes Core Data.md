# 版本

main

# 关联设计

- `docs/human/design/Data.md`（Index流程 第 4 步、第 7 步）
- `docs/human/requirements/20260921-Bug-Missing Files Treated As Missing Database Records.md`（4.8 Display Title）

# 需求描述

## 1. 现状

Display Title 在 Index 第 7 步计算，Search 数据在第 4 步就已发布。两步之间，以及第 7 步失败或未执行时，Library 中还没有的视频在 Search、Excerpt 与播放页顶栏显示视频文件名，Search 结果按它排序；第 7 步完成后才变为正式标题。第 7 步未完成的资料库要到下次 Index 才补做。

## 2. 要求

1. Display Title 在 Index 第 4 步随核心数据一同计算并发布，算法不变。
2. 第 4 步发布后，Search、Excerpt 与播放页顶栏直接显示正式的 Display Title，不显示视频文件名；第 7 步失败或未执行不影响 Display Title。
3. 第 7 步不再计算 Display Title，Library 使用第 4 步的值。
4. 升级后已有数据自动按本规则重算一次，包括第 7 步未完成的资料库，无需手动 Index。

## 3. 保持不变

1. Display Title 的算法及显示它的位置。
2. Library 展示数据的其余内容仍在第 7 步重建。
3. 已失效、且字幕已不在数据库中的 Excerpt 保留失效时记下的标题。

# 验收

1. 添加一个含大量新视频的文件夹，在生成封面期间搜索其中的视频：Search 结果、此时存入的 Excerpt、从 Search 进入播放页后的顶栏，均显示与 Index 完成后 Library 一致的 Display Title；Index 完成后 Search 结果的顺序不变。
2. 在 Finder 中改名某个视频文件后 Index：结果同第 1 条。
3. 升级后，Search、Excerpt、播放页顶栏与 Library 的 Display Title 一致。
4. 不新增自动化失败，不为本需求新增 E2E 能力；第 1 至 3 条人工验收。