# Localize The Library And Cover Editing

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

覆盖需求里的媒体库一节：页标题与汇总、添加内容、卡片上的播放与继续播放、右键菜单的打开
文件夹与更换封面、三档观看状态的标记与全部标记、集数与「正在播放第 N 集」、最近观看与
最近 Shiori 的分组名和空状态、以及封面编辑弹窗与封面选择面板。

集数、文件夹汇总、继续进度这类带数字的文案改用带位置参数的格式串，中英文语序不同也能
各自成立。

`WorkbenchTestLibraryView` 观察语言存储，语言变化时这一棵子树重新求值。

### 一处刻意不翻译

`AppCoordinator` 里出现的 `Covers` 是封面文件在磁盘上的目录名，不是界面文案。翻译它会
让已有封面文件找不到，因此保持原样。

关键文件：
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`
- `Sources/CueSeekerApp/Search/Library/LibraryFolderHeader.swift`
- `Sources/CueSeekerApp/Search/Library/LibraryEpisodeButton.swift`
- `Sources/CueSeekerApp/Shared/CoverSummaryCard.swift`
- `Sources/CueSeekerApp/Library/LibraryCoverEditingWorkflow.swift`
- `Sources/CueSeekerApp/Library/LibraryCoverCropEditor.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- `CoverSummaryCard`、`Library`、`AppLocalization` 相关共 118 个用例全部通过。
- Debug E2E 真机验证：简体中文下进入媒体库页，页标题为「媒体库」，汇总为
  「39 个文件夹 · 611 个视频 · 611 个字幕」，按钮为「添加内容」，卡片角标为「13 集」等。
  验证结束后偏好已删除，恢复默认跟随系统。

## Outcome

符合预期。

## 未能真机验证的部分

右键菜单、封面编辑弹窗、封面选择面板需要交互才会出现，本次没有逐个截图；它们都是按需
创建的浮层，每次打开都会重新取文案，不存在缓存问题。
