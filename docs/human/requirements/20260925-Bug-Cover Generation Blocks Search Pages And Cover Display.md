# 版本

main

# 关联设计

- `docs/human/design/Data.md`（Index流程 第 6 步）
- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md`（5. Index 进度）

# 需求描述

## 1. 现状

Index Now 与 Add Folder 生成封面期间，直到该阶段结束：

1. Recent、Library、Excerpt 中已有的封面显示为占位图，封面文件与数据并未改变。
2. Search 无法完成搜索。
3. 本次启动后首次打开的 Recent、Library 等页面一直显示加载中。

## 2. 要求

1. 生成封面期间，封面显示、Search 与各页面加载不受影响，与没有 Index 时一致。
2. 生成封面阶段的耗时不明显慢于修改前。

## 3. 保持不变

1. 封面生成规则与结果（Data.md 第 6 步）。
2. Index 的阶段、进度显示与任务移除行为。

# 验收

1. 添加一个含大量新视频的文件夹，生成封面期间：Recent、Library、Excerpt 中已有的封面正常显示；Search 正常出结果。
2. 重启 App 后在 File 页添加此类文件夹，生成封面期间首次打开 Recent 与 Library：正常显示内容，不停在加载中。
3. 生成封面阶段的耗时与修改前相比不明显变慢。
4. 自动化测试：生成封面期间，Search 与页面加载所用的后台任务能立即执行。
5. 不新增自动化失败，不为本需求新增 E2E 能力；第 1 至 3 条人工验收。