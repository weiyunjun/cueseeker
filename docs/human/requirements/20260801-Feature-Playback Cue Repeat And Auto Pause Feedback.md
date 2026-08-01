# 版本
main

# 需求描述
1. 当且仅当：位于视频播放界面，在Cue Playlist中，当前时间戳位于目标字幕的时间戳范围（左右都是闭区间），关闭Auto Switch to Next Cues in Playlist。允许重播该句，即seek到目标字幕的开始时间戳并播放。
2. 在播放器UI的截图按钮左侧新增一个Repeat按钮，图标用SF Symbol repeat。点击该按钮可以触发该功能。也可以通过键盘的R键或者手柄的Triangle键触发。
3. 当Auto Pause生效时，需要有居中的屏幕提示，参考Pause的提示，只是文字更换为Auto Pause。
4. 当重播生效时，需要有居中的屏幕提示，图标用重播的图标，文字是Repeat。
5. 当不满足重播条件时，重播按钮进入disable状态。此时按手柄的Triangle键没有屏幕提示，静默不执行。
