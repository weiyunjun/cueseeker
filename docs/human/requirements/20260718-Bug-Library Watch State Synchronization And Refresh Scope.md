# 版本
main

# 需求描述
1. 状态同步问题：从Library或Recent入口进入一个视频，然后点击下一个视频按钮。如果该视频此前未观看，此时进入Overlay Library，会发现当前视频仍然显示Unwatched，状态没有更新。
2. 状态同步问题：Unwatched的视频，点击观看，按下回车键，Overlay Recent界面没有更新该视频，Overlay Library界面该视频仍显示Unwatched。
3. 状态同步问题潜在风险：1. 定时保存进度及达到完成点时只写数据库，不通知共享Store。进入Overlay时可能看到旧进度或旧观看状态。2. Library切换到Search/Shiori后关闭播放，状态可能长期不刷新。3. Search Scope 的结果也可能陈旧。
4. 异常刷新问题：在Library二级界面，右键菜单标记观看状态，会异常触发整个界面刷新。