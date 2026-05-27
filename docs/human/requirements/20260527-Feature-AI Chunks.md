备注：此为初步需求文档，需要随着讨论逐渐细化。
### 版本
feature/playback-quick-search
### 需求描述
1. 在Settings - Experimental Features - AI Chunking中，支持prompt配置和保存，方便我调试。
2. prompt中需要包含通配符的格式，因为最后调用API时，会根据实际的句子来处理发送内容。
3. prompt在文本框中，当点击文本框时，进入输入状态，下面会出现3个按钮：default cancel save。分别对应：恢复默认prompt，取消修改，保存修改。
4. 保存改需要实时生效并持久化。