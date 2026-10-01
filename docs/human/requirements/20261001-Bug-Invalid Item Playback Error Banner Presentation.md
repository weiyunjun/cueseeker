# 版本

main

# 关联设计

- `docs/human/design/Toast Usage Registry.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 失效条目播放报错提示

1. 点击已不在资料库中的搜索结果或摘录条目进入播放时，界面保持黑屏。
2. 界面左上角必须显示红色报错横幅 `This item is no longer in the library`，持续 5 秒。
3. 播放页的返回按钮与快捷键（ESC、Backspace 等）保持可用，允许用户正常返回上一界面。

## 2. 播放列表过滤失效项

1. 播放列表中不包含失效条目。
2. 若播放列表为空，界面居中提示 `No Available Results`，持续 1 秒。

# 验收

1. 点击已移出资料库的搜索结果条目：进入播放页面保持黑屏，左上角准确弹出红色报错横幅，不出现无提示的纯黑屏。
2. 点击返回按钮或按退出键可正常返回搜索页。
3. 单元测试与集成测试全部通过。