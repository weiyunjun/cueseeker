# ASS字幕处理
1. 只处理[Events] section中的Dialogue事件。
2. ASS Text 中 {...} 花括号里的override tag会被移除。
3. 换行符（\N，\n）会转成换行。
4. 文本的开头和结尾的空白会删除。
5. 排除所有时间戳长度小于200ms的字幕。
6. clean 后如果为空，这条字幕不进入可搜索cue索引。
7. 到这一步，经过清理后完全一致（时间戳，文本，以及保留字段）的字幕，做去重处理。

# 非ASS字幕处理
1. 文本的开头和结尾的空白会删除。
2. 排除所有时间戳长度小于200ms的字幕。
3. clean 后如果为空，这条字幕不进入可搜索cue索引。
4. 到这一步，经过清理后完全一致（时间戳，文本）的字幕，做去重处理。

# Cue Group
1. 经过# ASS字幕处理后得到的，位于同一SubtitleID下的Cue，如果时间戳完全相同，则被视为互相处于一个Cue Group中。
2. 经过# 非ASS字幕处理后得到的，每一个Cue均位于一个只包含自身的Cue Group中。

# ASS字幕变化检测
经过# ASS字幕处理得到的Cue的身份划分为四部分：Style，时间戳（开始与结束时间），文字内容，其余Dialogue字段（例如 Layer、Name、Margins、Effect）。

## 处理流程
1. 先对同一SubtitleID下，旧版本的经过# ASS字幕处理得到的Cue+Tombstone中的Cue，和新版本的经过# ASS字幕处理得到的Cue做四部分完全匹配。完全匹配的Cue立即锁定并复用原CueID。
2. 同一SubtitleID下，旧版本剩余的Cue+Tombstone中的Cue，和新版本剩余的Cue，进行匹配。匹配规则是，考察Style，时间戳，文字内容，其余Dialogue字段，是否在Style相同的前提下，剩余3个部分有且只有1个部分存在不同，且在同一个SubtitleID下，如果是，则匹配成功。
3. 如果某个旧版本剩余的Cue或Tombstone中的Cue，只有唯一的匹配关系，且它匹配的对象，新版本剩余的Cue，也只有唯一的匹配关系。那么，新版本剩余的Cue继承旧版本剩余的Cue或Tombstone中的Cue的CueID，以及CueID的关联关系。
4. 不满足第3点条件的新版本剩余的Cue，会自动获得新的CueID。不满足第3点的旧版本剩余的且位于至少一个Excerpt List中的Cue，进入Tombstone。不满足第3点的旧版本剩余的且不位于Excerpt List中的Cue，直接删除。不满足第3点的Tombstone中的Cue，留在Tombstone中。满足第1点或第3点的Cue，离开Tombstone。
5. 对于不满足第3步条件的旧版本的Cue，如果位于至少一个Excerpt List中，会标记为失效。失效后的重新绑定，后续再做。

## 注意事项
1. 无需特别处理2条Cue的Style互换的极端情况，这不属于算法应该考虑的范围。

# 非ASS字幕变化检测
经过# 非ASS字幕处理得到的Cue的身份划分为两部分：时间戳（开始与结束时间），文字内容。

## 处理流程
1. 先对同一SubtitleID下，旧版本的经过# 非ASS字幕处理得到的Cue+Tombstone中的Cue，和新版本的经过# 非ASS字幕处理得到的Cue做两部分完全匹配。完全匹配的Cue立即锁定并复用原CueID。
2. 同一SubtitleID下，旧版本剩余的Cue+Tombstone中的Cue，和新版本剩余的Cue，进行匹配。匹配规则是，考察时间戳，文字内容，是否在2个部分有且只有1个部分存在不同，且在同一个SubtitleID下，如果是，则匹配成功。
3. 如果某个旧版本剩余的Cue或Tombstone中的Cue，只有唯一的匹配关系，且它匹配的对象，新版本剩余的Cue，也只有唯一的匹配关系。那么，新版本的Cue继承旧版本剩余的Cue或Tombstone中的Cue的CueID，以及CueID的关联关系。
4. 不满足第3点条件的新版本剩余的Cue，会自动获得新的CueID。不满足第3点的旧版本剩余的且位于至少一个Shiori List中的Cue，进入Tombstone。不满足第3点的旧版本剩余的且不位于Shiori List中的Cue，直接删除。不满足第3点的Tombstone中的Cue，留在Tombstone中。满足第1点或第3点的Cue，离开Tombstone。
5. 对于不满足第3步条件的旧版本的Cue，如果位于至少一个Shiori List中，会标记为失效。失效后的重新绑定，后续再做。
