# 版本
main

# 需求描述

## 改名
1. Auto Stop After a Cue Finishes改名为Auto Pause After a Cue Finishes。

## seek规则
1. seek不改变Playlist索引。
2. seek本身不触发Auto Pause，即使跨过或落在停止时间戳。
3. 只有从时间戳之前自然播放到时间戳时才触发。
4. Auto Pause后手动继续播放，不得立即再次暂停。
5. 只有播放位置重新回到时间戳之前，才重新准备Auto Pause。
6. 同一视频中即使包含多个Playlist Cue，也只处理当前索引对应的时间戳。

## 操作规则
明确并调整Auto Pause和Auto Switch的操作规则。

| 用户操作 | Auto Pause 时间戳 | 等待中的 Auto Switch |
|---|---|---|
| seek、拖进度条、前后跳转 | 保留 | 取消 |
| 手动播放或暂停 | 保留 | 取消 |
| 进入 Overlay | 保留 Playlist 状态 | 取消 |
| Playlist 下一项/上一项 | 替换为新索引的时间戳 | 取消旧任务 |
| 播放其他搜索结果、Shiori 或 Library 内容 | 清除旧 Playlist 规则 | 取消 |
| 音量、字幕显示、窗口操作 | 不影响 | 不影响 |

## 验证
1. Auto Pause触发时要验证：仍是同一个Playlist Item、设置仍开启，否则不得自动暂停。
2. 在Auto Switch倒计时结束时要重新验证：仍是同一个Playlist Item，倒计时仍属于最近一次有效的Auto Pause事件，仍因该事件保持暂停，没有进入Overlay，Auto Pause与Auto Switch均保持开启，否则不得切换。

## Playlist状态初始化
1. 以上提到的影响Auto Pause和Auto Switch的操作（## 操作规则），只对当前Playlist Item有效，不修改Auto Pause或Auto Switch的设置值。
2. 当前Playlist索引成功改变时，应清除旧Item的Auto Pause运行状态和等待中的Auto Switch任务，并按照当前设置为新Item初始化。
3. 这意味着，哪怕之前用户通过非设置界面的操作，例如seek到某个位置，取消了Auto Switch，在索引成功改变并初始化以后，也会根据持久化的设置，初始化Auto Pause和Auto Switch。