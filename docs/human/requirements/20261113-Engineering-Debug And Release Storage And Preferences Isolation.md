# 版本

main

# 关联设计

- 无。本需求仅将 Debug 与 Release 构建的本地数据存储、缓存与偏好设置对称隔离，不改变任何界面、图标或产品功能语义。

# 需求描述

1. **本地应用数据与缓存目录对称隔离**：
   - 按编译模式将本地应用数据目录对称划分为 `~/Library/Application Support/CueSeeker/release/`（Release 正式构建）与 `~/Library/Application Support/CueSeeker/debug/`（Debug 调试构建）；各自的数据库文件、封面目录与远程文件夹字幕缓存均独立存放在对应环境目录下，不再直接存放在 `~/Library/Application Support/CueSeeker/` 根目录。
   - 系统缓存目录按编译模式对称划分为 `~/Library/Caches/CueSeeker/release/` 与 `~/Library/Caches/CueSeeker/debug/`。
   - 运行日志目录维持现有的 `~/Library/Application Support/CueSeeker/logs/release/` 与 `~/Library/Application Support/CueSeeker/logs/debug/` 不变。

2. **本地偏好设置对称隔离**：
   - 按编译模式将本地偏好设置独立划分为 `release` 与 `debug` 两套互不共享的配置空间（包含已添加文件夹列表、远程连接信息、上次更新时间、筛选与排序状态、外观语言、播放与快捷键设置等），并移除历史遗留的旧版配置自动合并逻辑；两套环境首次启动均从各自干净的初始状态开始，修改任一环境的文件夹或设置均不影响另一环境。
   - 自动化测试继续使用独立的临时测试目录与临时配置空间，不读写、不污染 `release` 或 `debug` 环境数据。

3. **跨环境并行运行与同环境单实例保护**：
   - 允许正式版与命令行调试版同时运行；同一编译环境内部各自保持单实例保护，重复启动同一环境时自动激活已运行的对应窗口并退出，防止同一环境的多个进程并发读写同一数据库。
   - 外部链接跳转、应用界面与图标维持现状不变。

# 验收标准

1. **存储与配置完全隔离**：分别启动 Release 构建与 Debug 构建时，各自的数据库、封面、远程字幕缓存、系统缓存及偏好设置严格读写对应的 `release` 与 `debug` 空间，在任一环境中增删改文件夹、修改封面或调整设置均不影响另一环境；日志继续按既有规则分别写入 `logs/release/` 与 `logs/debug/`。
2. **并行运行与防双开生效**：Release 构建与命令行 Debug 构建可同时正常运行互不拦截；在同一环境已运行时再次启动该环境，自动唤起已运行的对应窗口并退出。
3. **测试隔离零残留**：运行完整自动化测试套件全部通过，且不会在 `release`、`debug` 数据目录、日志目录或偏好设置中产生任何测试残留。