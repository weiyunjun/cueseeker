# 版本
main

# 需求描述
删除历史功能，Speaker和AI Chunking，具体包括：
1. 数据库迁移删除 Speaker 表和 AI Cache 表。
2. 删除 Speaker 与 AI Chunking 的全部功能链路。
3. 主动清除 DeepSeek Keychain 凭据及相关 UserDefaults。
4.不影响 Cue、Language、Shiori Tag、字幕播放和其他搜索筛选能力。