# Localization Final Sweep

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

需求覆盖范围翻译完成后，对所有界面目录做了一次收尾排查，找出三处漏网的用户可见文案并
补上：

- 播放标题在没有任何选中项时的兜底文案「未选择视频」。
- Data 页在数据库尚未初始化时展示的失败原因，复用已有的运行状态文案。
- 最近页里「最近视频 / 最近 Shiori」两个分组标题。之前只翻译了侧栏的同名入口，页面内
  的分组标题是另一处调用点。

排查同时确认以下英文是**刻意保留**的，不属于漏翻：写进 Anki 导出数据的名称与字体名、
`Deep Link`、底层技术错误文本、断言用的开发者信息，以及作为系统偏好取值比较用的
`Maximize` / `Minimize`。

关键文件：
- `Sources/CueSeekerApp/App/AppCoordinator.swift`
- `Sources/CueSeekerApp/App/AppCoordinator+Data.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`

## Verification

- `swift build --product CueSeeker` 通过。
- 本地化、媒体库、播放相关共 432 个用例：失败集合与基线同类，都是既有的环境相关不稳定
  用例，没有新增失败。

## Outcome

符合预期。
