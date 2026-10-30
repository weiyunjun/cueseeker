# 版本

main

# 需求描述

1. **Debug 与 Release 日志目录隔离与按日轮转清理**：
   - 按编译模式将本地日志分别存放在 `~/Library/Application Support/CueSeeker/logs/release/`（Release 正式构建，含打包生成的 `.app`）与 `~/Library/Application Support/CueSeeker/logs/debug/`（Debug 调试构建）目录下；单元测试与集成测试运行期间不写入本地日志文件。
   - 日志文件按自然日保存，命名为 `cueseeker-YYYY-MM-DD.log`；单个日志文件大小上限为 10 MB（超出上限时自动裁剪旧记录）；应用启动时自动清理超过 14 天的历史日志文件。
   - 将原有的长截图耗时日志（`collage-performance.log`）合并至日常日志中，不再单独生成独立日志文件。

2. **日志格式、级别与业务分类**：
   - 单条日志采用单行纯文本结构化格式：`YYYY-MM-DD HH:mm:ss.SSS [LEVEL] [Category] Message | key=value ...`。
   - 日志级别分为 `ERROR`、`WARN`、`INFO`、`DEBUG` 四级：Release 构建记录 `INFO`、`WARN`、`ERROR` 三级日志；Debug 构建记录全部四个级别日志。
   - 业务模块分类划分为 `App`（应用启动/退出与系统环境）、`Database`（数据库初始化、迁移、压缩维护与读写异常）、`Task`（添加文件夹、索引扫描、重命名、移除文件夹等后台任务结果与耗时）、`Playback`（媒体打开、解码模式选择与回退、音轨/字幕切换、长截图生成各阶段耗时及播放异常）、`Export`（Anki 导出、长截图复制与导出结果及耗时）、`Network`（SMB / NFS / FTP / WebDAV 连接与读取异常）、`System`（URL Scheme 唤醒、手柄连接与断开、系统内存告警等）。

3. **日志记录范围与隐私合规边界**：
   - 记录应用启动环境信息、关键业务操作生命周期与耗时统计、长截图生成耗时拆解，以及各模块异常与降级警告。
   - 严禁在日志中记录账号密码等敏感凭证、用户搜索词（Query）、字幕台词正文及高频界面刷新事件。

# 验收标准

1. 运行打包后的 Release 版本与开发 Debug 版本时，日志分别写入 `logs/release/cueseeker-YYYY-MM-DD.log` 与 `logs/debug/cueseeker-YYYY-MM-DD.log`，互不混杂；超过 14 天的旧日志在启动时自动清理。
2. 应用启动、执行后台任务、播放视频、切换解码/音轨/字幕、生成与导出长截图、导出 Anki 及发生异常时，日志文件按规范格式实时记录对应的级别、模块分类、关键参数与耗时信息，且不再单独生成 `collage-performance.log`。
3. 日志内容不包含任何密码凭证、搜索词或台词正文；执行完整单元测试与集成测试（`swift test`）全部通过且零磁盘日志残留。