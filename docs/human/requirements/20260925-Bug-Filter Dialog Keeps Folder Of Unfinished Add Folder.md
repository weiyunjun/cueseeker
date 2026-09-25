# 版本

main

# 关联设计

- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md`（4. 任务行为 第 2、6 条）
- `docs/human/requirements/20260916-Feature-Filter Dialog Folder Group And Fixed Height.md`（2. Folder 组 第 2 条）

# 需求描述

## 1. 现状

Add Folder 未完成时（执行中退出 App 后重启，或执行中被移除），它新增的数据已按规则清除，File 页与 Library 也不显示该文件夹；但 Search 与 Excerpt 的 Filter Dialog 仍按清除前的数据列出选项，Folder 组中仍有该文件夹，直到下一次 Index 完成。

## 2. 要求

1. Add Folder 新增的数据被清除后，Filter Dialog 立即按清除后的数据列出选项，Folder 组不再出现该文件夹。
2. 重启后的清除在 App 显示任何内容之前完成，任何页面都不出现被清除的数据。

## 3. 保持不变

1. 未完成的 Add Folder 仍按 20260918 需求单清除它新增的数据，任务记录不变。

# 验收

1. 添加一个新文件夹，在生成封面阶段退出 App 并重启：Search 与 Excerpt 的 Filter Dialog 中没有该文件夹，File 页与 Library 同样没有。
2. 添加一个新文件夹，在生成封面阶段移除该任务：结果同第 1 条，无需重启。
3. 自动化测试覆盖第 1、2 条中的数据清除与 Filter Dialog 选项列表。
4. 不新增自动化失败，不为本需求新增 E2E 能力；第 1、2 条人工验收。