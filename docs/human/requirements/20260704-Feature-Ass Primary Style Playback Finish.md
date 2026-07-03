# 版本
main

# 需求描述
1. 在index阶段，处理好ASS字幕的Primary Style。
2. 第一步，合并时间戳完全一致的时间戳，合并后的时间戳的Style，取合并前的所有非空Style。第二步，找出所有时间戳没有和任何其它时间戳有大于等于1ms交集的时间戳。第三步，统计第二步得到的时间戳对应的Style，数量最多的作为Primary Style，允许多个Primary Style或不存在Primary Style（例如ASS字幕本身就是空的或极其混乱）。
3. 修改视频finished判定规则。1. 最后一句Primary Style的结束时间戳存在且大于等于视频时长的80%，该结束时间戳作为finished判定点。2. Primary Style不存在或最后一句Primary Style的结束时间戳存在且小于视频时长的80%，且最后一句字幕的结束时间戳大于等于视频时长的80%，以最后一句字幕的结束时间戳finished判定点。3. Primary Style不存在或最后一句Primary Style的结束时间戳存在且小于视频时长的80%，且最后一句字幕的结束时间戳小于视频时长的80%，需要播放完才判定为finished。
4. 修改代码后，不需要修改已有的unwatched/watching/finished数据。