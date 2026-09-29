# 版本

main

# 需求目标

将数据库中所有媒体及相关数据的存储路径前缀从 `/Volumes/Samsung/影视` 批量替换为 `/Volumes/Seagate/影视`。

# 需求

1. 路径批量更新：将 SQLite 数据库中所有引用的 `/Volumes/Samsung/影视` 路径前缀更新为 `/Volumes/Seagate/影视`。
2. 涉及更新的表与字段：
   - `search_paths`: `path`
   - `subtitle_files`: `subtitle_path`
   - `video_files`: `path`
   - `subtitle_cue_groups`: `subtitle_path`
   - `library_video_rows`: `video_path`, `subtitle_path`, `folder_path`
   - `subtitle_search_order_rows`: `subtitle_path`, `folder_path`
   - `cue_tombstones`: `subtitle_path`, `video_path`
   - `subtitle_playback_finish_metadata`: `subtitle_path`
   - `folder_covers`: `folder_path`
   - `user_folder_covers`: `folder_path`
   - `task_records`: `folder_path`, `old_paths`, `new_paths`
   - `cue_facet_counts`: `value`
3. 安全保障：执行修改前自动对当前数据库创建带时间戳的备份文件。
4. 完整性：保持原有主键、外键约束、索引及关联关系不变。

# 验收

1. 数据库相关表中不再存在包含 `/Volumes/Samsung/影视` 的记录，全部对应更新为 `/Volumes/Seagate/影视`。
2. App 启动后，资料库列表、搜索、摘录以及视频播放均能正常读取新路径下的媒体与字幕。