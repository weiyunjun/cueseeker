# 版本

main

# 关联设计

- `docs/human/design/Toast Usage Registry.md`
- `docs/human/design/UI Application Rules.md`

# 需求描述

## 1. 失效条目播放报错提示

1. 点击已不在资料库中的搜索结果或摘录条目进入播放时，界面保持黑屏。
2. 界面左上角必须显示红色报错横幅 This item is no longer in the library，最长持续 5 秒；当触发以下任一操作时立即消失，不等待 5 秒倒计时结束：
   - 播放其它结果（包括所有途径：快捷键或控制栏上一个/下一个、播放列表点击、Command Panel 启动播放等）；
   - 进入 Playback Overlay 界面；
   - 退出播放（点击返回按钮、按 ESC / Backspace 等）。
3. 播放页的返回按钮与快捷键（ESC、Backspace 等）保持可用，允许用户正常返回上一界面。

## 2. 播放列表过滤失效项

1. 播放列表中不包含失效条目。
2. 若播放列表为空，界面居中提示 `No Available Results`，持续 1 秒。

# 验收

1. 点击已移出资料库的搜索结果条目：进入播放页面保持黑屏，左上角准确弹出红色报错横幅，不出现无提示的纯黑屏。
2. 点击返回按钮或按退出键可正常返回搜索页。
3. 在失效条目黑屏显示红色横幅期间，无论通过何种途径（快捷键、控制栏按钮、播放列表点击、Command Panel 等）切换至有效条目播放，红色横幅立即消失。
4. 在失效条目黑屏显示红色横幅期间，进入 Playback Overlay 界面：红色横幅立即消失。