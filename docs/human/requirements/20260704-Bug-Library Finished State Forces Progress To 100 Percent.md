# 版本
main

# 需求描述
修复回归Bug：
Finished 只表示观看完成标志，不改变播放进度显示。
Library 卡片进度条和时间 Badge 必须始终使用真实 positionMilliseconds。
即使状态为 Finished，也不能把进度条或时间显示强制渲染为 100% / 视频总时长。