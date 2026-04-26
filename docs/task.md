# SubFinder (Flutter 重构版) 立项与架构设计文档

## 1. 项目概述

### 1.1 项目目标
本项目旨在利用 Flutter 桌面端技术栈重构现有的 SubFinder 字幕搜索引擎。核心目的是彻底解决原 Electron 架构下 H.265/VP9 等复杂视频编码的本地播放兼容性问题，同时提升海量字幕数据的检索性能与应用整体的资源利用率，并为后期扩展“单词本”、“Anki 联动”等个人知识管理功能奠定底层基础。

### 1.2 目标平台
* 主要平台：macOS (Apple Silicon / Intel)
* 次要平台：Windows 10/11 (x64)

---

## 2. 技术栈与架构选型

本架构全面抛弃 Web 技术栈（DOM/JS/Chromium），转为基于 AOT 编译与自绘引擎的单进程架构。

| 模块 | 技术选型 | 选型依据 |
| :--- | :--- | :--- |
| **核心框架** | Flutter (Dart) | 桌面端 AOT 编译，高性能 UI 渲染（Skia/Impeller），单一语言心智负担低。 |
| **音视频引擎** | `media_kit` (基于 libmpv) | 通过 Dart FFI 零拷贝渲染，完美支持 H.265/VP9 硬件解码，跨平台表现一致。 |
| **本地数据库** | `sqlite3` (Dart FFI) | 直接调用系统原生 SQLite C 库，支持 FTS5 全文检索引擎。 |
| **状态管理** | `Riverpod` (推荐) / `Provider` | 响应式状态管理，适合处理跨组件的播放器状态与字幕列表联动。 |
| **持久化存储** | `shared_preferences` / `path_provider` | 轻量级配置读取（如：字幕库路径、主题设置）。 |

---

## 3. 核心功能实现路径

### 3.1 双视图 UI 架构设计

在 Flutter 中，视图切换不依赖多窗口，而是通过局部组件树的替换来实现单页面应用（SPA）体验。

* **List View（默认列表视图）**：
  * 使用 `TextField` 配合 `debounce` 控制器实现防抖搜索。
  * 使用 `ListView.builder` 实现搜索结果的按需加载（天然等同于虚拟滚动，无性能瓶颈）。
* **Two-Pane View（双栏播放视图）**：
  * **布局结构**：顶层使用 `Row`，左侧 `Expanded(flex: 3)` 放置字幕流，右侧 `Expanded(flex: 7)` 放置视频播放器。
  * **左侧字幕流**：预先加载该视频全量字幕记录至内存。通过 `ScrollController` 监听右侧播放器时间进度，实现自动滚动（Auto-scroll）与当前句高亮。
  * **右侧播放器**：基于 `Video` widget（来自 `media_kit_video`），隐藏原生控制条，在上层 `Stack` 叠加自定义的播放控件与字幕蒙层。

### 3.2 视频播放引擎整合 (`media_kit`)

1. **初始化**：在 `main.dart` 入口调用 `MediaKit.ensureInitialized()` 初始化底层 libmpv 环境。
2. **实例管理**：创建 `Player` 实例并将其状态注入全局（Riverpod `Provider`）。
3. **精准跳转**：接收到列表项点击事件后，调用 `player.open(Media('file://path/to/video.mp4'))`，随后立即调用 `player.seek(Duration(milliseconds: timestamp))`。
4. **内置字幕处理**：关闭 `libmpv` 默认的字幕渲染（防止画面出现系统自带字幕），完全由 Flutter UI 层通过监听 `player.stream.position` 从数据库读取对应文本并在 `Stack` 中渲染，以保证后期划词、高亮等交互的绝对控制权。

### 3.3 数据库与全文检索架构

1. **建表策略**：
   * 主表 `subtitles`：存储 `id`, `video_id`, `start_time`, `end_time`, `content`。
   * 虚拟表 `subtitles_fts`：使用 **FTS5** 引擎建立倒排索引，并使用 `tokenize = 'unicode61'` 或自定义分词器以支持多语言复合搜索。
2. **异步查询 (Isolate)**：
   * 必须使用 `compute` 函数或手动 `Isolate.spawn` 将耗时的数据库全文检索操作移出 UI 线程。
   * 查询结果序列化为 Dart 实体类 List 后，通过 Port 传回主线程渲染，确保输入框不卡顿。
3. **增量索引器**：
   * 使用后台 Isolate 遍历本地目录。由于去除了 Node.js 的 fs 模块，将使用 Dart原生 `Directory` 与 `File` API 进行递归扫描和正则匹配解析 SRT 文件。

---

## 4. 工程化与性能调优关键点

### 4.1 FFI 内存管理
使用 `sqlite3` 和 `media_kit` 时，本质上是在通过 FFI 操作 C/C++ 指针。必须严格管理生命周期：
* 切换视频或销毁双栏视图时，必须调用 `player.dispose()` 释放底层解码器资源。
* 退出应用前，调用 `db.dispose()` 安全关闭数据库连接，防止 WAL 损坏。

### 4.2 文本渲染性能约束
Flutter 的强项在于图形渲染，弱项在于超长富文本。
* **避免滥用富文本**：如果需要对搜索关键词进行高亮，应在数据解析层将字符串切片为 `TextSpan` 数组，不要在每次 `build` 时进行正则表达式匹配。
* **按需渲染**：左侧的双栏字幕流必须且只能使用 `ListView.builder`，千万不要将两千句字幕直接放入 `SingleChildScrollView`。

### 4.3 状态隔离
视频播放的进度回调频率极高（每秒数十次更新）。
* **UI 重绘隔离**：绝对不能将 `currentTime` 的状态放在父级 Widget 中导致整个页面重绘。应使用 `ValueNotifier` 或细粒度的状态管理（如 Riverpod 的 `select`），仅让控制条进度条和当前字幕高亮框进行局部重绘。

---

## 5. 潜在技术风险与应对策略

| 风险点 | 描述 | 应对策略 |
| :--- | :--- | :--- |
| **包体积膨胀** | `media_kit` 静态链接 `libmpv` 会导致应用打包后体积显著增加。 | 在生产环境编译时，合理使用 Flutter 的 `--split-debug-info` 和 `--obfuscate` 参数。考虑到桌面端存储宽裕，50-100MB 属于可接受范围。 |
| **桌面端快捷键劫持** | 播放器的全局快捷键（如空格暂停、方向键快进）可能与输入框搜索产生冲突。 | 使用 `FocusScope` 严格管理焦点。只有当播放器区域获得焦点时，才响应快捷键事件；当处于搜索框时，拦截快捷键。 |
| **文本交互手感局限** | Flutter 的鼠标划词选择、右键菜单手感不如原生浏览器 DOM。 | 后期开发“单词本”划词功能时，需深入定制 `SelectionArea`，或使用叠加的点击事件层来模拟精确的单词级点击判定。 |

---

## 6. 后期演进接口预留

在数据层和 UI 层设计时，需为未来功能预留接口：

1. **数据模型扩展**：为 `subtitles` 表预留 `is_starred` (收藏) 字段。设计独立的 `vocabulary` (生词库) 表，通过 `subtitle_id` 进行外键关联。
2. **网络层解耦**：封装独立的 `AnkiService` 类，利用 `http` 库预留对本地 `http://localhost:8765` (AnkiConnect) 的 JSON-RPC 请求接口。
3. **UI 拓展插槽**：在右侧播放器的 `Stack` 层预设一个空置的 `WidgetBuilder`，以便未来挂载翻译弹窗或生词卡片预览面板。