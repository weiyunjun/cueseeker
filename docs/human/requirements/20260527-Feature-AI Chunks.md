### 版本
feature/playback-quick-search
### 需求描述
1. 在Settings - Experimental Features - AI Chunking中，新增Translation Language，在下拉选择框中，有简体中文，繁體中文，English，日本語，一共4个选项。默认简体中文。这个选项需要实时生效并持久化。
2. 在Settings - Experimental Features - AI Chunking中，支持prompt配置和保存，方便我调试。
3. prompt中需要包含通配符的格式，因为最后调用API时，会根据实际的句子来处理发送内容。详见### 通配符配置。
4. prompt在文本框中，当点击文本框时，进入输入状态，下面会出现3个按钮：default cancel save。分别对应：恢复默认prompt，取消修改，保存修改。
5. 保存修改需要实时生效并持久化。
6. 日志中的[AIChunking]，需要增加日志。详见### 新增日志。
7. 关闭AI Chunking，翻译语言设置和下面的prompt设置，也要变灰，无法修改。
### 通配符配置
{{sentence}}，在视频播放页的Quick Search界面里选中的句子。
{{language}}，取Settings - Experimental Features - AI Chunking - Translation Language的值。

#### 注意事项
1. 输入框中出现不符合上述的通配符，点击保存会拦截。
2. 上述通配符都是必须包含于prompt中的，可以多次引用。
3. 目前已经实现缓存API返回的结果，由于引入了语言通配符，因此缓存策略也要跟着翻译语言设置走。
4. 第一次实现缓存策略跟着翻译语言设置的功能时，为了避免历史数据干扰，需要清空AI Chunks的缓存（后续迭代修改不需要，除非明确要求）。
### 新增日志
1. `duration_ms=...`，请求到完整处理结束耗时。从即将发出 API 请求开始，到收到 API 响应、完成 JSON 解码、完成 AI chunk item 校验为止；不包含本地缓存查询、本地数据库搜索、缓存写入和 UI 更新。
2. `request_content=...`，实际发出的 prompt
3. `response_content=...`，模型返回的原始 content
