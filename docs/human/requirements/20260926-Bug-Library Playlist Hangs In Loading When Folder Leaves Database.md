# 版本

main

# 关联设计

- `docs/human/requirements/20260925-Feature-Playback Continues When Content Leaves The Database.md`（3. 播放页 第 4 条）
- `docs/human/design/UI Design System.md`（Playback Overlay、Empty State）

# 需求描述

## 1. 现状

Remove Folder 或 Index 使正在播放的视频所属目录离开数据库后，打开 Playback Overlay 的 Playlist，界面一直处于加载状态（转圈），未能展示提示内容。

## 2. 要求

1. 视频所属目录不在数据库中时，打开 Playback Overlay 的 Playlist 显示提示 `No items in this playlist are in the library.`。
2. 界面加载结束时正确刷新，不卡在转圈状态。

## 3. 保持不变

1. 20260925 需求单中播放继续、Current 提示及其他已有逻辑不变。

# 验收

1. 播放某个目录下的视频，Remove 该目录并等待完成，打开 Playback Overlay 的 Playlist：界面不卡在转圈状态，显示提示 `No items in this playlist are in the library.`。
2. 单元与模块集成测试覆盖该场景下的状态刷新与空态提示判定。
3. 不新增自动化失败，不为本需求新增 E2E 能力；第 1 条人工验收。