# 版本

main

# 关联设计

- `docs/human/design/data/Data.md`
- `docs/human/design/workbench/Library and File.md`
- `docs/human/design/playback/Playback Core.md`

# 需求描述

1. **四种网络协议（WebDAV、SMB、FTP、NFS）统一视频流请求方式**：
   - 除本地文件夹直接读取本机磁盘文件外，WebDAV、SMB、FTP、NFS 四种网络协议在视频播放、Seek 跳转、视频信息读取、自动封面生成、截图/拼图及 Anki 导出中，统一采用与 WebDAV 一致的「单次流请求对应单条持续数据流」方式。
   - 每次打开视频或发起 Seek 跳转时，从目标起始位置建立一次连接并持续顺序推送后续视频数据流，直至播放器读取完成或下一次跳转主动断开，中途不再按固定大小切片断开并重复重连。

# 验收标准

1. WebDAV、SMB、FTP、NFS 四种网络协议下的视频播放、Seek 跳转、封面生成、截图/拼图与 Anki 导出均采用统一的持续流式请求方式。
2. 同一远程视频在 FTP 与 NFS 方式下进行播放与连续 Seek 跳转时，响应速度与 WebDAV、SMB 方式保持一致，不再出现明显卡顿。