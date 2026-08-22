# Localize The Info Page States

## Human-owned document

- `docs/human/requirements/20260822-Feature-Simplified And Traditional Chinese Localization.md`

## Change

`InfoPageState` 是搜索 / 媒体库 / Shiori 三个界面非稳态文案的唯一归口，标题和说明共 17 条
改为按当前语言取值。渲染它的 `InfoPageStateView` 观察语言存储，语言变化时只有这一处
重新求值。

失败态的文案来自错误本身，按需求第 8 条本期不翻译，保持原样透传。

关键文件：
- `Sources/CueSeekerApp/Workbench/InfoPageStateView.swift`

### 新增一条跨语言的约束

新增 `everyBundledLanguageDefinesTheSameKeys`：直接读三份语言资源里实际定义的键，要求
三者完全一致。这样某一条文案只加到一种语言、另外两种漏掉时会直接测试失败，而不是在运行
时静默回落成键名。后面还有大量文案要翻译，这条约束是给它们兜底的。

## Verification

- `swift build --product CueSeeker` 通过。
- `AppLocalizationTests` 与 `InfoPageStateTests` 全部通过，含新增的键一致性用例。

## Outcome

符合预期。

## 未能真机验证的部分

这几个状态在当前数据下不可达：媒体库非空，所以「媒体库为空 / 正在加载媒体库 / 没有视频」
都不会出现；失败态需要构造错误。搜索页在空查询时显示的是搜索外壳自己的提示
（`Enter a search term to show cues.`），不走 `InfoPageState`，属于表格那一批提交的范围。
本次因此只有单元层面的验证，文案取值走的是与其它界面相同的入口。
