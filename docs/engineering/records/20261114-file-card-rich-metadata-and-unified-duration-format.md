# File 卡片富媒体摘要与统一补零时长格式工程实现记录

- 对应需求单：`docs/human/requirements/20261114-Feature-File Card Rich Metadata And Unified Duration Format.md`
- 分支 / 起始提交：`main`（`a5f5de7`）

## 修改摘要

1. **数据库 Schema 68 与查询边界修正（`CueSeekerCore`）**
   - `DatabaseBootstrap.swift` / `DatabaseBootstrap+Migrations.swift`：将 `currentSchemaVersion` 升级至 `68`，新增 `migrateSchema67To68(on:)` 与建表索引 `idx_subtitle_cue_lines_subtitle_file ON subtitle_cue_lines(subtitle_file_id)`，迁移阶段按 `subtitle_cue_lines` 实际列集合防守执行以兼容早期历史测试 Fixture。
   - `IndexedContentDatabaseModels.swift` / `IndexedContentDatabase.swift`：移除 SQL 查询中的 `COALESCE(..., 0)`，`IndexedContentObject` 与 `IndexedContentSubtitle` 改为可空元字段并读取视频宽高、视频编码、时长、字幕 `raw_cue_count` 与有效台词数（`loadValidCueCounts(for:)` 直接通过 `subtitle_file_id` 索引分组计数，不连接多余表），严格保留数据库 `NULL` 与真实 `0` 的区别。
2. **领域层统一格式与分档映射（`CueSeekerCore`）**
   - `LibraryDatabase+FileDetail.swift`（`MediaDetailFormatter`）：
     - 新增 `shortResolutionText(width:height:)`：基于 `videoResolutionBenchmarks`（`8K` 至 `144P` 标准基准宽高）、`resolutionCropToleranceRatio = 0.05` 统一容差及下一档短边下限推导 10 档简化分辨率标签；
     - 在 `videoCodecMappings` 中统一维护详情页与卡片展示名称并新增 `VVC / H.266` 映射，提供 `shortVideoCodecText(_:)` 与保留既有 `File Info` 的 `codecText(_:)`；
     - 抽出 `formattedDuration(seconds:)` 与 `formattedDuration(seconds:roundingRule:)`，为播放器、封面与 `File Info` 统一提供 `< 1h` 时 `MM:SS`（两位补零）与 `>= 1h` 时 `HH:MM:SS`（两位补零）格式，并提供 `shortDurationText(_:)`。
3. **展示层卡片副标题、时长复用、本地化与缓存失效（`CueSeekerApp`）**
   - `WorkbenchFileView.swift`：新增 `FileCardSubtitleFormatter` 将非空字段按双半角空格 `"  "` 拼接为单个副标题字符串传入既有 `WorkbenchFileCard`，不修改通用静态可选文本控件 `WorkbenchSelectableText` 及任何 UI 布局变量；真实 `0` 值正常渲染（`0 B`、`0 raw cues` / `0 条原始台词` 等），`NULL` 字段省略。
   - `Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`：补充三语台词数量单复数键 `file.card.raw_cue_count.{one,other}` 与 `file.card.valid_cue_count.{one,other}`。
   - `LibraryCoverViews.swift`、`PlaybackChromeView.swift`、`PlaybackProgressScrubber.swift`：统一改用 `MediaDetailFormatter.formattedDuration(seconds:...)`。
   - `AppCoordinator+Indexing.swift`：在后台辅助数据刷新完成回调 `refreshLibraryAfterAuxiliaryDataMutation()` 中追加 `invalidateFileTreeCache()`，确保后台异步补全的视频元数据能同步触发 `File` 界面文件树缓存失效与按需重建。

## 单元测试与验证结果

以下测试均在最后一次代码修改后执行通过：

1. **定向核心与 UI 回归（8 个测试套件）**：
   `swift test --package-path apps/macos-native --filter "DatabaseBootstrapTests|IndexedContentDatabaseTests|FileDetailDatabaseTests|LibraryCoverProgressPresentationTests|FileRouteNavigationTests|WorkbenchInvalidationTests|FileDetailDialogTests|FileCardMenuTests"`
   - 结果：Swift Testing 执行 87 项全部通过（0 失败）。
2. **扩展 Core 与 App 回归（17 个测试套件，含 `WorkbenchSelectableTextTests` 等）**：
   `swift test --package-path apps/macos-native --filter "CoverSummaryCardTests|PlaybackChromeVisibilityModelTests|PlaybackProgressScrubberThumbnailTests|WorkbenchSelectableTextTests|LibraryCoverProgressPresentationTests|LibraryCoverFrameTests|FileCardMenuTests|FileDetailDialogTests|FileRouteNavigationTests|WorkbenchInvalidationTests|DatabaseBootstrapTests|IndexedContentDatabaseTests|FileDetailDatabaseTests|LibraryDatabaseTests|IndexingDatabaseTests|SubtitleIndexerTests|AppResourceBundleTests"`
   - 结果：Swift Testing 执行 229 项全部通过（0 失败）。
3. **本地化键一致性与文件大小格式测试**：
   `swift test --package-path apps/macos-native --filter "everyBundledLanguageDefinesTheSameKeys|singularCountKeysDoNotContainUnresolvedFormatPlaceholders|FileSizeFormatterTests"`
   - 结果：XCTest（`FileSizeFormatterTests`）5 项全部通过，Swift Testing 2 项全部通过（0 失败）。
4. **原生播放模块全量回归**：
   `swift test --package-path apps/macos-native --filter "CueSeekerPlaybackTests"`
   - 结果：Swift Testing 执行 135 项全部通过（0 失败）。
