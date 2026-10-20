# 版本

main

# 关联设计

- `docs/human/design/ui/UI Tokens.md`
- `docs/human/design/ui/UI Components - Domain.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/ui/UI Layouts - Playback.md`

# 需求描述

1. **全 App 统一 Spinner 视觉样式与尺寸 Token（`C-09.4 Spinner`）**：
   - 所有加载、计算与执行中的旋转指示器统一使用 `C-09.4 Spinner` 样式：静止底环（`--color-spinner-track`）搭配四分之一圆弧指示器（`--color-spinner-indicator`）以 `--duration-spinner-motion`（`1s`）、`--easing-spinner-motion`（`linear`）匀速旋转。
   - 所有场景下的 Spinner 尺寸与线宽统一收敛至标准 Token：`--size-spinner`（`16px`）、`--width-spinner-stroke`（`2px`），移除系统原生菊花样式及局部 `18px` 尺寸特例。

2. **各界面统一范围**：
   - **原系统菊花替换为 `16px` 圆环 Spinner**：
     - **Recent 页面**：`Recent Videos` 与 `Recent Excerpt Lists` 加载期间的居中指示器；
     - **Library 页面**：一级文件夹总览页与二级文件夹详情页加载期间的居中指示器；
     - **Excerpt 页面**：一级摘录集总览页加载期间的居中指示器；
     - **Playback Overlay 播放列表**：视频播放列表加载期间的居中指示器；
     - **Settings 设置窗口**：`Maintenance` 页（加载存储统计、压缩数据库）与 `Developer` 页（加载词表诊断数据）状态文字左侧的指示器。
   - **既有 `18px` 圆环 Spinner 统一改为 `--size-spinner`（`16px`）**：
     - **File 页面**：顶部状态栏进行中状态（如 `Indexing...`、`Removing...`）文字左侧的 Spinner，以及二级、三级目录异步加载期间的列表居中 Spinner；
     - **远程文件夹弹窗（WebDAV / SMB / FTP / NFS）**：第二步目录浏览加载子目录期间的列表居中 Spinner（第一步 `Connect` 按钮与筛选弹窗 `Calculating` 按钮内的 Spinner 保持 `--size-spinner: 16px` 不变）。

# 验收标准

1. Recent、Library、Excerpt、Playback Overlay 播放列表、Settings（Maintenance 与 Developer）在加载状态下均展示圆环 Spinner，App 内不再出现系统原生菊花指示器。
2. File 页面、远程文件夹弹窗（WebDAV / SMB / FTP / NFS）、筛选弹窗及上述全部界面的圆环 Spinner 尺寸（`16px`）、线宽（`2px`）、明暗模式配色与旋转动效完全一致。