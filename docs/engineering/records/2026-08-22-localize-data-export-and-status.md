# Localize The Data Page, Export And Running Status

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

本次是需求覆盖范围的最后一批：Data 页、导出相关的保存面板与错误提示、以及索引与维护
过程中的运行状态与失败提示。

### 导出里刻意不翻译的部分

按需求第 7 条，写进 `.apkg` 数据的名称——牌组名、笔记类型的三个字段、卡片模板名与样式
名——全部保持英文。翻译它们会让新旧导出的牌组和笔记类型对不上，破坏已有牌组的兼容性。
被翻译的只有保存面板标题、默认文件名和面向用户的错误提示。

### 运行状态提示

「正在索引 / 正在移除文件夹 / 正在压缩数据库 / 数据库尚未初始化」这类互斥状态提示，
以及索引过程中的元数据、封面、展示刷新失败提示，改为按当前语言取值。提示里拼接的底层
错误文本按需求第 8 条保持英文。

关键文件：
- `Sources/CueSeekerApp/Data/DataView.swift`
- `Sources/CueSeekerApp/Export/AnkiPackageExporter.swift`
- `Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`
- `Sources/CueSeekerApp/App/AppCoordinator+AnkiExport.swift`
- `Sources/CueSeekerApp/App/AppCoordinator+SubtitleScreenshotExport.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- 整包 `swift test`（1017 个用例）：失败集合与基线同类，都是既有的环境相关不稳定用例
  （音频设备、窗口尺寸、滚动锚点、指针转移），外加此前已定位的
  `sharedPersistenceMigration...` 测试隔离问题。
- Debug E2E 真机验证：简体中文下进入 Data 页，页标题为「数据」，树形内容正常展开。
  验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 未能真机验证的部分

导出保存面板、导出失败提示与各类运行状态提示都需要具体触发条件（选中条目导出、磁盘空间
不足、索引失败等），本次没有构造这些场景，只有编译与单元层面的覆盖。
