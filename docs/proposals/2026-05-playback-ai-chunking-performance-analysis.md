# Performance Analysis - Playback AI Sentence Chunking Latency Breakdown

根据高分辨率遥测日志，我们对 macOS 播放 Quick Search 叠加层中“AI 句子分块”功能的生命周期以及各环节的执行耗时进行了系统性拆解。以下是高精度的性能分析报告。

---

## 1. 耗时数据总览 (Latency Summary Table)

在句子分块查询的整个生命周期中，主要包含以下六个步骤。根据 **Cache Miss（缓存未命中）** 和 **Cache Hit（缓存命中）** 两种情况，每一步的典型执行时间如下：

| 步骤编号 | 阶段名称 | 典型耗时 (Cache Miss) | 典型耗时 (Cache Hit) | 瓶颈等级 | 执行线程 | 备注 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **步骤 1** | **本地缓存查询**<br>(SQLite Cache Lookup) | `0.10ms - 0.50ms` | `0.10ms - 0.50ms` | 🟢 极低 | 异步后台线程 | 在本地 SQLite `ai_chunk_cache_entries` 中查找哈希 |
| **步骤 2** | **DeepSeek API 网络请求**<br>(Network HTTP Request) | **`2,200ms - 2,300ms`** | `0ms` (跳过) | 🔴 **绝对瓶颈** | 异步网络线程 | 包含网络往返时延及大模型推理时间 |
| **步骤 3** | **JSON 解码与提取校验**<br>(JSON Decode & Validation) | `2.50ms - 10.12ms` | `0ms` (跳过) | 🟢 极低 | 异步后台线程 | JSON 结构体反序列化及词块合法性去重校验 |
| **步骤 4** | **本地缓存写入**<br>(SQLite Cache Write) | `0.50ms - 2.00ms` | `0ms` (跳过) | 🟢 极低 | 异步后台线程 | 将提取到的词块序列化为 JSON 写入数据库中 |
| **步骤 5** | **词块频次库查询**<br>(Database Occurrence Count) | `0.24ms - 1.97ms` | `0.24ms - 1.97ms` | 🟢 极低 | 异步数据库线程 | CJK FTS5 索引精准分词匹配 + SQL `LIKE` 局部过滤 |
| **步骤 6** | **UI 线程异步刷新**<br>(UI Async Task Delivery) | `7.66ms` (总回调) | `7.66ms` (总回调) | 🟢 极低 | 主线程 (MainActor) | 从数据库拿到结果传递并重新渲染 UI 容器的调度开销 |

---

## 2. 详细生命周期步骤拆解 (Step-by-Step Breakdown)

### 步骤 1：本地缓存查询 (SQLite Cache Lookup)
- **原理**：将当前句子利用 `AIChunkTextNormalizer.normalizedSentence` 进行正则化与去噪（提取核心中日韩或英文句子内容），随后将其转化为 64 字节哈希值作为主键，在本地 SQLite 表 `ai_chunk_cache_entries` 中检索缓存条目。
- **耗时**：**`0.10ms - 0.50ms`**。
- **结论**：极速。由于使用了高效的 SQLite 索引，本地检索几乎不消耗任何时间。

### 步骤 2：DeepSeek API 网络请求 (DeepSeek API Request)
- **原理**：若本地缓存未命中，利用 `DeepSeekChunkingClient` 发起 HTTP POST 请求到 `https://api.deepseek.com/chat/completions`。
- **耗时**：**`2,233.15ms - 2,261.32ms`** (典型值 2.2 秒以上)。
- **结论**：**这是导致“速度比之前慢了非常多”的唯一、绝对的性能瓶颈。** 无论是建立 HTTPS 握手、发送 Payload，还是等待 DeepSeek-v4-flash 模型生成高召回率的复杂 JSON 词块及中文翻译，网络往返和 LLM 推理开销均处于秒级级别。

### 步骤 3：JSON 解码与提取校验 (JSON Decoding & Validation)
- **原理**：网络响应返回后，利用 `JSONDecoder` 依次解码 `DeepSeekChatCompletionResponse` 及其嵌套的 `AIChunkingContent`，并由 `validatedItems` 进行过滤校验与去重，将字词转换为 `[AIChunkItem]`。
- **耗时**：**`2.50ms - 10.12ms`**。
- **结论**：极快。本地 CPU 反序列化对整体时延的影响几乎可以忽略不计。

### 步骤 4：本地缓存写入 (SQLite Cache Write)
- **原理**：在获取合规的词块项后，后台调用 `database.upsertAIChunkCacheEntry`，将包含翻译的 `[AIChunkItem]` 序列化为 JSON 写入 SQLite 本地表中，确保后续相同句子直接命中缓存。
- **耗时**：**`0.50ms - 2.00ms`**。
- **结论**：极快。SQLite 事务写入性能完全不会拖慢前台。

### 步骤 5：词块频次库查询 (Database Occurrence Count)
- **原理**：当选中某个词块（例如 `'君'`）时，UI 触发频次数据库查询。`cueGroupOccurrenceCount(for:)` 自动识别中日韩文，并通过 `ftsQuery` 进行 CJK 分词检索，结合 SQL `LIKE` 辅助检索进行高保真过滤。
  - **SQL 预处理与参数绑定 (`prep` 阶段)**：耗时 **`0.03ms - 0.12ms`**。
  - **SQL 执行与提取计数 (`step` 阶段)**：耗时 **`0.20ms - 1.85ms`**。
- **总数据库耗时**：**`0.24ms - 1.97ms`**。
- **结论**：极致的数据库查询性能。即便存在 800+ 数量的大容量频次匹配，也能在 2ms 内得出计数结果。

### 步骤 6：UI 线程异步刷新 (UI Async Task Delivery)
- **原理**：在 SwiftUI 组件中，频次查询运行在异步非阻塞的 `Task` 块中。由于查询是在独立线程完成的，回到主线程进行 UI 重绘的整个生命周期也仅需极短时间。
- **耗时**：**`7.66ms`** 左右。
- **结论**：主线程响应非常流畅，由于异步任务调度合理，绝对没有发生任何 UI 卡顿（Stutter/UI-blocking）。

---

## 3. “速度比之前慢了非常多”的根本原因与后续优化方向

### 根本原因
通过上方的精准耗时记录可以明确得出结论：**除 DeepSeek 大模型网络请求（步骤 2）外，数据库读取、网络解析、缓存持久化和主线程 UI 刷新的累计耗时仅在几毫秒级。用户感知到的“速度慢”全部来源于网络往返时延（RTT）及 DeepSeek API 产生大模型响应时的生成时延（2.2s+）。**

### 建议优化方案
为了不影响大模型的高召回词块生成质量，同时在视觉上大幅度提升响应速度，我们建议在后续版本中实施以下优化：
1. **背景预拉取（Predictive Background Prefetching）**：
   - 当播放器准备加载下一句字幕时，利用非阻塞后台线程**提前 1-2 句**向 DeepSeek 发起分块请求并将结果持久化到本地 SQLite 缓存中。当用户打开 Quick Search 切换到该句时，即可 **100% 直接命中本地缓存**，实现毫秒级瞬间加载。
2. **轻量级本地分词器垫后（Fast Local Segmenter Fallback）**：
   - 在网络请求响应的 2.2 秒等待期内，利用内置的轻量级分词器（如基于 CoreNLP 或 SQLite 默认分词器）先输出基础的本地词块让用户进行交互，大模型响应返回后再平滑地渐进式更新为多层级高召回词块。
