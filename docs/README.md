# SubFinderX

SubFinderX 是一个基于 Flutter macOS 的桌面字幕检索与视频联动播放器。它的核心目标不是“管理字幕文件”，而是把大量本地或 WebDAV 目录中的 `.srt` 字幕建立成可全文检索的数据库，然后让用户在搜索到一句台词后，直接跳到对应视频的对应时间点开始播放。

这份 README 的目标是让 LLM 或新开发者在不打开源码的情况下，也能大致理解项目结构、核心数据流、每个模块的职责，以及主要类、函数、Provider、状态对象的作用。

## 1. 项目一句话概览

可以把整个项目理解成 5 层：

1. 输入层：用户在搜索框输入关键字，或者在设置页添加本地/WebDAV 路径。
2. 索引层：`IndexerService` 扫描 `.srt` 文件，解析成字幕条目，写入 SQLite + FTS5。
3. 检索层：`SearchService` 把用户输入转换成 FTS 查询语句，返回字幕命中结果。
4. 状态层：Riverpod 负责管理“当前关键词”“当前搜索结果”“当前被点击的字幕”“全局播放器实例”等状态。
5. 播放层：`VideoPlayerPane` 根据字幕条目决定是本地直读、WebDAV 下载、本地缓存、AList 签名直链，还是本地 HTTP 代理，再调用 `media_kit/libmpv` 播放。

## 2. 主要功能

- 搜索本地目录中的 `.srt` 字幕。
- 搜索 WebDAV 目录中的 `.srt` 字幕。
- 自动尝试把字幕文件与同目录同名视频匹配。
- 使用 SQLite FTS5 做全文检索。
- 对中文/CJK 文本做简单字符分段，提升 FTS 命中率。
- 点击字幕结果后，直接打开对应视频并跳转到对应毫秒位置。
- 同一视频内再次点击其他字幕时，只做 `seek`，不重新打开视频。
- 支持独立设置窗口，持久化搜索路径。
- 支持 AList API，将 WebDAV 路径转换成播放器更容易消费的签名下载链接。
- 支持本地代理和本地缓存，规避某些带鉴权或非 ASCII URL 的播放问题。

## 3. 技术栈

- UI 框架：Flutter
- 语言：Dart
- 状态管理：`flutter_riverpod`
- 视频播放：`media_kit` + `media_kit_video` + 底层 `libmpv`
- 数据库存储：`sqlite3`
- 全文检索：SQLite FTS5
- 多窗口：`desktop_multi_window`
- 本地配置：`shared_preferences`
- 文件夹选择：`file_selector`
- 应用支持目录：`path_provider`
- 远程目录读取：`webdav_client`

## 4. 仓库结构

下面只列出理解项目所需的关键文件，忽略 `build/` 等生成物。

```text
SubFinderX/
├── README.md
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── search_path_entry.dart
│   │   └── subtitle.dart
│   ├── providers/
│   │   └── database_provider.dart
│   ├── services/
│   │   ├── alist_api_service.dart
│   │   ├── database_service.dart
│   │   ├── indexer_service.dart
│   │   ├── local_stream_proxy_service.dart
│   │   └── search_service.dart
│   ├── view_models/
│   │   ├── player_view_model.dart
│   │   └── search_view_model.dart
│   └── ui/
│       ├── home_page.dart
│       ├── settings_window.dart
│       └── components/
│           ├── action_feedback_overlay.dart
│           ├── result_list_widget.dart
│           ├── search_bar_widget.dart
│           └── video_player_pane.dart
├── docs/
│   ├── README.md
│   ├── implementation_plan.md
│   ├── task.md
│   └── walkthrough.md
├── test_indexer.dart
├── test_indexer_db.dart
└── test_indexer_dir.dart
```

## 5. 整体运行流程

### 5.1 应用启动流程

1. `main()` 先执行 `WidgetsFlutterBinding.ensureInitialized()`。
2. 如果命令行参数第一个值是 `multi_window`，说明当前进程不是主窗口，而是设置窗口。
3. 设置窗口模式下，会解析 `windowId` 和 JSON 参数，启动 `SettingsWindowApp`。
4. 如果不是设置窗口，主程序会先调用 `MediaKit.ensureInitialized()`，确保底层媒体库被加载。
5. 然后用 `ProviderScope` 包裹整个应用，启动 `MyApp`。
6. `MyApp` 在 `build()` 中读取 `databaseInitProvider`。
7. `databaseInitProvider` 内部会触发 `DatabaseService.init()`。
8. 数据库初始化完成后，首页显示 `HomePage`；初始化中显示 loading；失败则显示错误。

### 5.2 搜索流程

1. 用户在 `SearchBarWidget` 输入文本。
2. 文本变化后写入 `searchKeywordProvider`。
3. `searchResultsProvider` 监听关键词变化，先做 300ms 防抖。
4. 防抖结束后，调用 `SearchService.search()`。
5. `SearchService` 会把关键词转成 FTS 查询语法。
6. SQLite FTS5 执行 `MATCH` 查询。
7. 查询结果转换成 `SubtitleEntry` 列表。
8. `ResultListWidget` 订阅这个 Provider，把结果渲染成可点击列表。

### 5.3 点击结果后的播放流程

1. 用户点击某条字幕结果。
2. `ResultListWidget` 把这一条 `SubtitleEntry` 写入 `activeSubtitleProvider`。
3. `VideoPlayerPane` 监听 `activeSubtitleProvider`。
4. 如果是首次进入播放面板，`initState()` 会主动读取当前激活字幕，处理首击场景。
5. `_handlePlayback()` 根据 `SubtitleEntry.videoPath` 判断是本地文件还是远程 URL。
6. 如果是远程 URL，会尝试：
   - 映射到本地已挂载路径。
   - 通过 AList API 获取签名直链。
   - 对非 ASCII 路径做本地缓存下载。
   - 或注册到本地代理服务转发。
7. 播放器调用 `player.open()` 打开视频，并从 `startMs` 开始播放。
8. 同时 `_loadSubtitleForEntry()` 显式加载 `.srt` 到 mpv。
9. 如果用户在同一视频下点击另一句字幕，只执行 `player.seek()` + `player.play()`。

### 5.4 路径设置与重建索引流程

1. 用户点击搜索栏右侧齿轮按钮。
2. 创建一个新的独立窗口，显示 `SettingsPage`。
3. 设置页读取 `SharedPreferences` 中的 `search_paths`。
4. 用户添加或删除本地/WebDAV 路径。
5. 设置页保存新的路径数组。
6. 保存后，通过 `desktop_multi_window` 给主窗口发送 `reindex` 方法调用。
7. 主窗口的 `SearchBarWidget` 收到 `reindex`。
8. `_handleReindex()` 逐个路径调用 `IndexerService.indexDirectory()`。
9. 索引结束后，重新触发当前搜索词搜索，刷新结果列表。

## 6. 核心数据模型

### 6.1 `lib/models/subtitle.dart`

这个文件定义了索引后和查询结果中最重要的数据结构。

#### `class SubtitleEntry`

表示一条已经解析完成并可用于搜索、展示、跳转播放的字幕记录。

字段说明：

- `id`
  - SQLite 主键。
  - 本地数据库写入后生成。
  - 也是 FTS 表 `rowid` 关联主表的关键字段。
- `videoPath`
  - 对应视频文件路径。
  - 可能是本地文件路径，也可能是 WebDAV URL。
- `videoName`
  - 展示给用户看的文件名，通常来自 `basename(videoPath)`。
- `srtPath`
  - 字幕文件路径。
  - 用于增量索引、缓存、删除旧记录、下载远程字幕。
- `seq`
  - 原始 `.srt` 里的字幕序号。
- `startTime`
  - 原始起始时间文本，如 `00:01:23,456`。
- `endTime`
  - 原始结束时间文本。
- `startMs`
  - 把 `startTime` 转成毫秒后的整数值。
  - 播放跳转时直接使用。
- `content`
  - 字幕正文。
  - 是搜索展示、FTS 索引和高亮的核心字段。

构造与方法：

- `SubtitleEntry(...)`
  - 普通构造函数。
  - 创建一个完整字幕条目。
- `factory SubtitleEntry.fromRow(Map<String, dynamic> row)`
  - 把 SQLite 查询结果的一行转换成 `SubtitleEntry`。
  - `SearchService.search()` 查询完成后主要依赖它做模型映射。

#### `class IndexMeta`

表示一个字幕文件上次被索引时的元数据。

字段说明：

- `srtPath`
  - 字幕文件唯一标识。
- `fileSize`
  - 文件大小。
- `modifiedAt`
  - 文件最后修改时间。

这个类在当前代码里更多像“语义型数据结构保留”，主要索引逻辑其实直接读写 `index_meta` 表，没有大量直接实例化它。

### 6.2 `lib/models/search_path_entry.dart`

这个文件描述“用户配置的可扫描路径”。

#### `enum PathEntryType`

只有两种类型：

- `local`
  - 本地目录。
- `webdav`
  - WebDAV 根路径。

#### `class SearchPathEntry`

表示一条被保存到设置中的路径配置。

字段说明：

- `type`
  - 本地路径还是 WebDAV 路径。
- `path`
  - 路径本体。
  - 本地时通常是目录；WebDAV 时通常是 URL。
- `username`
  - WebDAV 用户名。
- `password`
  - WebDAV 密码。

方法说明：

- `toJson()`
  - 把对象转成 Map，方便序列化到 `SharedPreferences`。
- `factory fromJson(...)`
  - 从 Map 恢复为对象。
- `encode()`
  - 把对象 JSON 序列化成字符串。
- `factory decode(String source)`
  - 从 JSON 字符串恢复对象。
- `toString()`
  - 方便调试和展示，输出 `(WebDAV) xxx` 或 `(Local) xxx`。

这个对象贯穿设置页、重建索引、播放路径匹配和远程访问流程。

## 7. 数据库层

### 7.1 `lib/providers/database_provider.dart`

这里只有两个 Riverpod Provider，但它们是整个应用的数据库入口。

#### `databaseProvider`

类型：`Provider<DatabaseService>`

作用：

- 创建一个 `DatabaseService` 实例。
- 在 Provider 生命周期结束时调用 `dispose()` 关闭数据库连接。

它是数据库服务的依赖注入入口，其他服务如 `SearchService`、`IndexerService` 都通过它间接拿到数据库路径或数据库连接。

#### `databaseInitProvider`

类型：`FutureProvider<void>`

作用：

- 在应用入口统一调用 `DatabaseService.init()`。
- 让界面可以在数据库 ready 之前显示 loading。

这个 Provider 的重要意义不是“提供数据”，而是“提供初始化时序保障”。

### 7.2 `lib/services/database_service.dart`

这个服务只做一件事：准备并持有本地 SQLite 数据库。

#### `class DatabaseService`

字段说明：

- `db`
  - 打开的 SQLite 数据库连接。
- `dbPath`
  - 数据库文件绝对路径。

方法说明：

- `Future<void> init()`
  - 获取应用支持目录。
  - 创建 `com.weiyunjun.subfinderx` 目录。
  - 打开 `subfinder.db`。
  - 调用 `_createTablesIfNotExist()`。

- `void _createTablesIfNotExist()`
  - 创建主表 `subtitles`。
  - 检查旧版 FTS 表 schema。
  - 如果发现旧版 FTS 使用了 external content 模式，则删除旧 FTS 表并删除 `index_meta`，强制下次重建。
  - 创建新的 FTS5 表 `subtitles_fts`。
  - 创建增量索引元数据表 `index_meta`。

- `void dispose()`
  - 释放数据库连接。

#### 数据表设计

##### `subtitles`

普通主表，存储结构化字幕条目。

字段：

- `id`
- `video_path`
- `video_name`
- `srt_path`
- `seq`
- `start_time`
- `end_time`
- `start_ms`
- `content`

##### `subtitles_fts`

FTS5 虚拟表。

特点：

- 只存 `content`。
- 使用 `unicode61` 分词。
- 与主表通过 `rowid -> subtitles.id` 手动关联。

##### `index_meta`

增量扫描元数据表。

字段：

- `srt_path`
- `file_size`
- `modified_at`
- `indexed_at`

作用：

- 如果 `.srt` 文件大小和修改时间都没变化，就跳过重建。
- 如果目录里某个旧字幕文件消失了，也可以根据差集删除陈旧记录。

## 8. 搜索层

### 8.1 `lib/services/search_service.dart`

这个服务负责把用户输入转换成适合 SQLite FTS5 的查询。

#### `searchServiceProvider`

类型：`Provider<SearchService>`

作用：

- 读取 `databaseProvider`。
- 创建 `SearchService`。

#### `class SearchService`

字段：

- `dbService`
  - 持有数据库服务引用，执行查询时直接访问 `dbService.db`。

方法：

- `List<SubtitleEntry> search(String keyword, {int limit = 500})`

执行流程：

1. 去掉首尾空格。
2. 空字符串直接返回空列表。
3. 判断用户是否主动使用了 FTS 语法：
   - `*`
   - `AND`
   - `OR`
   - `NOT`
   - `NEAR`
4. 如果已经是 FTS 语法，就原样使用。
5. 否则根据输入特征做自动转换：
   - 含 CJK 字符：把每个中文字符后插入空格，再整体包成短语查询。
   - 含空格：整句包成 phrase match。
   - 普通单词：自动补 `*` 做前缀匹配。
6. 执行 SQL：
   - 从 `subtitles_fts` 做 `MATCH`
   - 再 `JOIN subtitles`
   - 按 `video_name, start_ms` 排序
   - 限制最大结果数量
7. 用 `SubtitleEntry.fromRow()` 映射结果。
8. 如果 SQL 因语法错误报错，则吞掉异常并返回空数组。

#### 这段逻辑的设计意图

- 对英语单词搜索更友好：默认前缀匹配。
- 对空格短语更友好：默认整句匹配。
- 对中文更友好：依赖索引时的字符分段方案。
- 对高级用户开放：允许直接输入原生 FTS 语法。

### 8.2 `lib/view_models/search_view_model.dart`

这个文件不是“业务服务”，而是“界面和服务之间的状态桥梁”。

#### `class SearchKeywordNotifier extends Notifier<String>`

作用：

- 保存当前搜索框文本。

方法：

- `build()`
  - 初始值是空字符串。
- `updateKeyword(String word)`
  - 更新当前关键字。

#### `searchKeywordProvider`

类型：`NotifierProvider<SearchKeywordNotifier, String>`

作用：

- 让整个应用中的多个组件都能读写当前关键词。
- `SearchBarWidget` 负责写。
- `ResultListWidget` 和 `searchResultsProvider` 负责读。

#### `searchResultsProvider`

类型：`FutureProvider<List<SubtitleEntry>>`

作用：

- 监听关键词变化。
- 做 300ms 防抖。
- 调用 `SearchService.search()`。

实现细节：

- 通过 `ref.onDispose()` 设置 `cancelled = true`。
- 如果防抖期间用户又输入新字符，旧 Future 会被丢弃。
- 这是一种轻量的 debounce 实现。

## 9. 索引层

### 9.1 `lib/services/indexer_service.dart`

这是项目里最重、最关键的服务之一。它负责：

- 扫描本地或 WebDAV 中的 `.srt`
- 查找同名视频文件
- 解析 SRT
- 把字幕写入 SQLite 和 FTS5
- 做增量索引
- 删除失效旧记录

#### `indexerProvider`

类型：`Provider<IndexerService>`

作用：

- 从 `databaseProvider` 读取 `dbPath`
- 创建 `IndexerService`

这里传 `dbPath` 而不是传数据库连接，是因为索引部分会进入 `Isolate`，需要在隔离线程里重新打开数据库文件。

#### `class IndexProgress`

索引进度 DTO。

字段：

- `current`
  - 当前处理数量。
- `total`
  - 总数量。
- `currentFile`
  - 当前文件名。
- `status`
  - 例如 `scanning`、`indexing`、`downloading`、`done`、`error`。
- `message`
  - 面向 UI 展示的进度描述。

#### `class IndexerService`

字段：

- `dbPath`
  - SQLite 文件路径。

#### 公开方法：`indexDirectory(...)`

签名：

- `Future<void> indexDirectory(SearchPathEntry entry, void Function(IndexProgress)? onProgress)`

作用：

- 根据路径类型选择本地索引流程或 WebDAV 索引流程。

##### 本地目录分支

执行流程：

1. 检查目录是否存在。
2. 上报“正在扫描”进度。
3. 用 `_findAllSrtFilesLocal()` 递归收集所有 `.srt`。
4. 如果没有字幕文件，直接返回。
5. 上报“正在优化和解析”。
6. 调用 `Isolate.run()` 执行 `_runIsolateTaskLocal(...)`。
7. 完成后上报 done 信息。

这样设计的目的，是避免 SRT 解析和大量数据库写入阻塞 Flutter UI 主线程。

##### WebDAV 分支

执行流程：

1. 创建 `webdav_client` 客户端。
2. 递归调用 `_crawlWebdav()`，把所有远程文件收集到 `allWebdavFiles`。
3. 过滤出扩展名为 `.srt` 的文件。
4. 构造 `basePath`。
   - 这里非常小心地保留原始中文路径，不使用会重新编码路径的方式。
5. 遍历每个远程字幕文件：
   - 下载字幕字节。
   - 调用 `_findVideoFileWebdav()` 查找同目录匹配视频。
   - 进入 `Isolate.run()` 执行 `_parseAndInsertWebdavItem(...)`。
6. 统计 indexed / skipped。
7. 上报最终结果。

#### 私有方法说明

##### `_crawlWebdav(client, path, allFiles)`

递归遍历 WebDAV 目录。

特点：

- 忽略当前目录自己的虚拟项。
- 目录就继续递归。
- 文件就加入 `allFiles`。

##### `_findVideoFileWebdav(srtFile, allFiles, basePath)`

作用：

- 在 WebDAV 文件列表中，为某个 `.srt` 找到同目录、同基名的视频文件。

核心逻辑：

- 先取字幕文件所在目录。
- 再取不带后缀的基名。
- 如果名字尾部形如 `.en`、`.zh-CN` 之类的语言后缀，则同时把“去掉语言后缀后的基名”也作为候选。
- 遍历同目录文件，看是否存在 `.mp4/.mkv/.webm/.avi/.mov`。
- 找到后拼接成完整远程 URL 返回。

##### `_parseAndInsertWebdavItem(...)`

作用：

- 处理单个远程字幕文件。

执行步骤：

1. 打开数据库。
2. 查询 `index_meta`，如果文件大小和修改时间未变化，则跳过。
3. `utf8.decode(bytes, allowMalformed: true)` 解码字幕。
4. 用 `_parseSrtFileText()` 解析字幕块。
5. 开启事务。
6. 删除这个 `srt_path` 旧的主表记录与 FTS 记录。
7. 插入新的 `subtitles` 记录。
8. 对每一条字幕调用 `_segmentCJK()`，写入 `subtitles_fts`。
9. 更新 `index_meta`。
10. 成功则 `COMMIT`，失败则 `ROLLBACK`。
11. 关闭数据库。

##### `_findAllSrtFilesLocal(dir)`

作用：

- 遍历本地目录，递归收集所有 `.srt` 文件绝对路径。

##### 静态正则缓存

文件中缓存了多个正则：

- `_seqRegex`
  - 匹配纯数字序号行。
- `_timeRegex`
  - 匹配 `00:00:00,000 --> 00:00:01,000` 时间轴行。
- `_timeParseRegex`
  - 把时间字符串拆成时、分、秒、毫秒。
- `_langSuffixRegex`
  - 匹配语言后缀，如 `movie.en`、`movie.zh-CN`。

这些正则声明为静态缓存，目的是避免在大量文件解析时重复编译。

##### `_runIsolateTaskLocal(dbFilePath, rootDirPath, srtPaths)`

这是本地索引的主工作函数。

执行流程：

1. 打开数据库。
2. 设置 SQLite 性能参数：
   - `journal_mode=WAL`
   - `synchronous=NORMAL`
   - `temp_store=MEMORY`
3. 查询 `index_meta` 中已有路径。
4. 取当前目录里的实际字幕路径集合。
5. 计算差集，删除已经不存在的旧字幕记录与元数据。
6. 开启一个大事务，而不是每个文件一个事务。
7. 预编译插入主表与 FTS 表的 statement。
8. 遍历所有 `.srt`：
   - 用文件大小 + 修改时间做增量判断。
   - 用 `_findVideoFile()` 找同名视频。
   - 读文件字节并解码。
   - 用 `_parseSrtFileText()` 解析字幕。
   - 删除该 `srt_path` 的旧记录。
   - 插入新的字幕记录。
   - 为 FTS 插入 `_segmentCJK(entry.content)`。
   - 更新 `index_meta`。
9. 最后统一 `COMMIT`。
10. 如遇错误则 `ROLLBACK`。
11. 返回字符串形式的结果信息。

它之所以重要，是因为本地索引性能基本由这里决定。

##### `_findVideoFile(srtPath)`

本地版本的视频匹配函数。

作用：

- 根据字幕路径，在同目录下寻找同名视频。

特点：

- 支持语言后缀回退匹配。
- 支持 `.mp4/.mkv/.webm/.avi/.mov`。
- 同时检查小写和大写扩展名。

##### `_parseSrtFileText(srtPath, videoPath, content)`

作用：

- 把整个 `.srt` 文本解析成多个 `SubtitleEntry`。

内部状态机：

- `expect_seq`
  - 期待读到字幕序号。
- `expect_time`
  - 期待读到时间轴。
- `expect_text`
  - 期待读到正文，直到空行。

关键点：

- 使用 `LineSplitter` 按行切分。
- 每遇到一个完整块就调用 `flushEntry()`。
- 保留正文中的多行结构，最后用 `\n` 连接。

##### `_parseTimeToMs(timeStr)`

把 `HH:MM:SS,mmm` 或 `HH:MM:SS.mmm` 转换成毫秒整数。

##### `_segmentCJK(text)`

作用：

- 在中文字符后插入空格。

目的：

- 配合 SQLite `unicode61` 分词器，使中文字符更容易被 FTS 检索命中。

这是一个简单但实用的“索引时预处理”策略。

## 10. 播放与远程访问层

### 10.1 `lib/view_models/player_view_model.dart`

这个文件负责定义播放器相关的全局状态。

#### `class ActiveSubtitleNotifier extends Notifier<SubtitleEntry?>`

作用：

- 保存当前被点击、当前应该驱动播放器的字幕条目。

方法：

- `build()`
  - 初始状态是 `null`。
- `setActive(SubtitleEntry? entry)`
  - 更新当前激活字幕。

#### `activeSubtitleProvider`

类型：`NotifierProvider<ActiveSubtitleNotifier, SubtitleEntry?>`

作用：

- 左侧结果列表点击时写入。
- 右侧播放器面板监听它并执行播放。
- 关闭播放器时把它重置为 `null`。

#### `playerProvider`

类型：`Provider<Player>`

作用：

- 创建全局唯一的 `media_kit` `Player` 实例。
- Provider 销毁时调用 `player.dispose()`。

为什么做成全局唯一：

- 避免每次切换字幕都重建底层播放器。
- 让同一视频内的 seek 更快。
- 统一管理日志流、错误流和播放状态流。

### 10.2 `lib/services/alist_api_service.dart`

这个服务专门解决“WebDAV 能列目录，但播放器直接打开 `/dav/...` 地址不稳定”的问题。

#### `class AlistResolvedLink`

表示 AList 解析后返回的可直接播放链接。

字段：

- `url`
  - 签名后的真实下载地址。
- `headers`
  - 播放这个地址时可能需要附带的 HTTP 头。

#### `class AlistApiService`

单例服务。

字段：

- `_httpClient`
  - 原生 `HttpClient`。
- `_tokenCache`
  - 登录 token 缓存，避免重复登录。

构造方式：

- 私有构造 `AlistApiService._()`
- 对外暴露 `instance`

方法说明：

- `resolveSignedLink(...)`
  - 入口方法。
  - 先确认当前路径是 WebDAV 类型。
  - 验证目标 URL 是否属于这个 WebDAV 根。
  - 把 WebDAV 根路径转换成 AList 的文件路径。
  - 先 `_login()` 获取 token。
  - 再请求 `/api/fs/get`。
  - 从返回值中拿 `raw_url` 和额外 header。
  - 最后包装为 `AlistResolvedLink` 返回。

- `_login(...)`
  - 调用 `/api/auth/login`。
  - 把 `origin + username + password` 作为缓存键。
  - 成功后缓存 token。

- `_postJson(...)`
  - 通用 POST JSON 请求方法。
  - 被登录和 `fs/get` 复用。

- `_extractMountPath(webdavPath)`
  - 把 WebDAV URL path 映射成 AList 挂载路径。
  - 例如 `/dav` 映射为 `/`，`/dav/百度网盘` 映射为 `/百度网盘`。

- `_joinPosix(base, child)`
  - 安全拼接 POSIX 风格路径。

- `_normalizeComparableUrl(url)`
  - 去掉 URL 中的 `user:pass@`。
  - 去掉尾部 `/`。
  - 方便做前缀匹配。

- `_parseHeaderMap(rawHeader)`
  - 把接口返回的 header 字段解析成 `Map<String, String>`。
  - 兼容原本就是 Map 或 JSON 字符串两种情况。

### 10.3 `lib/services/local_stream_proxy_service.dart`

这个服务是播放器的兜底网络转发层。

#### `class LocalStreamProxyService`

单例服务。

字段：

- `_server`
  - 本地 `HttpServer`。
- `_httpClient`
  - 向真实远端发请求的客户端。
- `_targets`
  - token 到远端目标的映射。

主要方法：

- `register({required String remoteUrl, Map<String, String>? headers})`
  - 确保本地服务器已启动。
  - 生成 token。
  - 记录 token -> 远端 URL/header 映射。
  - 返回本地代理 URL，如 `http://127.0.0.1:xxxx/stream/<token>`。

- `_ensureServer()`
  - 如果本地服务器没启动，则绑定 loopback 地址随机端口。
  - 持续监听请求。

- `_handleRequest(request)`
  - 校验路径格式是否为 `/stream/<token>`。
  - 找到对应远端目标。
  - 将 Range、User-Agent、Accept 等关键请求头转发给远端。
  - 把远端返回的状态码和内容长度、范围等头透传回来。
  - 对 `HEAD` 请求只返回头。
  - 对普通请求直接流式 pipe 给客户端。

#### `class _ProxyTarget`

内部结构体：

- `remoteUrl`
- `headers`

作用：

- 保存某个代理 token 对应的真实远端目标。

### 10.4 `lib/ui/components/video_player_pane.dart`

这是整个项目最复杂的 UI 组件，也是实际播放控制中心。

#### `class VideoPlayerPane`

一个 `ConsumerStatefulWidget`，表示右侧视频区域。

#### `_VideoPlayerPaneState` 的字段

- `controller`
  - `VideoController`，用于把 `Player` 绑定到 `Video` 组件。
- `_errorSub`
  - 订阅播放器错误流。
- `_logSub`
  - 订阅播放器日志流。
- `_localPlaybackCache`
  - 远程视频下载到本地缓存后的映射。
- `_srtLocalCache`
  - 远程字幕下载到本地后的缓存。
- `_showSubtitles`
  - 是否显示字幕。
- `_feedbackController`
  - 给 `ActionFeedbackOverlay` 发送视觉反馈事件。
- `_playingSub`
  - 监听播放/暂停状态变化。
- `_buildContext`
  - 保存当前 context，用于 ESC 退出全屏时做路由 pop。

#### `initState()`

做了几件事：

1. 向 `HardwareKeyboard` 注册全局键盘处理器。
2. 从 `playerProvider` 取全局 `Player`。
3. 创建 `VideoController`。
4. 监听播放器错误和日志。
5. 监听 `player.stream.playing`，把播放/暂停状态转成反馈动画事件。
6. 在首帧后主动读取 `activeSubtitleProvider`，解决“用户首次点击字幕时播放器面板刚刚挂载，listen 还没收到历史事件”的问题。

#### `_handlePlayback(previous, next)`

这是点击字幕后真正开始播放的主函数。

执行流程非常关键：

1. 取出 `next.startMs`，转成 `Duration`。
2. 初始 `targetPath = next.videoPath`。
3. 如果 URL 中包含 `user:pass@`，提取出 Basic Auth。
4. 如果目标是 HTTP/HTTPS：
   - 先找匹配的 WebDAV 配置项。
   - 尝试把远程 URL 映射成本地已挂载路径。
   - 如果能映射到本地真实文件，优先本地播放。
   - 否则尝试 `AlistApiService.resolveSignedLink()`。
   - 如果 AList 成功，使用签名后的 `raw_url`。
   - 如果 URL 含非 ASCII 字符且需要兜底，尝试下载到本地缓存。
   - 如果以上都不满足，则注册到 `LocalStreamProxyService`，走本地代理。
5. 如果本次点击的是新视频：
   - 先 `_configurePlayerForTarget()`。
   - 再 `player.open(Media(...), play: true)`。
   - 并异步触发 `_loadSubtitleForEntry()`。
6. 如果还是同一个视频：
   - 只做 `player.seek(startDuration)`。
   - 然后 `player.play()`。

#### `_sanitizeHttpUrlForMpv(url)`

作用：

- 尽量保留非 ASCII 字符，同时对不安全的 ASCII 字符做百分号编码。

目的：

- 避免 URL 被错误重新编码。
- 尤其是中文路径和 mpv/URI 兼容问题。

#### `_needsLocalWebdavFallback(url)`

判断是否包含非 ASCII 字符。

当前含义：

- 如果 URL 含非 ASCII，通常更倾向本地缓存兜底。

#### `_prepareLocalPlaybackFile(...)`

作用：

- 把远程 WebDAV 视频下载到系统临时目录中，再作为本地文件播放。

执行步骤：

1. 查缓存。
2. 找匹配的 WebDAV 配置项。
3. 计算相对路径。
4. 创建临时缓存目录。
5. 调用 `client.read2File(relativePath, localPath)` 下载。
6. 写入缓存映射并返回本地路径。

#### `_configurePlayerForTarget(player, targetPath)`

作用：

- 针对本地文件和网络流，配置不同的 mpv 行为。

设置内容：

- 网络流：
  - `cache=yes`
  - `cache-on-disk=no`
- 本地文件：
  - `cache=no`
  - `cache-on-disk=no`
- 通用：
  - `sub-auto=no`
  - `sid=no`
  - `sub-visibility=no`

设计意图：

- 避免 mpv 自己自动发现字幕，和手动 `sub-add` 造成重复。
- 避免自动选中内嵌字幕轨。
- 保留字幕轨，但隐藏 mpv 自己的原生字幕渲染层，让 Flutter 侧 SubtitleView 接管。

#### `_loadSubtitleForEntry(player, entry)`

作用：

- 显式加载外挂字幕文件。

步骤：

1. 如果 `srtPath` 是远程 URL，就调用 `_downloadSrtToLocal()`。
2. 等待播放器进入已加载状态。
3. 调用 mpv 原生命令 `sub-add` 加载字幕。

#### `_downloadSrtToLocal(srtUrl)`

作用：

- 把 WebDAV 上的字幕下载到临时目录。

步骤：

1. 查缓存。
2. 去掉 URL 中的鉴权信息。
3. 找匹配的 WebDAV 配置项。
4. 算出相对路径。
5. 用 `webdav_client.read()` 下载字节。
6. 写入本地缓存文件。
7. 返回本地路径。

#### `_resolveLocalMountedPath(...)`

作用：

- 如果用户的 WebDAV 目录其实已经被挂载到本地某个目录，则优先映射成真实本地文件路径。

逻辑：

1. 根据 WebDAV 根和远程 URL 算相对路径。
2. 读取 `search_paths` 中的所有本地路径。
3. 把相对路径拼接到本地根目录上。
4. 检查文件是否存在。
5. 找到就直接返回本地路径。

这样可以绕过网络流，直接读取磁盘文件。

#### `_findMatchingWebdavEntry(remoteUrlWithoutUserInfo)`

作用：

- 从所有已保存的路径配置中，找出最匹配的 WebDAV 根。

实现上选“最长前缀匹配”，避免多个 WebDAV 根重叠时匹配错。

#### `_normalizeComparableUrl(url)`

和 AList 服务里的版本类似，去掉鉴权信息和尾部 `/`，用于 URL 前缀比较。

#### `dispose()`

- 移除全局键盘处理。
- 取消各种 stream 订阅。
- 关闭反馈事件流。

#### `_handleKeyEvent(event)`

这是自定义播放器快捷键处理器。

快捷键功能：

- `Esc`
  - 退出全屏路由。
- `←`
  - 后退 5 秒。
- `→`
  - 前进 5 秒。
- `↑`
  - 音量 +5。
- `↓`
  - 音量 -5。
- `Space`
  - 播放/暂停。
- `Z`
  - 播放速率重置为 1.0x。
- `X`
  - 播放速率 +0.1。
- `C`
  - 播放速率 -0.1。
- `Q`
  - 切换字幕显示/隐藏。

它会先检查当前焦点是否在输入框里，如果用户正在打字，就不拦截按键。

#### `build(context)`

主要做三件事：

1. `ref.listen(activeSubtitleProvider, ...)` 监听后续点击。
2. 构建 `Video` 组件和自定义 controls。
3. 在空状态显示占位 UI，在非空状态显示关闭按钮和播放界面。

其中 controls 的实现是：

- `MaterialDesktopVideoControls(state)` 作为基础控制层。
- `ActionFeedbackOverlay(stream: feedbackStream)` 叠加在上层显示快进/快退/音量/速率/播放暂停动画。

## 11. UI 层

### 11.1 `lib/main.dart`

这个文件是应用入口与顶层 App 壳。

#### `main(List<String> args)`

作用：

- 区分主窗口和设置窗口。
- 初始化 Flutter、MediaKit 和 ProviderScope。

关键分支：

- 如果参数是 `multi_window`
  - 解析设置窗口参数并启动 `SettingsWindowApp`
- 否则
  - 初始化媒体环境
  - 启动主窗口 `MyApp`

#### `class MyApp`

顶层应用 Widget。

继承：

- `ConsumerStatefulWidget`

当前 `initState()` 没有业务逻辑，更多是预留扩展位。

#### `_MyAppState.build()`

作用：

- 订阅数据库初始化状态。
- 清空 Flutter 默认 `Shortcuts`。
- 构建 `MaterialApp`。

为什么清空默认快捷键：

- 项目自定义了大量键盘控制。
- 默认 Space、Arrow、Tab、Enter 等行为会干扰播放器和页面交互。

### 11.2 `lib/ui/home_page.dart`

首页布局控制器。

#### `class HomePage`

主界面入口 Widget。

#### `_HomePageState` 字段

- `_globalFocusNode`
  - 用于全局按键拦截。

#### `initState()` / `dispose()`

- 创建和释放全局 `FocusNode`。

#### `_handleGlobalKeyEvent(node, event)`

作用：

- 在页面层拦截受控按键，阻止 Flutter 默认焦点移动和快捷键系统接管。

逻辑：

1. 如果用户正在某个 `TextField` 中输入，则放行。
2. 如果不在输入状态，则拦截：
   - 方向键
   - 空格
   - `Q/Z/X/C`
   - `Tab`
   - `Enter`

返回 `KeyEventResult.handled` 表示事件在这一层就停止传播。

#### `build(context)`

逻辑：

- 读取 `activeSubtitleProvider`。
- 如果没有激活字幕，显示单栏布局。
- 如果有激活字幕，显示左右双栏布局。

#### `_buildSinglePane()`

结构：

- 顶部搜索栏
- 分隔线
- 结果列表

#### `_buildDoublePane()`

结构：

- 左 3：搜索栏 + 结果列表
- 右 7：视频播放器

### 11.3 `lib/ui/components/search_bar_widget.dart`

这是顶部搜索栏，也是“重建索引”的交互入口。

#### `class SearchBarWidget`

带本地状态的 Consumer 组件。

#### `_SearchBarWidgetState` 字段

- `_controller`
  - 文本输入控制器。
- `_isIndexing`
  - 当前是否正在重建索引。
- `_indexMessage`
  - 当前进度提示文字。

#### `initState()`

做两件事：

1. 把 `searchKeywordProvider` 中的旧关键词放回输入框。
   - 因为布局在单栏/双栏切换时，这个 Widget 可能会被销毁重建。
2. 调用 `_bindMethodHandler()` 监听来自设置窗口的 `reindex`。

#### `_bindMethodHandler()`

作用：

- 建立主窗口 `0` 的单向 `WindowMethodChannel`。
- 收到 `reindex` 时调用 `_handleReindex()`。

#### `_handleReindex()`

重建索引主流程：

1. 防止重复执行。
2. 读取 `SharedPreferences` 中的 `search_paths`。
3. 兼容旧格式路径和新 JSON 格式路径。
4. 逐个调用 `ref.read(indexerProvider).indexDirectory(...)`。
5. 用回调更新 `_indexMessage`。
6. 索引结束后清空进度文字。
7. 最后重新写一次当前关键词，触发列表刷新。

#### `build(context)`

界面结构：

- 左侧：同步按钮
  - 点击手动重建索引。
- 中间：输入框
  - `onChanged` 时更新 `searchKeywordProvider`。
- 右侧：设置按钮
  - 打开新设置窗口。
- 下方：索引状态文字

### 11.4 `lib/ui/components/result_list_widget.dart`

这是搜索结果渲染组件。

#### `class ResultListWidget`

无本地状态的 `ConsumerWidget`。

方法说明：

- `_formatTimestamp(timeStr)`
  - 把时间戳格式简化展示。
  - 去掉毫秒。
  - 如果小时是 `00:`，也去掉。

- `_buildHighlightedText(text, keyword, baseStyle)`
  - 对搜索关键字做简单高亮。
  - 当前实现是大小写不敏感字符串匹配，不是复杂分词高亮。

#### `build(context, ref)`

行为：

1. 订阅 `searchResultsProvider`。
2. 订阅 `activeSubtitleProvider`。
3. 订阅 `searchKeywordProvider`。
4. 按 `when(data/loading/error)` 渲染。

`data` 分支中：

- 如果结果为空，显示空提示。
- 否则用 `ListView.builder` 渲染虚拟长列表。
- 每个条目点击后：
  - 写入 `activeSubtitleProvider`
  - 主动 `unfocus()`，避免键盘事件残留给列表

每个条目展示：

- 高亮后的字幕正文
- 时间戳
- 视频文件名
- 当前选中项会有浅色背景和左侧高亮边条

### 11.5 `lib/ui/components/action_feedback_overlay.dart`

这个组件只负责一件事：在播放器上显示大号视觉反馈动画。

#### `enum FeedbackType`

事件类型：

- `forward`
- `rewind`
- `playPause`
- `speed`
- `volume`

#### `class FeedbackEvent`

一个反馈事件对象。

字段：

- `type`
  - 反馈类型。
- `value`
  - 例如速度、音量数值。
- `boolValue`
  - 例如播放还是暂停。

#### `class ActionFeedbackOverlay`

接收一个 `Stream<FeedbackEvent>`，根据事件显示动画。

#### `_ActionFeedbackOverlayState` 的状态字段

主要分两组：

- 侧边快进/快退状态
  - `_forwardSecs`
  - `_rewindSecs`
  - `_forwardTimer`
  - `_rewindTimer`
  - `_showForward`
  - `_showRewind`

- 中央图标状态
  - `_centerIcon`
  - `_centerText`
  - `_showCenter`
  - `_centerTimer`

动画控制器：

- `_centerAnimCtrl`
- `_sideAnimCtrl`

流订阅：

- `_eventSub`

#### `_handleEvent(event)`

按事件类型分发到：

- `_showForwardAnim()`
- `_showRewindAnim()`
- `_showPlayPauseAnim(...)`
- `_showSpeedAnim(...)`
- `_showVolumeAnim(...)`

#### 各个 `_showXxxAnim()` 方法

共同特征：

- 更新状态。
- 触发动画控制器从头播放。
- 重置对应计时器。
- 800ms 后自动隐藏。

#### `_buildSidePill(isForward)`

生成左侧或右侧的胶囊提示条，如 `+ 10` 或 `- 5`。

#### `build(context)`

通过 `Stack` 叠加：

- 左侧快退提示
- 右侧快进提示
- 中央播放/速率/音量提示

整个组件 `IgnorePointer`，不影响下层播放控件点击。

### 11.6 `lib/ui/settings_window.dart`

设置窗口相关的全部逻辑。

#### `class SettingsWindowApp`

独立窗口中的顶层 `MaterialApp`。

字段：

- `windowId`
- `argument`

当前 `argument` 基本是预留位，真正使用的是 `windowId`。

#### `class SettingsPage`

设置窗口首页。

#### `_SettingsPageState`

字段：

- `_selectedIndex`
  - 当前左侧选中的设置分类。

当前只有一个分类：

- 路径

#### `_buildNavItem(...)`

构建左侧导航项。

#### `class PathSettingsPanel`

真正的路径设置面板。

#### `_PathSettingsPanelState` 字段

- `_isEditing`
  - 是否处于编辑模式。
- `_paths`
  - 当前路径列表。
- `_isLoading`
  - 是否正在加载配置。
- `_updateInfoMsg`
  - 保存成功后提示主窗口正在重建索引。

#### `initState()`

- 调用 `_loadPaths()`。

#### `_loadPaths()`

作用：

- 从 `SharedPreferences` 读取 `search_paths`。
- 兼容新旧两种存储格式。
- 如果为空，给一个默认本地路径。

#### `_savePaths(paths)`

作用：

- 把 `SearchPathEntry` 列表编码成字符串数组后保存。
- 保存后更新本地状态。
- 然后触发 `_triggerReindex()`。

#### `_triggerReindex()`

作用：

- 更新界面提示。
- 获取主窗口 `0` 的 `WindowController`。
- 调用主窗口的 `reindex` 方法。

#### `_chooseAddType()`

作用：

- 弹出底部菜单，让用户选择：
  - 添加本地文件夹
  - 添加 WebDAV 网盘

#### `_addNewLocalPath()`

作用：

- 打开系统目录选择器。
- 防止重复添加。
- 保存新路径。

#### `_addNewWebdavPath()`

作用：

- 弹出对话框输入 URL、用户名、密码。
- 组装为 `SearchPathEntry(type: webdav, ...)`。
- 保存。

#### `_removePath(path)`

作用：

- 弹出确认框。
- 删除路径并保存。

#### `build(context)`

布局：

- 顶部标题与“编辑”按钮
- 路径列表
- 编辑模式下的删除控制
- 底部添加按钮
- 可能的状态提示

## 12. 测试与辅助脚本

项目根目录下有三个临时/辅助性质的脚本，不属于正式 Flutter test 体系，但有助于理解早期调试过程。

### `test_indexer.dart`

作用：

- 给几个固定 `.srt` 路径做解析试验。
- 验证 `_findVideoFile()` 和 SRT 状态机解析是否能得到字幕块。

### `test_indexer_db.dart`

作用：

- 直接连真实数据库做单文件插入试验。
- 验证主表和 FTS 表写入是否正常。

### `test_indexer_dir.dart`

作用：

- 对某个目录全量扫描 `.srt`。
- 统计可以成功匹配视频并解析出字幕条目的文件数量。

## 13. 项目中的关键设计决策

### 13.1 为什么用 SQLite FTS5，而不是自己写全文索引

- 本地桌面工具对部署简单性要求高。
- SQLite 是单文件数据库，易于集成与备份。
- FTS5 已经足够处理字幕检索场景。
- 与 Dart FFI 结合后性能和体积都合适。

### 13.2 为什么主表和 FTS 表分开

- 主表保存结构化字段，便于排序、展示、跳转。
- FTS 表只关心检索字段，职责明确。
- 使用 `rowid` 和 `id` 手动关联，逻辑更可控。

### 13.3 为什么索引放到 Isolate

- 解析大量字幕和批量写数据库会阻塞 UI。
- Flutter 桌面应用如果主线程长时间忙碌，会直接影响交互体验。

### 13.4 为什么播放器要做多层远程兜底

远程视频播放存在多个现实问题：

- WebDAV 可列目录，不代表直连地址适合播放器消费。
- AList 背后可能接百度网盘等需要签名下载的后端。
- URL 里的中文路径、Basic Auth、302 跳转、额外 header 都可能让播放器失败。

因此这里采用了分层策略：

1. 能映射到本地挂载路径就直接本地读。
2. 否则优先让 AList 生成真实 `raw_url`。
3. 非 ASCII 路径必要时直接下载到本地缓存。
4. 仍不适合时走本地代理转发。

### 13.5 为什么要显式 `sub-add` 字幕

- 对本地文件播放器有时能自动发现字幕。
- 但对 HTTP 链接尤其是代理、签名 URL、远程缓存场景，自动发现不可靠。
- 显式加载更可控，也方便统一行为。

## 14. 当前已知特点与潜在改进点

### 已有优点

- 结构比较清晰，按 `models/services/view_models/ui` 分层。
- 本地和远程索引链路都已经打通。
- 播放链路对复杂网络环境做了多层兼容。
- 交互层面对键盘和播放反馈做了不少细节打磨。

### 当前局限

- 还没有正式的自动化测试。
- README 和源码之间没有自动同步机制，文档更新需要手工维护。
- 一些错误处理采用了“吞异常后返回空结果”的策略，便于 UI 稳定，但不利于定位问题。
- WebDAV 全量递归遍历在超大目录上可能较慢。
- `IndexMeta` 类目前更多是语义占位，未被系统性使用。
- 部分日志和错误输出仍带有本地绝对路径假设，比如桌面日志文件。

### 后续值得做的事情

- 为索引器和播放器策略提炼单元测试。
- 把 SRT 解析、视频匹配、CJK 分段等纯函数抽成更易测试的工具模块。
- 为设置页提供路径编辑与排序能力。
- 优化 WebDAV 增量索引策略。
- 引入更完整的错误报告与诊断 UI。

## 15. 给 LLM 的理解提示

如果你是一个后续要继续修改本项目的 LLM，可以先建立下面这个最小心智模型：

1. `SearchPathEntry` 描述“去哪里找字幕”。
2. `IndexerService` 负责“把字幕文件变成数据库记录”。
3. `SubtitleEntry` 描述“数据库里的一条字幕命中结果”。
4. `SearchService` 负责“把关键词变成数据库查询”。
5. `searchKeywordProvider` 和 `searchResultsProvider` 负责“搜索框到结果列表”的状态链路。
6. `activeSubtitleProvider` 负责“点击一条结果后，告诉播放器播放哪一句”。
7. `VideoPlayerPane` 负责“把字幕条目变成真正的视频播放行为”。
8. 如果视频路径是远程的，优先思考：
   - 是否能映射到本地挂载目录
   - 是否需要 AList `raw_url`
   - 是否需要本地缓存
   - 是否需要本地代理

## 16. 启动方式

```bash
flutter pub get
flutter run -d macos
```

首次使用时，建议先在设置窗口中添加本地目录或 WebDAV 根路径，再点击同步按钮触发索引。

## 17. 最后的总结

SubFinderX 当前已经不是一个“简单搜字幕的 Flutter demo”，而是一个完整串起了路径配置、批量索引、全文检索、结果联动播放、远程路径解析、播放器兜底策略和键盘交互系统的桌面工具原型。

如果只记住一句话：

这个项目的核心就是“把字幕句子变成视频时间跳板”，而它的全部工程实现，都是为了让这个跳板在本地文件、WebDAV、AList 和播放器之间尽可能稳定地工作。
