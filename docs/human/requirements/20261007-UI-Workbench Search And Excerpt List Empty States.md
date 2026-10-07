# Workbench Search 与 Excerpt List 空状态及表头交互需求

## 1. 范围与定义

覆盖 **Workbench Search** 与 **Excerpt List** 两个页面的 4 种空状态：

1. **Search 未输入搜索词（Empty Query）**：搜索输入框为空，未发起搜索。
2. **Search 搜索无结果（Empty Results）**：搜索输入框有内容（或有筛选条件），但匹配结果数为 0。
3. **Excerpt List 列表无内容（Empty List）**：该摘录单本身没有任何已保存的摘录条目。
4. **Excerpt List 搜索/筛选无结果（Empty Filter/Search）**：摘录单本身有条目，但搜索或筛选后匹配数为 0。

## 2. 界面与交互行为

1. **表头隐藏**：
   - 在上述全部 4 种空状态下，**隐藏表格表头**（表头高度为 0，不显示列名与表头下方的边框分隔线）。
   - 有数据时正常显示表头。
2. **文字居中对齐**：
   - 在上述全部 4 种空状态下，提示文本必须在界面的**剩余可视空白区域**内水平和垂直居中。
   - **Search 界面**：在 Search Toolbar 下方的剩余可视区域居中。
   - **Excerpt List 界面**：排除顶部 Cover Summary 与 Pinned Toolbar 占用的高度后，在下方剩余的可视区域居中（修复先前偏上未居中的问题）。
3. **Toolbar 结果计数（做法 C）**：
   - **Search 未输入搜索词**时，Toolbar 第二行左侧保持留白，不显示 `xx results`，右侧保留 Filter 筛选入口。

## 3. 多语言文案规范

### 3.1 Search 未输入（Empty Query）
- zh-Hans: `输入搜索词以显示台词。`
- en: `Enter a search term to show cues.`
- zh-Hant: `輸入搜尋字詞以顯示台詞。`

### 3.2 Search 搜索无结果（Empty Results）
- zh-Hans: `未找到匹配的台词。`
- en: `No matching cues found.`
- zh-Hant: `未找到相符的台詞。`

### 3.3 Excerpt List 列表无内容（Empty List）
- zh-Hans: `从搜索结果中或在播放时保存台词，即可收集摘录。`
- en: `Save cues from search results or playback to collect excerpts.`
- zh-Hant: `從搜尋結果中或在播放時儲存台詞，即可收集摘錄。`

### 3.4 Excerpt List 搜索/筛选无结果（Empty Filter/Search）
- zh-Hans: `未找到匹配的摘录。`
- en: `No matching excerpts found.`
- zh-Hant: `未找到相符的摘錄。`