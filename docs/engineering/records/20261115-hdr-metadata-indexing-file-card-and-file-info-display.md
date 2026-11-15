# HDR 元数据索引、File 卡片标签与 File Info 展示工程实现记录

- 对应需求单：`docs/human/requirements/20261115-Feature-HDR Metadata Indexing File Card And File Info Display.md`
- 分支 / 起始提交：`main`（变更前：`db00640`，需求单提交后：`c010af5`）

## 修改摘要

1. **FFmpeg 底层流与有界轻量采样 HDR 探测（`CNativePlayback`）**
   - `apps/macos-native/Sources/CNativePlayback/include/SFXNativePlaybackPlayer.h`：新增 `SFXMediaHDRMetadata` 值对象与 `SFXMediaMetadata.hdrMetadata` 属性。
   - `apps/macos-native/Sources/CNativePlayback/SFXMediaMetadataInspector.m`：新增 `SFXInspectVideoHDRMetadata`、`SFXHDRSampleFramesFromCursor`、`SFXHDRMergePacketSideDataList`、`SFXHDRMergeFrame`、`SFXHDRMergeMasteringDisplay`、`SFXHDRMergeContentLight` 与 `SFXBuildHDRMetadataFromState`。
     - 优先读取 `codecpar` 色彩属性（`color_primaries` / `color_trc`）与流级 `coded_side_data`（`DOVI_CONF`、母带显示、内容亮度、`HDR10+`）。
     - 对已明确标记为常规 SDR 且无 HDR 附加数据的 MP4 / MKV 保持零额外解码开销；对需要补齐帧级动态元数据（`HDR10+` / 比特流 DOVI RPU / 混合标准）及广播流/裸流（`mpegts` / `hls` / `flv` 等片头普通信号切入正片 HDR）执行有界关键帧对齐轻量采样（首部采样 + `0.35` / `0.70` 时间戳跳转与 `AVSEEK_FLAG_BYTE` 50% 回退）。

2. **产品域结构化数据、SQLite Schema 69 与持久化链路（`CueSeekerCore` / `CueSeekerPlayback`）**
   - `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseModels.swift`：新增 `VideoHDRStandard` 与 `VideoHDRMetadata`（仅保存标准列表、杜比视界 Profile/兼容配置号、色域/传递曲线规范标识、母带色域与亮度范围、MaxCLL / MaxFALL 等结构化原始数据，不存预拼接展示文案）。
   - `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift` & `DatabaseBootstrap+Migrations.swift`：Schema 版本升至 `69`，为 `video_files` 新增可空 `hdr_metadata TEXT` 列，补全 `migrateSchema68To69`：旧库升级时增加 `hdr_metadata` 并将存量 `video_files.duration_retry_pending` 置为 `1`，不在迁移阶段扫描外部媒体文件。
   - `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseProtocols.swift`、`LibraryDatabase.swift`、`IndexedContentDatabaseModels.swift`、`IndexedContentDatabase.swift`、`LibraryDatabase+FileDetail.swift`、`CueSeekerPlayback/PlaybackVideoMetadataIndexer.swift`：在探测结果 `ProbedVideoMediaMetadata`、`updateVideoMetadata`（写入 `hdr_metadata` 并在 HDR 与已确认普通 SDR 时统一将 `duration_retry_pending` 清零）、`IndexedContentObject` 及 `FileDetailVideoInfo` 全链路透传 `hdrMetadata`；应用内文件组与目录重命名自动保留该列。

3. **纯函数格式化与 UI / 多语言原位接入（`CueSeekerCore` / `CueSeekerApp`）**
   - `apps/macos-native/Sources/CueSeekerCore/LibraryDatabase+FileDetail.swift`：新增 `MediaDetailFormatter.shortHDRStandardText`（按 `Dolby Vision` / `杜比视界` / `杜比視界` > `HDR10+` > `HDR10` > `HLG` 返回最高优先级单一标准）与 `MediaDetailFormatter.hdrProperties`（输出至多 6 项，含多标准组合、杜比视界 Profile `.0` 省写及无配置号回退、母带亮度尾零裁剪、千分位无逗号、`MaxCLL`/`MaxFALL == 0` 及缺失项隐藏）。
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`：复用 `FileCardSubtitleFormatter.videoSubtitle(for:locale:)`，在简化分辨率与视频编码之间以 `2` 个英文空格插入单一 HDR 标签（非 HDR 或未重索引省略）。
   - `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileDetailDialog.swift` & `Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`：复用现有 `FileDetailRow` 与 `SettingsRowDivider` 在 `Pixel Format` 与 `Duration` 之间通过 `hdrPropertyItems` 渲染至多 6 项 HDR 信息（非 HDR 全隐藏），并接入英/简/繁实时语言切换响应（`languageRevision` / `AppLocalizationStore`）。

4. **工程规范与文档同步**
   - 严守奥卡姆剃刀与 UI 设计规范：全部在现有模块原位扩展，未新建独立引擎/管理层或硬编码特例，正式代码未引入任何测试专用属性或后门，未改动 `docs/human/`。
   - 更新 `docs/engineering/05_database_rules.md`（Schema 版本更新至 `69`，补录 Schema `68` 与 Schema `69` 说明）与 `docs/changelog.md`。

## 编译与单元测试验证

- 全部代码与测试修改完成后执行定向无窗口纯逻辑回归测试：
  `swift test --package-path apps/macos-native --filter "DatabaseBootstrapTests|FileDetailDatabaseTests|LibraryRenameTests|IndexedContentDatabaseTests|PlaybackVideoMetadataIndexerTests|FileRouteNavigationTests|hdrPropertyItemsAndLocalizationBundlesSwitchCleanly"`
  - 共执行 `87` 项纯逻辑测试，全部通过（0 失败，包含 Schema 68 -> 69 升级与 `duration_retry_pending` 置位/清零、重命名保留、真实 FFmpeg SDR / HDR10 静态元数据 / 中途 SDR->HLG 广播流探测、卡片副标题优先级与多语言切换、File Info 至多 6 项裁剪与隐藏等用例）。
- UI 视觉效果与真实 HDR/SDR 片源端到端验收交由用户实测确认。
