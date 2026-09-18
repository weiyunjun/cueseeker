# 版本

main

# 关联需求

- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md`

# 需求目标

Remove Folder 执行太快，无法在 App 内验收它执行期间的界面状态与播放行为。为 Debug 构建临时加一个延迟开关。

# 需求

1. Debug 构建读取环境变量 `CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS`，值为秒数。
2. 设置后，Remove Folder 任务开始时先等待该秒数，再按原流程执行移除；等待期间任务处于执行中。
3. 取消 Add Folder、启动时清理中断的 Add Folder，这两种数据清理不等待。
4. 未设置或值不是正数时不等待。
5. Release 构建不读取该变量。

# 范围

1. 只对 Remove Folder 加延迟。
2. 临时使用，关联需求验收通过后删除。

# 验收

1. 以 `CUESEEKER_DEBUG_REMOVE_FOLDER_DELAY_SECONDS=15 swift run CueSeeker` 启动，Remove Folder 保持 In Progress 约 15 秒后完成移除。
2. 未设置该变量时，Remove Folder 的行为与改动前一致。
3. 取消 Add Folder 时的清理不等待。