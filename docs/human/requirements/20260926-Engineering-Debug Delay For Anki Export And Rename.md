# 版本

main

# 关联需求

- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md`

# 需求目标

Export to Anki、修改文件名称、修改文件夹名称执行过快，不便验收执行期间的任务状态与界面交互。为 Debug 构建复用现有的任务延迟开关。

# 需求

1. Debug 构建下，环境变量 `CUESEEKER_DEBUG_TASK_DELAY_SECONDS` 对 Export to Anki、修改文件名称（Rename Files）、修改文件夹名称（Rename Folder）任务生效。
2. 设置该环境变量后，上述任务开始时先等待该秒数，等待期间任务在任务面板中保持执行中（In Progress）状态。
3. 未设置该环境变量或值不是正数时不等待。
4. Release 构建不读取该变量。

# 范围

1. 启动指令保持不变：`CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker`。
2. 仅对 Export to Anki、修改文件名称、修改文件夹名称增加开始延迟，已有任务（Add Folder、Index、Remove Folder）的延迟行为保持不变。

# 验收

1. 以 `CUESEEKER_DEBUG_TASK_DELAY_SECONDS=15 swift run CueSeeker` 启动：
   - 执行 Export to Anki，任务面板中显示 In Progress 约 15 秒后完成导出。
   - 执行修改文件名称，任务面板中显示 In Progress 约 15 秒后完成重命名。
   - 执行修改文件夹名称，任务面板中显示 In Progress 约 15 秒后完成重命名。
2. 未设置该环境变量启动时，上述操作直接执行，无额外延迟。