# 调用toast的场景

## Excerpt相关

### 1. 目标写入成功，且已从来源列表移除
文字：Moved to “{List Name}”
持续时间：5秒
Scenario ID：excerpt.move.succeeded
出现位置：App Center
动画：Default

### 2. 目标副本创建成功
文字：Duplicated to “{List Name}”
持续时间：5秒
Scenario ID：excerpt.duplicate.succeeded
出现位置：App Center
动画：Default

### 3. 执行时目标列表已经不存在
文字：“{List Name}” is no longer available
持续时间：5秒
Scenario ID：excerpt.destination.unavailable
出现位置：App Center
动画：Default

### 4. 非目标消失原因导致移动失败，来源数据保持不变
文字：Couldn’t move the excerpt.
持续时间：5秒
Scenario ID：excerpt.move.failed
出现位置：App Center
动画：Default

### 5. 非目标消失原因导致复制失败
文字：Couldn’t duplicate the excerpt.
持续时间：5秒
Scenario ID：excerpt.duplicate.failed
出现位置：App Center
动画：Default

### 6. 目标列表已经包含同一CueID的目标
文字：This excerpt already exists in “{List Name}”
持续时间：5秒
Scenario ID：excerpt.destination.cue.already_exists
出现位置：App Center
动画：Default

### 7. 保存成功
文字：Saved to “{List Name}”
持续时间：5秒
Scenario ID：excerpt.save.succeeded
出现位置：App Center
动画：Default

### 8. 非目标消失原因导致保存失败
文字：Couldn’t save to “{List Name}”.
持续时间：5秒
Scenario ID：excerpt.save.failed
出现位置：App Center
动画：Default