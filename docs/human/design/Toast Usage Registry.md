# Toast 与 Feedback 调用场景注册表 (Toast & Feedback Usage Registry)

## 规范总则

1. **持续时间分档（Stay Duration）**：
   - **轻提示（1.5秒）**：成功的瞬态操作反馈（复制成功、摘录成功、截图成功等）。
   - **报错与警示（3秒）**：操作失败、目标失效、条目已存在、媒体库拦截等。
   - **播放器常规 HUD（1秒）**：视频播放高频控制与导航边界提示（播放/暂停、快进快退松手后、音量、倍速、字幕开关、列表切换等）。
2. **标点规范**：所有 Toast 与 Feedback 文案（含英、简、繁）末尾**一律不加句号**。
3. **图标语义**：
   - 报错、警示、失效、已存在及不可用拦截统一使用 `warning`。
   - 成功与功能操作使用对应语义图标（`copy`、`bookmarkSimple`、`camera`、`play`、`pause` 等）。
4. **出现位置与组件**：
   - **Toast（App Center）**：窗口级 4 槽堆叠提示容器（Workbench 界面）。
   - **Feedback & HUD（Playback Center）**：播放器画面中央单槽提示容器（Playback 界面）。

---

## 一、Workbench 表格操作（Table Toast）

### 1. 复制单行台词文本
- 英文：Cue Text Copied
- 简体中文：已复制台词
- 繁体中文：已拷貝台詞
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：table.row.copy_cue_text
- 出现位置：App Center
- 动画：Default

### 2. 复制单行 Deep Link
- 英文：Deep Link Copied
- 简体中文：已复制 Deep Link
- 繁体中文：已拷貝 Deep Link
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：table.row.copy_deep_link
- 出现位置：App Center
- 动画：Default

### 3. 复制单行台词组文本
- 英文：Cue Group Text Copied
- 简体中文：已复制台词组文本
- 繁体中文：已拷貝台詞組文字
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：table.row.copy_cue_group_text
- 出现位置：App Center
- 动画：Default

### 4. 复制单行时间范围
- 英文：Time Range Copied
- 简体中文：已复制时间范围
- 繁体中文：已拷貝時間範圍
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：table.row.copy_time_range
- 出现位置：App Center
- 动画：Default

### 5. 复制选中多行 Deep Links
- 英文：Deep Links Copied
- 简体中文：已复制 Deep Link
- 繁体中文：已拷貝 Deep Link
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：table.selection.copy_deep_links
- 出现位置：App Center
- 动画：Default

### 6. 复制选中多行表格内容
- 英文：Table Copied
- 简体中文：已复制表格
- 繁体中文：已拷貝表格
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：table.selection.copy_table
- 出现位置：App Center
- 动画：Default

---

## 二、摘录管理相关（Excerpt Toast）

### 7. 目标写入成功，且已从来源列表移除
- 英文：Moved to “{List Name}”
- 简体中文：已移动到“{List Name}”
- 繁体中文：已移動至「{List Name}」
- 图标：bookmarkSimple (fill)
- 持续时间：1.5秒
- Scenario ID：excerpt.move.succeeded
- 出现位置：App Center
- 动画：Default

### 8. 目标副本创建成功
- 英文：Duplicated to “{List Name}”
- 简体中文：已复制到“{List Name}”
- 繁体中文：已複製至「{List Name}」
- 图标：bookmarkSimple (fill)
- 持续时间：1.5秒
- Scenario ID：excerpt.duplicate.succeeded
- 出现位置：App Center
- 动画：Default

### 9. 保存成功
- 英文：Saved to “{List Name}”
- 简体中文：已保存到“{List Name}”
- 繁体中文：已儲存至「{List Name}」
- 图标：bookmarkSimple (fill)
- 持续时间：1.5秒
- Scenario ID：excerpt.save.succeeded
- 出现位置：App Center
- 动画：Default

### 10. 执行时目标列表已经不存在
- 英文：“{List Name}” is no longer available
- 简体中文：“{List Name}”已不存在
- 繁体中文：「{List Name}」已不存在
- 图标：warning
- 持续时间：3秒
- Scenario ID：excerpt.destination.unavailable
- 出现位置：App Center
- 动画：Default

### 11. 目标列表已经包含同一CueID的目标
- 英文：This excerpt already exists in “{List Name}”
- 简体中文：“{List Name}”中已存在该摘录
- 繁体中文：「{List Name}」中已有此摘錄
- 图标：warning
- 持续时间：3秒
- Scenario ID：excerpt.destination.cue.already_exists
- 出现位置：App Center
- 动画：Default

### 12. 非目标消失原因导致移动失败，来源数据保持不变
- 英文：Couldn’t move the excerpt
- 简体中文：移动摘录出错
- 繁体中文：移動摘錄時發生錯誤
- 图标：warning
- 持续时间：3秒
- Scenario ID：excerpt.move.failed
- 出现位置：App Center
- 动画：Default

### 13. 非目标消失原因导致保存失败
- 英文：Couldn’t save to “{List Name}”
- 简体中文：保存到“{List Name}”出错
- 繁体中文：儲存至「{List Name}」時發生錯誤
- 图标：warning
- 持续时间：3秒
- Scenario ID：excerpt.save.failed
- 出现位置：App Center
- 动画：Default

### 14. 非目标消失原因导致复制失败
- 英文：Couldn’t duplicate the excerpt
- 简体中文：复制摘录出错
- 繁体中文：複製摘錄時發生錯誤
- 图标：warning
- 持续时间：3秒
- Scenario ID：excerpt.duplicate.failed
- 出现位置：App Center
- 动画：Default

---

## 三、媒体库边界拦截（Library Interception Toast）

### 15. 台词不在媒体库中
- 英文：Cue Not in Library
- 简体中文：台词不在媒体库中
- 繁体中文：台詞不在資料庫中
- 图标：warning
- 持续时间：3秒
- Scenario ID：cue_not_in_library
- 出现位置：App Center
- 动画：Default
- 说明：在 Workbench 表格行菜单中，当所属视频已从媒体库移除，用户点击 `Copy Deep Link` 或 `Save to Excerpt List` 时触发拦截。

---

## 四、播放界面反馈与 HUD（Playback Feedback & HUD）

### 4.1 播放界面轻提示（1.5秒）

#### 16. 复制选中的字幕文本
- 英文：Selected Text Copied
- 简体中文：已复制选中文本
- 繁体中文：已拷貝選取文字
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：playback.feedback.selected_text_copied
- 出现位置：Playback Center
- 动画：Default

#### 17. 复制单句字幕台词
- 英文：Cue Text Copied
- 简体中文：已复制台词
- 繁体中文：已拷貝台詞
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：playback.feedback.cue_text_copied
- 出现位置：Playback Center
- 动画：Default

#### 18. 复制单句 Deep Link
- 英文：Deep Link Copied
- 简体中文：已复制 Deep Link
- 繁体中文：已拷貝 Deep Link
- 图标：copy
- 持续时间：1.5秒
- Scenario ID：playback.feedback.deep_link_copied
- 出现位置：Playback Center
- 动画：Default

#### 19. 复制视频截图
- 英文：Screenshot Copied
- 简体中文：已复制截图
- 繁体中文：已拷貝截圖
- 图标：camera
- 持续时间：1.5秒
- Scenario ID：playback.feedback.screenshot_copied
- 出现位置：Playback Center
- 动画：Default

#### 20. 移出当前摘录
- 英文：Excerpt Removed
- 简体中文：已移除摘录
- 繁体中文：已移除摘錄
- 图标：bookmarkSimple
- 持续时间：1.5秒
- Scenario ID：playback.feedback.excerpt_removed
- 出现位置：Playback Center
- 动画：Default

---

### 4.2 播放界面报错与警示（3秒）

#### 21. 当前画面无字幕
- 英文：No Subtitle
- 简体中文：无字幕
- 繁体中文：沒有字幕
- 图标：warning
- 持续时间：3秒
- Scenario ID：playback.feedback.no_subtitle
- 出现位置：Playback Center
- 动画：Default

#### 22. 复制失败
- 英文：Copy Failed
- 简体中文：复制失败
- 繁体中文：拷貝失敗
- 图标：warning
- 持续时间：3秒
- Scenario ID：playback.feedback.copy_failed
- 出现位置：Playback Center
- 动画：Default

#### 23. 台词长截图未就绪
- 英文：Collage Not Ready
- 简体中文：长截图未就绪
- 繁体中文：長截圖未就緒
- 图标：warning
- 持续时间：3秒
- Scenario ID：playback.feedback.collage_not_ready
- 出现位置：Playback Center
- 动画：Default

#### 24. 播放中台词不在媒体库中
- 英文：Cue Not in Library
- 简体中文：台词不在媒体库中
- 繁体中文：台詞不在資料庫中
- 图标：warning
- 持续时间：3秒
- Scenario ID：playback.feedback.not_in_library
- 出现位置：Playback Center
- 动画：Default
- 说明：在 Playback Overlay 中，当已播放视频已从媒体库移除，用户尝试保存到摘录或复制 Deep Link 时触发拦截。

---

### 4.3 播放器常规 HUD（1秒）

#### 25. 播放 / 暂停
- 英文：Play / Pause
- 简体中文：播放 / 暂停
- 繁体中文：播放 / 暫停
- 图标：play (fill) / pause (fill)
- 持续时间：1秒
- Scenario ID：playback.hud.play_pause
- 出现位置：Playback Center
- 动画：Default

#### 26. 自动暂停
- 英文：Auto Pause
- 简体中文：自动暂停
- 繁体中文：自動暫停
- 图标：pause (fill)
- 持续时间：1秒
- Scenario ID：playback.hud.auto_pause
- 出现位置：Playback Center
- 动画：Default

#### 27. 快进 / 快退
- 英文：+ {N}s / - {N}s
- 简体中文：+ {N}秒 / - {N}秒
- 繁体中文：+ {N}秒 / - {N}秒
- 图标：caretRight / caretLeft
- 持续时间：1秒（松手后）
- Scenario ID：playback.hud.seek
- 出现位置：Playback Center
- 动画：Default

#### 28. 音量调节与静音
- 英文：{volume}% / Muted
- 简体中文：{volume}% / 已静音
- 繁体中文：{volume}% / 已靜音
- 图标：speakerSimpleHigh / speakerSimpleLow / speakerSimpleX
- 持续时间：1秒
- Scenario ID：playback.hud.volume
- 出现位置：Playback Center
- 动画：Default

#### 29. 倍速调节
- 英文：{speed}x
- 简体中文：{speed}x
- 繁体中文：{speed}x
- 图标：speedometer
- 持续时间：1秒
- Scenario ID：playback.hud.speed
- 出现位置：Playback Center
- 动画：Default

#### 30. 字幕开关
- 英文：Subtitles On / Subtitles Off
- 简体中文：字幕已开 / 字幕已关
- 繁体中文：字幕已開 / 字幕已關
- 图标：subtitles
- 持续时间：1秒
- Scenario ID：playback.hud.subtitles
- 出现位置：Playback Center
- 动画：Default

#### 31. 全屏切换
- 英文：Enter Fullscreen / Exit Fullscreen
- 简体中文：进入全屏 / 退出全屏
- 繁体中文：進入全螢幕 / 結束全螢幕
- 图标：无
- 持续时间：1秒
- Scenario ID：playback.hud.fullscreen
- 出现位置：Playback Center
- 动画：Default

#### 32. 播放列表导航
- 英文：Previous Result / Next Result / Previous Library Video / Next Library Video / Previous Excerpt / Next Excerpt
- 简体中文：上一条结果 / 下一条结果 / 上一个媒体库视频 / 下一个媒体库视频 / 上一条摘录 / 下一条摘录
- 繁体中文：上一筆結果 / 下一筆結果 / 上一部媒體庫影片 / 下一部媒體庫影片 / 上一條摘錄 / 下一條摘錄
- 图标：caretLeft / caretRight
- 持续时间：1秒
- Scenario ID：playback.hud.navigation
- 出现位置：Playback Center
- 动画：Default

#### 33. 播放列表到达边界
- 英文：Already at First Result / Already at Last Result / Already at First Video / Already at Last Video / Already at First Excerpt / Already at Last Excerpt
- 简体中文：已经是第一个结果 / 已经是最后一个结果 / 已经是第一个视频 / 已经是最后一个视频 / 已经是第一条摘录 / 已经是最后一条摘录
- 繁体中文：已經是第一筆結果 / 已經是最後一筆結果 / 已經是第一部影片 / 已經是最後一部影片 / 已經是第一條摘錄 / 已經是最後一條摘錄
- 图标：caretLeft / caretRight
- 持续时间：1秒
- Scenario ID：playback.hud.navigation_edge
- 出现位置：Playback Center
- 动画：Default

#### 34. 播放列表无可用结果
- 英文：No Available Results
- 简体中文：没有可用的结果
- 繁体中文：沒有可用的結果
- 图标：warning
- 持续时间：1秒
- Scenario ID：playback.hud.no_available_results
- 出现位置：Playback Center
- 动画：Default
- 说明：播放列表中所有项目失效不可用时统一触发（Search 与 Excerpt 进入均统一为此提示）。

#### 35. 播放列表无可用视频
- 英文：No Available Videos
- 简体中文：没有可用的视频
- 繁体中文：沒有可用的影片
- 图标：warning
- 持续时间：1秒
- Scenario ID：playback.hud.no_available_videos
- 出现位置：Playback Center
- 动画：Default

---

## 五、任务队列与卡片操作（Task Toast）

### 36. 任务状态已经改变
- 英文：Task status has changed
- 简体中文：任务状态已经改变
- 繁体中文：任務狀態已經改變
- 图标：warning
- 持续时间：3秒
- Scenario ID：task.action.status_changed
- 出现位置：App Center
- 动画：Default
- 说明：在 Task 卡片弹出菜单打开期间，若任务状态已改变（如进行中转为已结束），用户点击移除任务时触发拦截报错。