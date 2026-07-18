# 版本
main

# 需求描述
1. 修改Only Play Cues in Playlist的实现，改名为Auto Stop After a Cue Finishes。不要强制只播放这一句，而是修改实现为暂停在字幕所属的最后一个有效画面。
2. 修改Auto Switch to Next Cues in Playlist的实现，保留名称，但是它应该在代码架构上是基于Auto Stop After a Cue Finishes的拓展功能。即暂停后等待若干毫秒自动播放下一个结果。
3. 状态同步问题：Overlay Playlist没有正确反映当前字幕。这里应该建立一个索引，当打开Overlay Playlist时，默认渲染当前字幕。参考Workbench界面的Context的表格实现。
4. 第3点的当前字幕，不是严格意义上当前正在播放的字幕，而是反应Playlist的逻辑状态。换言之，用户可以关闭Auto Stop After a Cue Finishes，然后一直播放下去，但是这不影响Overlay Playlist的焦点字幕结果。

# 注意事项
1. Auto Stop After a Cue Finishes开启，触发自动暂停后，按下空格键会继续播放而不是重播当前Cue。
2. 本次改动需要打包出来测试，因为涉及到URL Scheme刚刚添加的功能测试。